import Foundation

extension SpotRuns {
    func ask(_ function: String, of spot: Spot, card: String, origin: String, later: @escaping @MainActor (Bool) -> Void) -> Bool? {
        let script = hookScript(of: spot)
        let call = InlineCall(arguments: [card, origin], function: function)
        script.send(call)
        let outcome = call.wait(until: .now() + frameWait) { outcome in
            let answer = Self.isYes(outcome)
            Task { @MainActor in later(answer) }
        }
        return outcome.map(Self.isYes)
    }

    private func hookScript(of spot: Spot) -> InlineScript {
        if let kept = hookScripts[spot.id], kept.spot == spot { return kept.script }
        hookScripts[spot.id]?.script.end()
        let script = inline(spot)
        hookScripts[spot.id] = (spot, script)
        return script
    }

    private nonisolated static func isYes(_ outcome: InlineCall.Outcome) -> Bool {
        if case .frame(let text) = outcome { return text == "true" }
        return false
    }
}
