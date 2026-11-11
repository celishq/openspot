import Foundation

/// The link to a JavaScript spot that runs inside the app (I3). Each call runs on the thread of the script, which loads at
/// the first call (A26). The main thread waits 2 ms for its frame, and a later frame lands in a later turn (I5). A stopped
/// call that has not run never runs, and one that ran changes nothing. Each call goes in the call log. A change of the
/// file loads it again.
@MainActor
final class InlineLink: ScriptLink {
    private static let frameWait: DispatchTimeInterval = .milliseconds(2)

    weak var run: SpotRun?
    let holdsScript = false
    let keepsState = false
    let isReachable = true
    private let runs: SpotRuns
    private var script: InlineScript?
    /// The date of the file that the script loaded.
    private var loaded: Date?
    private var asking: [ScriptCall] = []

    init(runs: SpotRuns) {
        self.runs = runs
    }

    nonisolated deinit {}

    /// Whether the script holds its context and its thread now.
    var isLoaded: Bool {
        script?.isRunning == true
    }

    var isAsking: Bool {
        asking.contains { !$0.isStopped }
    }

    func send(_ call: SpotRun.Call) -> Bool {
        guard let run else { return false }
        let made = ScriptCall(action: call.action, key: call.key, started: runs.now())
        let inline = InlineCall(arguments: call.action.arguments, variables: call.variables, input: call.input)
        made.halt = { inline.stop() }
        if case .ask(let ask) = call.purpose, !ask.isAnswer { asking.append(made) }
        run.track(made)
        let begin = Date()
        current(for: run).send(inline)
        let outcome = inline.wait(Self.frameWait) { outcome in
            Task { @MainActor in self.take(outcome, of: call, made, begin: begin) }
        }
        if let outcome { take(outcome, of: call, made, begin: begin) }
        return true
    }

    func form(_ action: SpotAction, key: String) async throws -> String? {
        try await text(of: action, key: key, input: nil)
    }

    func submit(_ action: SpotAction, key: String, values: String) async throws -> String? {
        try await text(of: action, key: key, input: values)
    }

    func stop(_ call: ScriptCall) {}

    func settle() {}

    func end() {
        script?.end()
        script = nil
        asking = []
    }

    func leave() {
        end()
    }

    func scanned() {
        guard let loaded, loaded != fileDate else { return }
        end()
    }

    /// The script, which loads at its first call.
    private func current(for run: SpotRun) -> InlineScript {
        if let script { return script }
        let script = runs.inline(run.spot)
        self.script = script
        loaded = fileDate
        return script
    }

    private var fileDate: Date? {
        guard let run else { return nil }
        return (try? FileManager.default.attributesOfItem(atPath: run.spot.url.path))?[.modificationDate] as? Date
    }

    /// Takes the outcome of a call. The rows of a text of the main search show at once, and a text with no frame ends with
    /// no rows. Any other frame takes the path of a frame of a script that runs once, and a call stopped meanwhile changes
    /// nothing.
    private func take(_ outcome: InlineCall.Outcome, of call: SpotRun.Call, _ made: ScriptCall, begin: Date) {
        guard let run else {
            asking.removeAll { $0 === made }
            return
        }
        runs.usage.called(run.spot.id, name: run.spot.name, seconds: Date().timeIntervalSince(begin))
        var text: String?
        let end: ScriptCall.End
        switch outcome {
        case .frame(let frame) where !made.isStopped:
            text = frame
            end = .ended
        case .failed(let error) where !made.isStopped:
            end = .failed(error)
        default:
            end = .stopped
        }
        runs.record(run.spot, call.action, input: call.input, frames: text.map { [$0] } ?? [], errors: Self.errors(of: end), end: end, reason: call.reason, started: made.started, begin: begin)
        if case .ask(.answer(let query)) = call.purpose {
            run.takeAnswers(text.map { SpotOutput(text: $0).items } ?? [], to: query)
            return run.ended(made, call.purpose, end, hadAnswer: text != nil, showedPicture: false, selected: nil)
        }
        Task { [weak run, runs] in
            defer { self.asking.removeAll { $0 === made } }
            guard let run else { return }
            var end = end
            var lines = if let text { await runs.intake(text, of: run.spot.id) } else { SpotOutput?.none }
            if made.isStopped {
                lines = nil
                end = .stopped
            }
            var hasAnswer = false
            var showedPicture = false
            if let lines, let text, !made.isStopped {
                made.take(lines)
                switch call.purpose {
                case .ask(let ask) where lines.isPicture:
                    await run.takeAnswer(lines, frame: text, to: ask)
                    hasAnswer = true
                case .work(let work) where lines.isPicture:
                    showedPicture = await run.takePicture(lines, frame: text, of: work)
                default:
                    run.takeEffects(lines, frame: text)
                }
            }
            if case .ended = end, !hasAnswer, case .ask(let ask) = call.purpose {
                hasAnswer = true
                await run.takeAnswer(lines?.withoutEffects() ?? SpotOutput(text: ""), frame: "", to: ask)
            }
            run.ended(made, call.purpose, end, hadAnswer: hasAnswer, showedPicture: showedPicture, selected: lines?.select)
        }
    }

    /// What a call that failed says, as a script says it on stderr.
    private static func errors(of end: ScriptCall.End) -> String {
        guard case .failed(let error) = end else { return "" }
        return ((error as? SpotError)?.reason ?? error.localizedDescription) + "\n"
    }

    /// Runs a call to its end, and returns its frame, or nil when it was stopped.
    private func text(of action: SpotAction, key: String, input: String?) async throws -> String? {
        guard let run else { return nil }
        let made = ScriptCall(action: action, key: key, started: runs.now())
        let inline = InlineCall(arguments: action.arguments, input: input)
        made.halt = { inline.stop() }
        run.track(made)
        let begin = Date()
        current(for: run).send(inline)
        let outcome = await inline.outcome()
        run.callEnded(made)
        let text: String? = if case .frame(let frame) = outcome { frame } else { nil }
        let end: ScriptCall.End = switch outcome {
        case _ where made.isStopped, .dropped: .stopped
        case .frame: .ended
        case .failed(let error): .failed(error)
        }
        runs.record(run.spot, action, input: input, frames: text.map { [$0] } ?? [], errors: Self.errors(of: end), end: end, reason: nil, started: made.started, begin: begin)
        switch outcome {
        case .frame(let text) where !made.isStopped:
            run.report(toastOf: SpotOutput(text: text))
            return text
        case .failed(let error) where !made.isStopped:
            throw error
        default:
            return nil
        }
    }
}
