import Foundation

/// Where a spot lies on the grid: its place in the order, its row and column, its size, and in Edit Spots its group.
public struct SpotPlacement: Equatable, Sendable {
    /// The group of a card in Edit Spots while both have cards: on the grid, or on the shelf of search only under it.
    public enum Group: Equatable, Sendable {
        case grid, shelf
    }

    public let index: Int
    public let row: Int
    public let column: Int
    public let size: SpotSize
    /// Its group, or nil while the cards lie in one group.
    public let group: Group?

    public init(index: Int, row: Int, column: Int, size: SpotSize, group: Group? = nil) {
        self.index = index
        self.row = row
        self.column = column
        self.size = size
        self.group = group
    }

    /// How far the title bands above the spot push it down: one band over the grid, and one more over the shelf.
    public var top: CGFloat {
        switch group {
        case nil: 0
        case .grid: SpotTokens.groupTitleBand
        case .shelf: 2 * SpotTokens.groupTitleBand
        }
    }

    /// The way this spot moves when another spot opens: up or down if it lies above or below it, else to its side.
    public func direction(awayFrom open: SpotPlacement) -> (columns: Int, rows: Int) {
        if index == open.index { return (0, 0) }
        if row + size.rows <= open.row { return (0, -1) }
        if row >= open.row + open.size.rows { return (0, 1) }
        return (column < open.column ? -1 : 1, 0)
    }

    /// Where the spot lies in the grid.
    public var rect: CGRect {
        CGRect(
            x: CGFloat(column) * (SpotTokens.cell + SpotTokens.columnGap),
            y: CGFloat(row) * (SpotTokens.rowHeight + SpotTokens.rowGap) + top,
            width: SpotTokens.width(columns: size.columns),
            height: SpotTokens.height(rows: size.rows)
        )
    }
}
