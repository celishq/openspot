import Foundation

public struct GridPanels: Equatable, Sendable {
    public var hasLeft = false
    public var hasRight = false

    public init(hasLeft: Bool = false, hasRight: Bool = false) {
        self.hasLeft = hasLeft
        self.hasRight = hasRight
    }

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

    public func holding(_ panel: GridPanel) -> GridPanel {
        self[panel] ? panel : .center
    }

    public var columns: Int {
        SpotTokens.columns * ((hasLeft ? 1 : 0) + 1 + (hasRight ? 1 : 0))
    }

    public func firstColumn(of panel: GridPanel) -> Int {
        switch panel {
        case .left: 0
        case .center: hasLeft ? SpotTokens.columns : 0
        case .right: (hasLeft ? 2 : 1) * SpotTokens.columns
        }
    }

    public var leftExtent: CGFloat {
        hasLeft ? SpotTokens.gridWidth + SpotTokens.columnGap : 0
    }

    public var rightExtent: CGFloat {
        hasRight ? SpotTokens.gridWidth + SpotTokens.columnGap : 0
    }

    public var frame: CGRect {
        CGRect(x: -leftExtent, y: 0, width: SpotTokens.panelWidth + leftExtent + rightExtent, height: SpotTokens.panelHeight)
    }
}
