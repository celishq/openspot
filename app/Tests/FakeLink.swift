import Foundation
@testable import OpenspotCore

@MainActor
final class FakeLink: ScriptLink {
    weak var run: SpotRun?
    private(set) var sent: [OpenCall] = []
    private var open: [OpenCall] = []

    var isAsking: Bool {
        open.contains { call in
            guard case .ask(let ask) = call.request.purpose else { return false }
            return !ask.isAnswer && !call.made.isStopped
        }
    }

    func send(_ call: OpenCall) -> Bool {
        sent.append(call)
        open.append(call)
        run?.track(call.made)
        return true
    }

    func frame(_ text: String, of call: OpenCall) async {
        guard !call.made.isStopped else { return }
        call.frames.append(text)
        await run?.take(text, SpotOutput(text: text), of: call)
    }

    func end(_ call: OpenCall, _ end: ScriptCall.End = .ended) async {
        let last = call.made.isStopped ? .stopped : end
        await run?.takeEnd(of: call, last)
        open.removeAll { $0 === call }
        run?.finish(call, last)
    }

    func arguments() -> [[String]] {
        sent.map(\.request.action.arguments)
    }
}
