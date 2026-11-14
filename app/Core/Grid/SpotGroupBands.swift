import Foundation

/// The titles of the two groups of Edit Spots: how many cards lie on the grid and in search only, and where the Search only
/// group starts.
public struct SpotGroupBands: Equatable, Sendable {
    public let onGrid: Int
    public let searchOnly: Int
    /// The top of the Search only group's title band.
    public let shelfTop: CGFloat

    /// The bands of these placements, or nil when they lie in one group.
    public init?(_ placements: [SpotPlacement]) {
        let band = SpotTokens.groupTitleBand
        var onGrid = 0, searchOnly = 0, top = CGFloat.infinity
        for placement in placements {
            if placement.top == 2 * band {
                searchOnly += 1
                top = min(top, placement.rect.minY - band)
            } else if placement.top == band {
                onGrid += 1
            }
        }
        guard searchOnly > 0 else { return nil }
        self.onGrid = onGrid
        self.searchOnly = searchOnly
        shelfTop = top
    }
}
