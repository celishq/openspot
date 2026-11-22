import Foundation

public struct CardFace: Equatable, Sendable {
    public private(set) var parts: [SpotPart]
    public private(set) var tree = ViewTree.empty

    public static let none = CardFace(parts: [])

    public init(parts: [SpotPart], tree: ViewTree = .empty) {
        self.parts = tree.places.isEmpty ? [] : parts
        self.tree = tree
    }

    public var answerSize: SpotSize? {
        [SpotSize.large, .strip].first { size in Style.Variant(size: size).map(tree.places.contains) == true }
    }

    public mutating func set(_ value: String, of id: String) {
        parts.firstIndex { $0.id == id }.map { parts[$0].set(value) }
    }
}
