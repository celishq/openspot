import Foundation

@MainActor
final class ShownLink: ScriptLink {
    weak var run: SpotRun?
    private let frame: String?

    init(frame: String?) {
        self.frame = frame
    }

    nonisolated deinit {}

    var isAsking: Bool {
        false
    }

    func send(_ call: OpenCall) -> Bool {
        guard let run, let frame, case .ask(.read) = call.request.purpose else { return false }
        run.track(call.made)
        Task { [weak run] in
            await run?.take(frame, SpotOutput(text: frame), of: call)
            await run?.takeEnd(of: call, .ended)
            run?.finish(call, .ended)
        }
        return true
    }
}
