import Foundation

/// A tip that names a control of a card in Edit Spots, or a card of the dock that shows no words.
public struct SpotTip: Equatable, Sendable {
    /// Where the tip lies: under a top corner control of a card on the grid, or under a card of the dock.
    public enum Anchor: Equatable, Sendable {
        case leadingCorner, trailingCorner, dockCard
    }

    /// The card that the tip belongs to.
    public let id: String
    public let anchor: Anchor
    public let text: String

    public init(id: String, anchor: Anchor, text: String) {
        self.id = id
        self.anchor = anchor
        self.text = text
    }
}
