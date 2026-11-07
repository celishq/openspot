import Foundation

/// A sheet that grows from the rect of its card to its own rect, edge by edge in a straight line.
public struct SheetGrowth: Equatable, Sendable {
    public let from: CGRect
    public let to: CGRect

    public init(from: CGRect, to: CGRect) {
        self.from = from
        self.to = to
    }

    /// The share of the growth, from 0 to 1, at which the sheet first lies over a card; 1 when it never does.
    public func reach(of card: CGRect) -> Double {
        let limits = [
            Self.share(start: from.minX, end: to.minX, below: card.maxX),
            Self.share(start: -from.maxX, end: -to.maxX, below: -card.minX),
            Self.share(start: from.minY, end: to.minY, below: card.maxY),
            Self.share(start: -from.maxY, end: -to.maxY, below: -card.minY)
        ]
        let reach = limits.map(\.lower).max() ?? 0
        return reach < (limits.map(\.upper).min() ?? 1) ? reach : 1
    }

    /// The shares at which an edge that moves from `start` to `end` lies below `limit`.
    private static func share(start: CGFloat, end: CGFloat, below limit: CGFloat) -> (lower: Double, upper: Double) {
        let move = end - start
        if move == 0 { return start < limit ? (0, 1) : (1, 0) }
        let cross = Double((limit - start) / move)
        return move < 0 ? (min(max(cross, 0), 1), 1) : (0, min(max(cross, 0), 1))
    }
}
