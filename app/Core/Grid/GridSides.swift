import Foundation

/// Which side panels the grid has beside its center panel. Each is four columns wide, with a column gap to the center, so
/// that the center panel keeps its place and its width whichever sides show.
public struct GridSides: Equatable, Sendable {
    public var hasLeft = false
    public var hasRight = false

    public init(hasLeft: Bool = false, hasRight: Bool = false) {
        self.hasLeft = hasLeft
        self.hasRight = hasRight
    }

    public func has(_ side: SpotSide) -> Bool {
        switch side {
        case .left: hasLeft
        case .center: true
        case .right: hasRight
        }
    }

    /// The columns of the whole grid.
    public var columns: Int {
        SpotTokens.columns * ((hasLeft ? 1 : 0) + 1 + (hasRight ? 1 : 0))
    }

    /// The first column of a side's panel.
    public func firstColumn(of side: SpotSide) -> Int {
        switch side {
        case .left: 0
        case .center: hasLeft ? SpotTokens.columns : 0
        case .right: (hasLeft ? 2 : 1) * SpotTokens.columns
        }
    }

    /// How far the grid reaches left of the center panel's left edge.
    public var leftExtent: CGFloat {
        hasLeft ? SpotTokens.gridWidth + SpotTokens.columnGap : 0
    }

    /// How far the grid reaches right of the center panel's right edge.
    public var rightExtent: CGFloat {
        hasRight ? SpotTokens.gridWidth + SpotTokens.columnGap : 0
    }
}
