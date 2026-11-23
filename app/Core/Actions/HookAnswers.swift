import Foundation

public struct HookAnswers: Equatable, Sendable {
    private var texts: [String: String] = [:]

    public init() {}

    func text(of offer: OfferedAction, in spot: String) -> String? {
        texts[Self.key(offer, spot)]
    }

    mutating func keep(_ text: String, of offer: OfferedAction, in spot: String) {
        texts[Self.key(offer, spot)] = text
    }

    private static func key(_ offer: OfferedAction, _ spot: String) -> String {
        "\(spot) \(offer.action.id)"
    }
}
