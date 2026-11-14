import Foundation

public struct SpotPlacement: Equatable, Sendable {
    public enum Group: Equatable, Sendable {
        case grid, shelf
    }

    public let index: Int
    public let row: Int
    public let column: Int
    public let size: SpotSize
    public let group: Group?

    public init(index: Int, row: Int, column: Int, size: SpotSize, group: Group? = nil) {
        self.index = index
        self.row = row
        self.column = column
        self.size = size
        self.group = group
    }

    public var top: CGFloat {
        switch group {
        case nil: 0
        case .grid: SpotTokens.groupTitleBand
        case .shelf: 2 * SpotTokens.groupTitleBand
        }
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
            y: CGFloat(row) * (SpotTokens.rowHeight + SpotTokens.rowGap) + top,
            width: SpotTokens.width(columns: size.columns),
            height: SpotTokens.height(rows: size.rows)
        )
    }
}
