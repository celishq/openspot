import Foundation

public struct ShelfLayout: Equatable, Sendable {
    public let columns: Int
    public let left: CGFloat
    public let right: CGFloat
    public let band: ClosedRange<CGFloat>

    public init(screen: CGSize, panel: CGRect) {
        let card = SpotTokens.shelfCard.width
        let gap = SpotTokens.shelfColumnGap
        let margin = SpotTokens.arrangeMargin
        let room = min(panel.minX, screen.width - panel.maxX) - 2 * margin
        columns = max(Int(((room + gap) / (card + gap)).rounded(.down)), 1)
        left = margin
        right = screen.width - margin - Self.width(columns: columns)
        band = SpotTokens.arrangeBar...max(screen.height - SpotTokens.arrangeFoot, SpotTokens.arrangeBar)
    }

    public static func width(columns: Int) -> CGFloat {
        CGFloat(columns) * SpotTokens.shelfCard.width + CGFloat(max(columns - 1, 0)) * SpotTokens.shelfColumnGap
    }

    public var perRow: Int {
        2 * columns
    }

    public func rows(of count: Int) -> Int {
        (count + perRow - 1) / perRow
    }

    public func x(of index: Int) -> CGFloat {
        let column = index % perRow
        let side = column < columns ? left : right
        return side + CGFloat(column % columns) * (SpotTokens.shelfCard.width + SpotTokens.shelfColumnGap)
    }

    public var rowPitch: CGFloat {
        SpotTokens.shelfCard.height + SpotTokens.shelfRowGap
    }

    public func rect(of index: Int) -> CGRect {
        CGRect(origin: CGPoint(x: x(of: index), y: CGFloat(index / perRow) * rowPitch + SpotTokens.shelfRowGap), size: SpotTokens.shelfCard)
    }
}
