import Foundation

/// A card that the person carries in Edit Spots, which the window draws over the panel and the dock: the spot, the size it
/// shows, whether it lies over the dock now, and whether it glides to its place.
public struct SpotCarry: Equatable {
    public let entry: SpotsModel.Entry
    public var size: SpotSize
    /// The tile of the dock that the card came from, in the panel's space. A card of the grid has none.
    public let tile: CGRect?
    public var isOverDock = false
    public var isLanding = false

    public init(entry: SpotsModel.Entry, size: SpotSize, tile: CGRect? = nil) {
        self.entry = entry
        self.size = size
        self.tile = tile
    }
}
