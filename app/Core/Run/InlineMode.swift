import Foundation

@MainActor
final class InlineMode: ScriptMode {
    weak var run: SpotRun?
    private let runs: SpotRuns
    private let asking = AskingCalls()

    init(runs: SpotRuns) {
        self.runs = runs
    }

    nonisolated deinit {}

    var isAsking: Bool {
        asking.isAsking
    }

    static func frames(of spot: Spot, _ message: Message, limit: TimeInterval?, reason: String?, variables: [String: String], call: OpenCall?, in runs: SpotRuns) -> Frames {
        let inline = InlineCall(arguments: message.action.arguments, variables: runs.variables(of: spot, given: variables), input: message.text, reason: reason, limit: limit)
        runs.script(of: spot).send(inline)
        let (stream, halt) = runs.answered {
            switch await inline.outcome(limit: limit) {
            case .frame(let text): return text
            case .failed(let error): throw error
            case .dropped: return ""
            }
        }
        return (stream, {
            inline.stop()
            halt()
        }, nil)
    }

    func send(_ call: OpenCall) -> Bool {
        guard let run else { return false }
        let request = call.request
        let message = run.message(of: request, values: run.fieldValues)
        let inline = InlineCall(arguments: message.action.arguments, input: message.text, reason: request.event?.rawValue, limit: request.limit, opened: call)
        call.made.halt = { inline.stop() }
        asking.open(call, in: run)
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
        asking.dropAll()
    }

    private func take(_ outcome: InlineCall.Outcome, of call: OpenCall) {
        let made = call.made
        guard let run else {
            asking.drop(made)
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
        Task { [weak run, runs, asking] in
            var end = first
            if let run, let text {
                let lines = await runs.intake(text, of: run.spot)
                if made.isStopped { end = .stopped } else { await run.take(text, lines, of: call) }
            }
            await asking.close(call, end, errors: errors, in: run)
        }
    }

    private static func errors(of end: ScriptCall.End) -> String {
        guard case .failed(let error) = end else { return "" }
        return ((error as? SpotError)?.reason ?? error.localizedDescription) + "\n"
    }
}
