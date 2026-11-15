import Foundation

public struct SpotCarry: Equatable {
    public let entry: SpotsModel.Entry
    public var size: SpotSize
    public var isLanding = false

    public init(entry: SpotsModel.Entry, size: SpotSize) {
        self.entry = entry
        self.size = size
    }
}
