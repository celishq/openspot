import Foundation

/// A card that the person carries in Edit Spots, which the window draws over the panel: the spot, the size it shows, and
/// whether it glides to its place.
public struct SpotCarry: Equatable {
    public let entry: SpotsModel.Entry
    public var size: SpotSize
    public var isLanding = false

    public init(entry: SpotsModel.Entry, size: SpotSize) {
        self.entry = entry
        self.size = size
    }
}
