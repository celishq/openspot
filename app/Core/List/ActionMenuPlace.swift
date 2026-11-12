import Foundation

/// Where the actions menu lies at its item: beside an item of one column, on the side with more room, else under the item,
/// or over it when the room under it is short, on the item's side. It stays in its bounds.
public struct ActionMenuPlace: Equatable, Sendable {
    public static let width = SpotTokens.width(columns: 3)
    public static let gap = SpotTokens.placeGap
    /// How far right of the middle an item may lie and still count as on the left, so that a centred item keeps one side.
    private static let tie: CGFloat = 1

    public let rect: CGRect
    /// Whether the menu starts higher than its item, so that its bottom stays still as a search takes rows away.
    public let growsUp: Bool
    /// The corner of the menu nearest its item, which it grows from, as 0 or 1 on each axis: 0 is the left or the top.
    public let corner: CGPoint

    public init(item: CGRect, height: CGFloat, bounds: CGRect) {
        let isOnLeft = item.midX <= bounds.midX + Self.tie
        var origin: CGPoint
        if item.width <= SpotTokens.cell {
            origin = CGPoint(x: isOnLeft ? item.maxX + Self.gap : item.minX - Self.gap - Self.width, y: item.minY)
        } else {
            let under = item.maxY + Self.gap
            let over = item.minY - Self.gap - height
            let y = under + height <= bounds.maxY || over < bounds.minY ? under : over
            origin = CGPoint(x: isOnLeft ? item.minX : item.maxX - Self.width, y: y)
        }
        origin.x = min(max(origin.x, bounds.minX), bounds.maxX - Self.width)
        origin.y = max(min(origin.y, bounds.maxY - height), bounds.minY)
        rect = CGRect(origin: origin, size: CGSize(width: Self.width, height: height))
        growsUp = origin.y < item.minY
        corner = CGPoint(x: isOnLeft ? 0 : 1, y: growsUp ? 1 : 0)
    }

    /// The menu at the smaller height that a search leaves, with its still edge in place.
    public func rect(height: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: growsUp ? rect.maxY - height : rect.minY, width: rect.width, height: height)
    }
}
