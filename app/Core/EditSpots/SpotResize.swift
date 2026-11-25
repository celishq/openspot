import Foundation

public struct SpotResize: Sendable {
    public let id: String
    public let index: Int
    public let start: SpotSize
    public var size: SpotSize
    let grid: GridLayout
    private let layouts: [(size: SpotSize, places: [SpotPlacement])]

    public init(id: String, index: Int, placements: [SpotPlacement], choices: [SpotSize], grid: GridLayout) {
        self.id = id
        self.index = index
        let placement = placements.first { $0.index == index } ?? SpotPlacement(index: index, row: 0, column: 0, size: .small)
        start = placement.size
        size = placement.size
        self.grid = grid
        var layouts: [(size: SpotSize, places: [SpotPlacement])] = [(placement.size, placements)]
        for choice in choices where choice != placement.size {
            guard let places = grid.moved(index, to: placement.cell, size: choice, in: placements) else { continue }
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
