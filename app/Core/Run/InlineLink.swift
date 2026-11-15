import Foundation

@MainActor
final class InlineLink: ScriptLink {
    weak var run: SpotRun?
    private let runs: SpotRuns
    private var asking: [ScriptCall] = []

    init(runs: SpotRuns) {
        self.runs = runs
    }

    nonisolated deinit {}

    var isAsking: Bool {
        asking.contains { !$0.isStopped }
    }

    func send(_ call: OpenCall) -> Bool {
        guard let run else { return false }
        let request = call.request
        let values = run.fieldValues
        let inline = InlineCall(arguments: request.action.arguments, variables: run.sent(request.variables, values: values), input: values.input(with: request.input), limit: request.limit)
        call.made.halt = { inline.stop() }
        if case .ask(let ask) = request.purpose, !ask.isAnswer { asking.append(call.made) }
        run.track(call.made)
        runs.script(of: run.spot).send(inline)
        let wait = { (deadline: DispatchTime) in
            if DispatchTime.now() < deadline { self.runs.frameWaits += 1 }
            let outcome = inline.wait(until: deadline) { outcome in
                Task { @MainActor in self.take(outcome, of: call) }
            }
            if let outcome { self.take(outcome, of: call) }
        }
        switch request.purpose {
        case .ask(.answer) where runs.answerWaits != nil: runs.answerWaits?.append(wait)
        case .form: wait(.now())
        default: wait(.now() + runs.frameWait)
        }
        return true
    }

    func restart() {
        end()
    }

    func end() {
        if let run { runs.dropScript(of: run.spot.id) }
        asking = []
    }

    private func take(_ outcome: InlineCall.Outcome, of call: OpenCall) {
        let made = call.made
        guard let run else {
            asking.removeAll { $0 === made }
            return
        }
        var text: String?
        var end = ScriptCall.End.stopped
        switch outcome {
        case .frame(let frame) where !made.isStopped:
            text = frame
            end = .ended
        case .failed(let error) where !made.isStopped:
            end = .failed(error)
        default:
            break
        }
        call.frames = text.map { [$0] } ?? []
        let errors = Self.errors(of: end)
        if case .ask(.answer(let query)) = call.request.purpose {
            return run.take(answers: text, to: query, of: call, end, errors: errors)
        }
        let first = end
        Task { [weak run, runs] in
            var end = first
            if let run, let text {
                let lines = await runs.intake(text, of: run.spot.id)
                if made.isStopped { end = .stopped } else { await run.take(text, lines, of: call) }
            }
            await run?.takeEnd(of: call, end)
            self.asking.removeAll { $0 === made }
            run?.finish(call, end, errors: errors)
        }
    }

    private static func errors(of end: ScriptCall.End) -> String {
        guard case .failed(let error) = end else { return "" }
        return ((error as? SpotError)?.reason ?? error.localizedDescription) + "\n"
    }
}
