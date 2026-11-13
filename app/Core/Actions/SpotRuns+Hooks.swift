import Foundation

/// The hooks of offered actions: functions of a JavaScript spot that say whether an action shows on a card (protocol:
/// Buttons and actions).
extension SpotRuns {
    /// Asks a hook of a spot about a card, with the card's ID and origin as its arguments, and waits `frameWait` at most.
    /// Returns nil past the wait, and then the answer goes to `later` on the main thread. A hook that throws says no.
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
