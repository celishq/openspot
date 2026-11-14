import Foundation

public struct SpotGroupBands: Equatable, Sendable {
    public let grid: Int
    public let shelf: Int
    public let shelfTop: CGFloat

    public init?(_ placements: [SpotPlacement]) {
        var grid = 0, shelf = 0, top = CGFloat.infinity
        for placement in placements {
            switch placement.group {
            case .grid: grid += 1
            case .shelf:
                shelf += 1
                top = min(top, placement.rect.minY - SpotTokens.groupTitleBand)
            case nil: break
            }
        }
        guard shelf > 0 else { return nil }
        self.grid = grid
        self.shelf = shelf
        shelfTop = top
    }
}
