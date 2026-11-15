import Foundation

@MainActor
final class InlineLink: ScriptLink {
    weak var run: SpotRun?
    let holdsScript = false
    let keepsState = false
    let isReachable = true
    private let runs: SpotRuns
    private var script: InlineScript?
    private var loadedFileDate: Date?
    private var asking: [ScriptCall] = []

    init(runs: SpotRuns) {
        self.runs = runs
    }

    nonisolated deinit {}

    var isLoaded: Bool {
        script?.isRunning == true
    }

    var isAsking: Bool {
        asking.contains { !$0.isStopped }
    }

    func send(_ call: SpotRun.Call) -> Bool {
        guard let run else { return false }
        let made = ScriptCall(action: call.action, key: call.key, started: runs.now())
        let inline = InlineCall(arguments: call.action.arguments, variables: run.withPage(call.variables), input: call.input)
        made.halt = { inline.stop() }
        if case .ask(let ask) = call.purpose, !ask.isAnswer { asking.append(made) }
        run.track(made)
        let begin = Date()
        current(for: run).send(inline)
        let wait = { (deadline: DispatchTime) in
            if DispatchTime.now() < deadline { self.runs.frameWaits += 1 }
            let outcome = inline.wait(until: deadline) { outcome in
                Task { @MainActor in self.take(outcome, of: call, made, begin: begin) }
            }
            if let outcome { self.take(outcome, of: call, made, begin: begin) }
        }
        if case .ask(.answer) = call.purpose, runs.answerWaits != nil {
            runs.answerWaits?.append(wait)
        } else {
            wait(.now() + runs.frameWait)
        }
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
        guard let loadedFileDate, loadedFileDate != fileDate else { return }
        end()
    }

    private func current(for run: SpotRun) -> InlineScript {
        let date = fileDate
        if let script, loadedFileDate == date { return script }
        script?.end()
        let script = runs.inline(run.spot)
        self.script = script
        loadedFileDate = date
        return script
    }

    private var fileDate: Date? {
        guard let run else { return nil }
        return (try? FileManager.default.attributesOfItem(atPath: run.spot.url.path))?[.modificationDate] as? Date
    }

    private func take(_ outcome: InlineCall.Outcome, of call: SpotRun.Call, _ made: ScriptCall, begin: Date) {
        guard let run else {
            asking.removeAll { $0 === made }
            return
        }
        let isFailure = if case .failed = outcome { !made.isStopped } else { false }
        runs.usage.called(run.spot, seconds: Date().timeIntervalSince(begin), isFailure: isFailure, at: runs.now())
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
            run.takeAnswers(text.map { SpotOutput(text: $0).answers } ?? [], to: query)
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
                    run.takeMove(lines)
                    showedPicture = await run.takePicture(lines, frame: text, of: work)
                default:
                    if case .work = call.purpose { run.takeMove(lines) }
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

    private static func errors(of end: ScriptCall.End) -> String {
        guard case .failed(let error) = end else { return "" }
        return ((error as? SpotError)?.reason ?? error.localizedDescription) + "\n"
    }

    private func text(of action: SpotAction, key: String, input: String?) async throws -> String? {
        guard let run else { return nil }
        let made = ScriptCall(action: action, key: key, started: runs.now())
        let inline = InlineCall(arguments: action.arguments, variables: run.withPage([:]), input: input)
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
