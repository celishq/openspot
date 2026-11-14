import Foundation

public struct SpotTip: Equatable, Sendable {
    public enum Anchor: Equatable, Sendable {
        case leadingCorner, trailingCorner
    }

    public let id: String
    public let anchor: Anchor
    public let text: String

    public init(id: String, anchor: Anchor, text: String) {
        self.id = id
        self.anchor = anchor
        self.text = text
    }
}
