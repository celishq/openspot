import Foundation

/// A card that the person resizes by its corner in Edit Spots: the sizes it offers, the layout of the grid for each, and
/// the size that a release keeps.
public struct SpotResize: Sendable {
    public let id: String
    /// The card's place in the order.
    public let index: Int
    /// The size that the card had when the resize started.
    public let start: SpotSize
    /// The size that a release keeps.
    public var size: SpotSize
    private let layouts: [(size: SpotSize, places: [SpotPlacement])]

    /// Lays out the grid once for each size in `choices`, and leaves out each size that gives the grid the layout of a size
    /// kept before it. The card's own size is always kept. The grid keeps the size of the card.
    public init(id: String, index: Int, sizes: [SpotSize], choices: [SpotSize], grid: SpotGrid = SpotGrid()) {
        self.id = id
        self.index = index
        start = sizes[index]
        size = sizes[index]
        let grid = grid.keeping(index)
        let own = grid.place(sizes)
        var layouts: [(size: SpotSize, places: [SpotPlacement])] = []
        for choice in choices.contains(start) ? choices : [start] + choices {
            var changed = sizes
            changed[index] = choice
            let places = choice == start ? own : grid.place(changed)
            if choice != start, places == own || layouts.contains(where: { $0.places == places }) { continue }
            layouts.append((choice, places))
        }
        self.layouts = layouts
    }

    /// The sizes that each give the grid another layout, in the order that the card offers them.
    public var choices: [SpotSize] {
        layouts.map(\.size)
    }

    /// The places of the cards when the card takes this size.
    public func layout(of size: SpotSize) -> [SpotPlacement] {
        layouts.first { $0.size == size }?.places ?? []
    }

    /// Where the card lies, and its size, when it takes this size.
    public func placement(of size: SpotSize) -> SpotPlacement? {
        layout(of: size).first { $0.index == index }
    }

    /// The bottom right corner of the card when the pointer has moved this far from where the resize started.
    public func corner(movedBy translation: CGSize) -> CGPoint {
        let rect = placement(of: start)?.rect ?? .zero
        return CGPoint(x: rect.maxX + translation.width, y: rect.maxY + translation.height)
    }

    /// The size whose bottom right corner lies nearest to this point. A tie keeps the size the card offers first.
    public func nearest(to point: CGPoint) -> SpotSize {
        layouts.min { lhs, rhs in distance(from: point, to: lhs.size) < distance(from: point, to: rhs.size) }?.size ?? start
    }

    private func distance(from point: CGPoint, to size: SpotSize) -> CGFloat {
        let rect = placement(of: size)?.rect ?? .zero
        return hypot(rect.maxX - point.x, rect.maxY - point.y)
    }
}
