import Foundation

public struct SpotPlacement: Equatable, Sendable {
    public let index: Int
    public let row: Int
    public let column: Int
    public let size: SpotSize
    let drop: CGFloat

    public init(index: Int, row: Int, column: Int, size: SpotSize, drop: CGFloat = 0) {
        self.index = index
        self.row = row
        self.column = column
        self.size = size
        self.drop = drop
    }

    public var cell: GridCell {
        GridCell(row: row, column: column)
    }

    func dropped(by points: CGFloat) -> SpotPlacement {
        points == 0 ? self : SpotPlacement(index: index, row: row, column: column, size: size, drop: drop + points)
    }

    func reindexed(_ next: Int) -> SpotPlacement {
        SpotPlacement(index: next, row: row, column: column, size: size, drop: drop)
    }

    public func direction(awayFrom open: SpotPlacement) -> (columns: Int, rows: Int) {
        if index == open.index { return (0, 0) }
        if row + size.rows <= open.row { return (0, -1) }
        if row >= open.row + open.size.rows { return (0, 1) }
        return (column < open.column ? -1 : 1, 0)
    }

    public var rect: CGRect {
        CGRect(
            x: CGFloat(column) * (SpotTokens.cell + SpotTokens.columnGap),
            y: CGFloat(row) * (SpotTokens.cell + SpotTokens.rowGap) + drop,
            width: SpotTokens.width(columns: size.columns),
            height: SpotTokens.height(rows: size.rows)
        )
    }

    public static func height(of placements: [SpotPlacement]) -> CGFloat {
        placements.map(\.rect.maxY).max() ?? 0
    }
}
