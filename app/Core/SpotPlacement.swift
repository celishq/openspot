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
}
