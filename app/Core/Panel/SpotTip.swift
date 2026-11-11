import Foundation

/// A tip under a corner control of a card in Edit Spots, which names what the control does.
public struct SpotTip: Equatable, Sendable {
    /// The card that holds the control.
    public let id: String
    /// Whether the control lies on the card's top right corner, else on its top left.
    public let isTrailing: Bool
    public let text: String

    public init(id: String, isTrailing: Bool, text: String) {
        self.id = id
        self.isTrailing = isTrailing
        self.text = text
    }
}
