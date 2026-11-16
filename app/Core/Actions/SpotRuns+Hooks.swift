import Foundation

extension SpotRuns {
    func ask(_ function: String, of spot: Spot, card: String, origin: String, until deadline: DispatchTime? = nil, later: @escaping @MainActor (Bool) -> Void) -> Bool? {
        answer(function, of: spot, card: card, origin: origin, until: deadline) { later(!$0.isEmpty) }.map { !$0.isEmpty }
    }

    func hotkey(_ function: String, of spot: Spot, card: String, origin: String, until deadline: DispatchTime? = nil, later: @escaping @MainActor (String) -> Void) -> String? {
        answer(function, of: spot, card: card, origin: origin, until: deadline, later: later)
    }

    private func answer(_ function: String, of spot: Spot, card: String, origin: String, until deadline: DispatchTime?, later: @escaping @MainActor (String) -> Void) -> String? {
        let script = script(of: spot)
        let call = InlineCall(arguments: [card, origin], function: function, limit: readLimit)
        script.send(call)
        let outcome = call.wait(until: deadline ?? .now() + frameWait) { outcome in
            let answer = Self.text(of: outcome)
            Task { @MainActor in later(answer) }
        }
        return outcome.map(Self.text)
    }

    private nonisolated static func text(of outcome: InlineCall.Outcome) -> String {
        if case .frame(let text) = outcome { return text.trimmingCharacters(in: .whitespacesAndNewlines) }
        return ""
    }
}
