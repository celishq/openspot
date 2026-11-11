import Foundation

/// The link to a script that runs once for each call (01). Each call is a process of its own. Each frame with a block of a
/// read or a search answers it, and one that ended with no picture answers with its last head. A frame of only a head
/// carries effects.
@MainActor
final class OnceLink: ScriptLink {
    weak var run: SpotRun?
    let holdsScript = false
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
        var lastHead: PluginOutput?
        var selected: String?
        let made = runs.call(run.command, call.action, key: call.key, input: call.input, limit: call.limit, reason: call.reason, variables: call.variables) { [weak run] made, text, lines in
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
                if lines.isPicture {
                    if await run.takePicture(lines, frame: text, of: work) { showedPicture = true }
                } else {
                    run.takeEffects(lines, frame: text)
                }
            }
            if case .ask(.read) = call.purpose, lines.isPicture, !run.isWanted, !made.isStopped { run.stop(made) }
        } onEnd: { [weak self, weak run] made, end in
            self?.asking.removeAll { $0 === made }
            guard let run else { return }
            if case .ended = end, !hasAnswer, case .ask(let ask) = call.purpose {
                hasAnswer = true
                await run.takeAnswer(lastHead?.withoutEffects() ?? PluginOutput(text: ""), frame: "", to: ask)
            }
            run.ended(made, call.purpose, end, hadAnswer: hasAnswer, showedPicture: showedPicture, selected: selected)
        }
        if case .ask(let ask) = call.purpose, !ask.isAnswer { asking.append(made) }
        run.track(made)
        return true
    }

    func form(_ action: SpotAction, key: String) async throws -> String? {
        try await text(of: action, key: key, input: nil)
    }

    func submit(_ action: SpotAction, key: String, values: String) async throws -> String? {
        try await text(of: action, key: key, input: values)
    }

    /// Runs a call to its end, and returns all that it printed, or nil when it was stopped.
    private func text(of action: SpotAction, key: String, input: String?) async throws -> String? {
        guard let run else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            var text = ""
            let made = runs.call(run.command, action, key: key, input: input, limit: nil) { [weak run] _, frame, lines in
                text += frame
                run?.report(toastOf: lines)
            } onEnd: { [weak run] made, end in
                run?.callEnded(made)
                switch end {
                case .stopped: continuation.resume(returning: nil)
                case .ended: continuation.resume(returning: text)
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
