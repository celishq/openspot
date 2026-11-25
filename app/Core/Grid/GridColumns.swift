import Foundation

public struct GridColumns: Equatable, Sendable {
    public static let choices = [4, 6, 8]

    public let count: Int

    public init(_ count: Int = SpotTokens.columns) {
        self.count = Self.choices.contains(count) ? count : SpotTokens.columns
    }

    public var layout: GridLayout {
        GridLayout(columns: count)
    }

    public var leftExtent: CGFloat {
        let extra = (count - SpotTokens.columns) / 2
        return CGFloat(extra) * (SpotTokens.cell + SpotTokens.columnGap)
    }

    public var rightExtent: CGFloat {
        leftExtent
    }

    public var frame: CGRect {
        CGRect(x: -leftExtent, y: 0, width: SpotTokens.panelWidth + leftExtent + rightExtent, height: SpotTokens.panelHeight)
    }
}
