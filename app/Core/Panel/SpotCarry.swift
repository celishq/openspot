import Foundation

/// A card that the person carries in Edit Spots, which the window draws over the panel and the dock: the spot, the size it
/// shows, whether a release on the dock turns it off, and whether it lies over the dock now.
public struct SpotCarry: Equatable {
    public let entry: SpotsModel.Entry
    public var size: SpotSize
    public let turnsOff: Bool
    public var isOverDock = false

    public init(entry: SpotsModel.Entry, size: SpotSize, turnsOff: Bool) {
        self.entry = entry
        self.size = size
        self.turnsOff = turnsOff
    }
}
