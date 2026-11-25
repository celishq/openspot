import Foundation

public struct SpotDrag: Equatable, Sendable {
    public let id: String
    public let index: Int
    public let home: GridCell
    public let start: SpotSize
    public private(set) var cell: GridCell
    public private(set) var layout: [SpotPlacement]
    private let homeLayout: [SpotPlacement]
    private let others: [SpotPlacement]
    private let grid: GridLayout
    private let choices: [SpotSize]

    public init(id: String, index: Int, placements: [SpotPlacement], grid: GridLayout, choices: [SpotSize]) {
        self.id = id
        self.index = index
        let placement = placements.first { $0.index == index } ?? SpotPlacement(index: index, row: 0, column: 0, size: .small)
        home = placement.cell
        start = placement.size
        cell = home
        layout = placements
        homeLayout = placements
        others = placements.filter { $0.index != index }
        self.grid = grid
        self.choices = choices.isEmpty ? [placement.size] : choices
    }

    public var placement: SpotPlacement? {
        layout.first { $0.index == index }
    }

    public var homeRect: CGRect {
        SpotPlacement(index: index, row: home.row, column: home.column, size: start).rect
    }

    public func cell(movedBy translation: CGSize) -> GridCell {
        let rect = homeRect
        return grid.cell(near: CGPoint(x: rect.minX + translation.width, y: rect.minY + translation.height), for: start)
    }

    public func moved(to cell: GridCell) -> SpotDrag? {
        guard cell != home else {
            var next = self
            next.cell = home
            next.layout = homeLayout
            return next
        }
        let size = grid.size(of: start, at: cell, among: others, choices: choices)
        guard let layout = grid.moved(index, to: cell, size: size, in: homeLayout) else { return nil }
        var next = self
        next.cell = cell
        next.layout = layout
        return next
    }

    public func capped(_ translation: CGSize, within bounds: CGRect) -> CGSize {
        let rect = homeRect
        let x = min(max(translation.width, bounds.minX - rect.minX), bounds.maxX - rect.maxX)
        let y = min(max(translation.height, bounds.minY - rect.minY), bounds.maxY - rect.maxY)
        return CGSize(width: x, height: y)
    }

    public func holds(movedBy translation: CGSize) -> Bool {
        let rect = homeRect
        let centre = CGPoint(x: rect.midX + translation.width, y: rect.midY + translation.height)
        return CGRect(x: 0, y: 0, width: grid.width, height: grid.height).insetBy(dx: -SpotTokens.cell / 2, dy: -SpotTokens.cell / 2).contains(centre)
    }
}
