import Foundation

/// A tip that names a control of a card in Edit Spots.
public struct SpotTip: Equatable, Sendable {
    /// Where the tip lies: under the leading or the trailing top corner control of a card on the grid.
    public enum Anchor: Equatable, Sendable {
        case leadingCorner, trailingCorner
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
