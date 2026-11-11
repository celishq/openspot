import Foundation

/// The link to a JavaScript spot that runs inside the app (I3). Each call runs on the thread of the script. The main thread
/// waits 2 ms for its frame, and a later frame lands in a later turn (I5). A stopped call that has not run never runs, and
/// one that ran changes nothing. A change of the file loads it again.
@MainActor
final class InlineLink: ScriptLink {
    private static let frameWait: DispatchTimeInterval = .milliseconds(2)

    /// The run of the script, which loads the script ahead of its first call.
    weak var run: SpotRun? {
        didSet { if let run { _ = current(for: run) } }
    }
    let holdsScript = false
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

    var isAsking: Bool {
        asking.contains { !$0.isStopped }
    }

    func send(_ call: SpotRun.Call) -> Bool {
        guard let run else { return false }
        let made = ScriptCall(action: call.action, key: call.key, started: runs.now())
        let inline = InlineCall(arguments: call.action.arguments, reason: call.reason, input: call.input)
        made.halt = { inline.stop() }
        if case .ask(let ask) = call.purpose, !ask.isAnswer { asking.append(made) }
        run.track(made)
        let begin = Date()
        current(for: run).send(inline)
        let outcome = inline.wait(Self.frameWait) { outcome in
            Task { @MainActor [weak self] in self?.take(outcome, of: call, made, begin: begin) }
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
        guard let loaded, loaded != fileDate, let run else { return }
        end()
        _ = current(for: run)
    }

    /// The script, which starts to load at once.
    private func current(for run: SpotRun) -> InlineScript {
        if let script { return script }
        let script = InlineScript(spot: run.command, api: runs.api)
        self.script = script
        loaded = fileDate
        return script
    }

    private var fileDate: Date? {
        guard let run else { return nil }
        return (try? FileManager.default.attributesOfItem(atPath: run.command.url.path))?[.modificationDate] as? Date
    }

    /// Takes the outcome of a call. The rows of a text of the main search show at once. Any other frame takes the path of
    /// a frame of a script that runs once.
    private func take(_ outcome: InlineCall.Outcome, of call: SpotRun.Call, _ made: ScriptCall, begin: Date) {
        asking.removeAll { $0 === made }
        guard let run else { return }
        runs.usage.called(run.command.id, name: run.command.name, seconds: Date().timeIntervalSince(begin))
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
        if case .ask(.answer(let query)) = call.purpose {
            if let text { run.takeAnswers(PluginOutput(text: text).items, to: query) }
            return run.ended(made, call.purpose, end, hadAnswer: text != nil, showedPicture: false, selected: nil)
        }
        Task { [weak run, runs] in
            guard let run else { return }
            let lines = if let text { await runs.intake(text, of: run.command.id) } else { PluginOutput?.none }
            var hasAnswer = false
            var showedPicture = false
            if let lines, let text {
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
                await run.takeAnswer(lines?.withoutEffects() ?? PluginOutput(text: ""), frame: "", to: ask)
            }
            run.ended(made, call.purpose, end, hadAnswer: hasAnswer, showedPicture: showedPicture, selected: lines?.select)
        }
    }

    /// Runs a call to its end, and returns its frame, or nil when it was stopped.
    private func text(of action: SpotAction, key: String, input: String?) async throws -> String? {
        guard let run else { return nil }
        let made = ScriptCall(action: action, key: key, started: runs.now())
        let inline = InlineCall(arguments: action.arguments, input: input)
        made.halt = { inline.stop() }
        run.track(made)
        current(for: run).send(inline)
        let outcome = await inline.outcome()
        run.callEnded(made)
        switch outcome {
        case .frame(let text) where !made.isStopped:
            run.report(toastOf: PluginOutput(text: text))
            return text
        case .failed(let error) where !made.isStopped:
            throw error
        default:
            return nil
        }
    }
}
