import Foundation

public struct GridSpot: Equatable, Sendable {
    public let size: SpotSize
    public let cell: GridCell?

    public init(size: SpotSize, cell: GridCell?) {
        self.size = size
        self.cell = cell
    }
}
