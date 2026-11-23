import Foundation

extension SpotRuns {
    func answer(_ handler: String, of spot: Spot, card: String, origin: String, until deadline: DispatchTime? = nil, later: @escaping @MainActor (String) -> Void) -> String? {
        let script = script(of: spot)
        let input = Message(SpotWords(arguments: [handler]), inputs: [.init(key: "item", value: card), .init(key: "origin", value: origin)]).text
        let call = InlineCall(arguments: [handler], input: input, limit: showLimit)
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
