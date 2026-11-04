import Foundation

public struct SpotPlacement: Equatable, Sendable {
    public let index: Int
    public let row: Int
    public let column: Int
    public let size: SpotSize

    public init(index: Int, row: Int, column: Int, size: SpotSize) {
        self.index = index
        self.row = row
        self.column = column
        self.size = size
    }

    /// The way this spot moves when another spot opens: up or down if it lies above or below it, else to its side.
    public func direction(awayFrom open: SpotPlacement) -> (columns: Int, rows: Int) {
        if index == open.index { return (0, 0) }
        if row + size.rows <= open.row { return (0, -1) }
        if row >= open.row + open.size.rows { return (0, 1) }
        return (column < open.column ? -1 : 1, 0)
    }
}
