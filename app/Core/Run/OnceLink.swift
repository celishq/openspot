import Foundation

@MainActor
final class OnceLink: ScriptLink {
    weak var run: SpotRun?
    let holdsScript = false
    let keepsState = false
    let isReachable = true
    private let runs: SpotRuns
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
        var hasAnswer = false
        var showedPicture = false
        var lastHead: SpotOutput?
        var selected: String?
        let made = runs.call(run.spot, call.action, key: call.key, input: call.input, limit: call.limit, reason: call.reason, variables: run.withPage(call.variables)) { [weak run] made, text, lines in
            guard let run else { return }
            selected = lines.select ?? selected
            switch call.purpose {
            case .ask(let ask):
                guard !made.isStopped else { return }
                if lines.isPicture {
                    await run.takeAnswer(lines, frame: text, to: ask, keeping: hasAnswer ? run.typedPart : nil)
                    hasAnswer = true
                } else {
                    lastHead = lines
                    run.takeEffects(lines, frame: text)
                }
            case .work(let work):
                run.takeMove(lines)
                if lines.isPicture {
                    if await run.takePicture(lines, frame: text, of: work) {
                        showedPicture = true
                        run.drewFrame(made)
                    }
                } else {
                    run.takeEffects(lines, frame: text)
                }
            }
            if case .ask(.read) = call.purpose, lines.isPicture, !run.isWanted, !made.isStopped { run.stop(made) }
        } onEnd: { [weak self, weak run] made, end in
            guard let run else {
                self?.asking.removeAll { $0 === made }
                return
            }
            if case .ended = end, !hasAnswer, case .ask(let ask) = call.purpose {
                hasAnswer = true
                await run.takeAnswer(lastHead?.withoutEffects() ?? .empty, frame: "", to: ask)
            }
            self?.asking.removeAll { $0 === made }
            run.ended(made, call.purpose, end, hadAnswer: hasAnswer, showedPicture: showedPicture, selected: selected)
        }
        if case .ask(let ask) = call.purpose, !ask.isAnswer { asking.append(made) }
        run.track(made)
        return true
    }

    func form(_ action: SpotAction, key: String) async throws -> SpotOutput? {
        try await answer(of: action, key: key, input: nil)
    }

    func submit(_ action: SpotAction, key: String, values: String) async throws -> SpotOutput? {
        try await answer(of: action, key: key, input: values)
    }

    private func answer(of action: SpotAction, key: String, input: String?) async throws -> SpotOutput? {
        guard let run else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            var answer = SpotOutput.empty
            var select: String?
            let made = runs.call(run.spot, action, key: key, input: input, limit: nil, variables: run.withPage([:])) { [weak run] _, _, lines in
                if !lines.fields.isEmpty || answer.fields.isEmpty { answer = lines }
                select = lines.select ?? select
                run?.report(toastOf: lines)
            } onEnd: { [weak run] made, end in
                run?.callEnded(made)
                switch end {
                case .stopped: continuation.resume(returning: nil)
                case .ended: continuation.resume(returning: answer.selecting(select))
                case .failed(let error): continuation.resume(throwing: error)
                }
            }
            run.track(made)
        }
    }

    func stop(_ call: ScriptCall) {}

    func settle() {}

    func end() {}

    func leave() {}

    func scanned() {}
}
