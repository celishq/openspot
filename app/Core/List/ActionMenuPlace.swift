import Foundation

/// Where the actions menu lies at its item: beside an item of one column, on the side with more room, else under the item,
/// or over it when the room under it is short, on the item's side. It stays in its bounds.
public struct ActionMenuPlace: Equatable, Sendable {
    public static let width = SpotTokens.width(columns: 3)
    public static let gap = SpotTokens.placeGap

    public let rect: CGRect

    public init(item: CGRect, height: CGFloat, bounds: CGRect) {
        let isOnLeft = item.minX - bounds.minX <= bounds.maxX - item.maxX
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
    }
}
