import Foundation

public struct HookAnswers: Equatable, Sendable {
    private var texts: [String: String] = [:]

    public init() {}

    func text(_ hook: ActionHook, of offer: OfferedAction, in spot: String) -> String? {
        texts[Self.key(hook, offer, spot)]
    }

    mutating func keep(_ text: String, for hook: ActionHook, of offer: OfferedAction, in spot: String) {
        texts[Self.key(hook, offer, spot)] = text
    }

    private static func key(_ hook: ActionHook, _ offer: OfferedAction, _ spot: String) -> String {
        "\(spot) \(offer.action.id) \(hook.rawValue)"
    }
}
