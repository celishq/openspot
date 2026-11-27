import Foundation

public struct ShelfSlot: Equatable, Sendable {
    public let side: ShelfSide
    public let cell: GridCell

    public init(side: ShelfSide, cell: GridCell) {
        self.side = side
        self.cell = cell
    }
}
