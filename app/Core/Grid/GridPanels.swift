import Foundation

/// Which side panels the grid has beside its center panel. Each is four columns wide, with a column gap to the center, so
/// that the center panel keeps its place and its width whichever sides show.
public struct GridPanels: Equatable, Sendable {
    public var hasLeft = false
    public var hasRight = false

    public init(hasLeft: Bool = false, hasRight: Bool = false) {
        self.hasLeft = hasLeft
        self.hasRight = hasRight
    }

    /// Whether the grid has this panel. The center always shows, and takes no change.
    public subscript(panel: GridPanel) -> Bool {
        get {
            switch panel {
            case .left: hasLeft
            case .center: true
            case .right: hasRight
            }
        }
        set {
            switch panel {
            case .left: hasLeft = newValue
            case .center: break
            case .right: hasRight = newValue
            }
        }
    }

    /// The panel that a spot of this panel lies in: its own while the grid has it, and else the center.
    public func holding(_ panel: GridPanel) -> GridPanel {
        self[panel] ? panel : .center
    }

    /// The columns of the whole grid.
    public var columns: Int {
        SpotTokens.columns * ((hasLeft ? 1 : 0) + 1 + (hasRight ? 1 : 0))
    }

    /// The first column of a panel.
    public func firstColumn(of panel: GridPanel) -> Int {
        switch panel {
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

    /// The panel with these side panels, in the center panel's space.
    public var frame: CGRect {
        CGRect(x: -leftExtent, y: 0, width: SpotTokens.panelWidth + leftExtent + rightExtent, height: SpotTokens.panelHeight)
    }
}
