import Foundation

/// Where the actions menu lies at its item, and where each of its lines lies. It opens beside an item of one column, on the
/// side with more room, else under the item, or over it when the room under it is short. Its still edge, the one nearer its
/// item, holds the field and stays in place while a search takes rows away. It stays in its bounds.
public struct ActionMenuFrame: Equatable, Sendable {
    public enum Edge: Equatable, Sendable { case top, bottom }
    public enum Side: Equatable, Sendable { case left, right }

    public static let width = SpotTokens.width(columns: 3)
    public static let gap = SpotTokens.placeGap
    /// How far right of the middle an item may lie and still count as on the left, so that a centred item keeps one side.
    private static let tie: CGFloat = 1
    /// How far the menu stays from the panel's sides.
    private static let margin: CGFloat = 16
    private static let step = SpotTokens.menuRowHeight + SpotTokens.menuRowGap

    /// The menu with no search, which sets its place.
    public let rect: CGRect
    public let stillEdge: Edge
    /// The side of the menu that lines up with its item, which it grows from.
    public let side: Side

    public init(item: CGRect, menu: ActionMenu, bounds: CGRect) {
        self.init(item: item, height: SpotTokens.menuHeight(rows: menu.fullLines), bounds: bounds)
    }

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
        stillEdge = origin.y + height / 2 < item.midY ? .bottom : .top
        side = isOnLeft ? .left : .right
    }

    /// Where a menu may lie in a panel this wide: from this top down to the hint line's place at the panel's foot.
    public static func bounds(under top: CGFloat, panelWidth: CGFloat = SpotTokens.panelWidth) -> CGRect {
        let bottom = SpotTokens.panelHeight - SpotTokens.halo - SpotTokens.hintBlock
        return CGRect(x: margin, y: top, width: panelWidth - 2 * margin, height: bottom - top)
    }

    /// The menu at the smaller height that a search leaves, with its still edge in place.
    public func rect(height: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: stillEdge == .bottom ? rect.maxY - height : rect.minY, width: rect.width, height: height)
    }

    /// The menu as its search leaves it.
    public func rect(of menu: ActionMenu) -> CGRect {
        rect(height: SpotTokens.menuHeight(rows: menu.lines))
    }

    /// The field of a menu that searches, on its still edge.
    public func fieldRect(of menu: ActionMenu) -> CGRect? {
        guard menu.isSearchable else { return nil }
        return line(stillEdge == .top ? 0 : menu.shown.count, of: menu)
    }

    /// The shown row at this index.
    public func rowRect(_ index: Int, of menu: ActionMenu) -> CGRect {
        line(index + (menu.isSearchable && stillEdge == .top ? 1 : 0), of: menu)
    }

    /// The index of the shown row at a point, or nil off its rows.
    public func row(at point: CGPoint, of menu: ActionMenu) -> Int? {
        menu.shown.indices.first { rowRect($0, of: menu).contains(point) }
    }

    private func line(_ index: Int, of menu: ActionMenu) -> CGRect {
        let menuRect = rect(of: menu)
        return CGRect(
            x: menuRect.minX + SpotTokens.menuPadding,
            y: menuRect.minY + SpotTokens.menuPadding + CGFloat(index) * Self.step,
            width: menuRect.width - 2 * SpotTokens.menuPadding,
            height: SpotTokens.menuRowHeight
        )
    }
}
