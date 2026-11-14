import Foundation

public struct ActionMenuFrame: Equatable, Sendable {
    public enum Edge: Equatable, Sendable { case top, bottom }
    public enum Side: Equatable, Sendable { case left, right }

    public static let width = SpotTokens.width(columns: 3)
    public static let gap = SpotTokens.placeGap
    private static let tie: CGFloat = 1
    private static let margin: CGFloat = 16
    private static let step = SpotTokens.menuRowHeight + SpotTokens.menuRowGap

    public let rect: CGRect
    public let stillEdge: Edge
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

    public static func bounds(under top: CGFloat, in panel: CGRect = GridPanels().frame) -> CGRect {
        let bottom = SpotTokens.panelHeight - SpotTokens.halo - SpotTokens.hintBlock
        return CGRect(x: panel.minX + margin, y: top, width: panel.width - 2 * margin, height: bottom - top)
    }

    public func rect(height: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: stillEdge == .bottom ? rect.maxY - height : rect.minY, width: rect.width, height: height)
    }

    public func rect(of menu: ActionMenu) -> CGRect {
        rect(height: SpotTokens.menuHeight(rows: menu.lines))
    }

    public func fieldRect(of menu: ActionMenu) -> CGRect? {
        guard menu.isSearchable else { return nil }
        return line(stillEdge == .top ? 0 : menu.shown.count + menu.headers.count, of: menu)
    }

    public func rowRect(_ index: Int, of menu: ActionMenu) -> CGRect {
        line(menu.line(ofShown: index) + (menu.isSearchable && stillEdge == .top ? 1 : 0), of: menu)
    }

    public func headerRect(_ header: ActionMenu.Header, of menu: ActionMenu) -> CGRect {
        line(header.line + (menu.isSearchable && stillEdge == .top ? 1 : 0), of: menu)
    }

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
