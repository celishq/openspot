import Foundation

public struct SpotPin: Equatable, Sendable {
    public enum Target: Equatable, Sendable {
        case slot(GridCell, SpotSize)
        case swap(String, GridCell, SpotSize)

        public var cell: GridCell {
            switch self {
            case .slot(let cell, _), .swap(_, let cell, _): cell
            }
        }

        public var size: SpotSize {
            switch self {
            case .slot(_, let size), .swap(_, _, let size): size
            }
        }
    }

    public let id: String
    public let start: CGPoint
    public let size: SpotSize
    public private(set) var target: Target?
    let grid: GridLayout
    let placements: [SpotPlacement]
    private let ids: [String?]
    private let choices: [SpotSize]

    init(id: String, start: CGPoint, size: SpotSize, choices: [SpotSize], grid: GridLayout, placements: [SpotPlacement], ids: [String?]) {
        self.id = id
        self.start = start
        self.size = size
        self.choices = choices
        self.grid = grid
        self.placements = placements
        self.ids = ids
    }

    public var carriedSize: SpotSize {
        target?.size ?? size
    }

    public var landing: CGRect? {
        target.map { SpotPlacement(index: 0, row: $0.cell.row, column: $0.cell.column, size: $0.size).rect }
    }

    func moved(by translation: CGSize) -> SpotPin {
        var next = self
        next.target = target(at: CGPoint(x: start.x + translation.width, y: start.y + translation.height))
        return next
    }

    private func target(at corner: CGPoint) -> Target? {
        let half = SpotTokens.cell / 2
        let centre = CGPoint(x: corner.x + half, y: corner.y + half)
        guard CGRect(x: 0, y: 0, width: grid.width, height: grid.height).insetBy(dx: -half, dy: -half).contains(centre) else { return nil }
        let cell = grid.cell(near: corner, for: .small)
        if let card = placements.first(where: { covers($0, cell) }) {
            guard ids.indices.contains(card.index), let leaving = ids[card.index] else { return nil }
            let others = placements.filter { $0.index != card.index }
            let size = choices.contains(card.size) ? card.size : grid.fit(size, at: card.cell, among: others, choices: choices) ?? card.size
            return .swap(leaving, card.cell, size)
        }
        return grid.fit(size, at: cell, among: placements, choices: choices).map { .slot(cell, $0) }
    }

    private func covers(_ placement: SpotPlacement, _ cell: GridCell) -> Bool {
        (placement.row..<(placement.row + placement.size.rows)).contains(cell.row)
            && (placement.column..<(placement.column + placement.size.columns)).contains(cell.column)
    }
}
