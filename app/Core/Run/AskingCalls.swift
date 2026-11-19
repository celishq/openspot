import Foundation

@MainActor
final class AskingCalls {
    private var calls: [ScriptCall] = []

    nonisolated deinit {}

    var isAsking: Bool {
        calls.contains { !$0.isStopped }
    }

    func open(_ call: OpenCall, in run: SpotRun) {
        if case .ask(let ask) = call.request.purpose, !ask.isAnswer { calls.append(call.made) }
        run.track(call.made)
    }

    func close(_ call: OpenCall, _ end: ScriptCall.End, errors: String, in run: SpotRun?) async {
        await run?.takeEnd(of: call, end)
        drop(call.made)
        run?.finish(call, end, errors: errors)
    }

    func drop(_ call: ScriptCall) {
        calls.removeAll { $0 === call }
    }

    func dropAll() {
        calls = []
    }
}
