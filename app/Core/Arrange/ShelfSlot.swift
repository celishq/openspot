import Foundation

public struct ShelfSlot: Equatable, Sendable {
    public let side: Int
    public let cell: GridCell

    public init(side: Int, cell: GridCell) {
        self.side = min(max(side, 0), 1)
        self.cell = cell
    }
}
