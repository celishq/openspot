import Foundation

public struct SpotResize: Sendable {
    public let id: String
    public let index: Int
    public let start: SpotSize
    public var size: SpotSize
    private let layouts: [(size: SpotSize, places: [SpotPlacement])]

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

    public var choices: [SpotSize] {
        layouts.map(\.size)
    }

    public func layout(of size: SpotSize) -> [SpotPlacement] {
        layouts.first { $0.size == size }?.places ?? []
    }

    public func placement(of size: SpotSize) -> SpotPlacement? {
        layout(of: size).first { $0.index == index }
    }

    public func corner(movedBy translation: CGSize) -> CGPoint {
        let rect = placement(of: start)?.rect ?? .zero
        return CGPoint(x: rect.maxX + translation.width, y: rect.maxY + translation.height)
    }

    public func nearest(to point: CGPoint) -> SpotSize {
        layouts.min { lhs, rhs in distance(from: point, to: lhs.size) < distance(from: point, to: rhs.size) }?.size ?? start
    }

    private func distance(from point: CGPoint, to size: SpotSize) -> CGFloat {
        let rect = placement(of: size)?.rect ?? .zero
        return hypot(rect.maxX - point.x, rect.maxY - point.y)
    }
}
