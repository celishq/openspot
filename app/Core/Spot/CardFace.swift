import Foundation

public struct CardFace: Equatable, Sendable {
    public private(set) var tree = ViewTree.empty

    public static let none = CardFace()

    public init(tree: ViewTree = .empty) {
        self.tree = tree
    }

    public var answerSize: SpotSize? {
        [SpotSize.large, .strip].first { size in Style.Variant(size: size).map(tree.places.contains) == true }
    }

    public func draws(on size: SpotSize) -> Bool {
        tree.draws(on: size)
    }

    public mutating func set(_ value: String, of id: String) {
        tree.set(value, of: id)
    }

    mutating func lead(_ id: String, with icon: Icon) {
        tree.lead(id, with: icon)
    }
}
