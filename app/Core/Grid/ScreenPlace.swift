import Foundation

/// Where a window of Openspot opens on the screens. The panel opens on the screen that holds most of the front window, or
/// with no window in front, on the screen of the pointer, and sits as a centred window sits (A18). A float opens at the
/// pointer (W4). Frames are in AppKit's points, which count from the bottom left of the main screen.
public struct ScreenPlace: Sendable {
    /// A screen: its whole frame, and the area that the menu bar and the Dock leave free.
    public struct Screen: Sendable {
        public let frame: CGRect
        public let area: CGRect

        public init(frame: CGRect, area: CGRect) {
            self.frame = frame
            self.area = area
        }
    }

    private let screens: [Screen]

    /// The screens of the Mac, the main screen first.
    public init(screens: [Screen]) {
        self.screens = screens
    }

    /// The origin of a panel of this size, or nil with no screen.
    public func origin(of size: CGSize, window: CGRect?, pointer: CGPoint) -> CGPoint? {
        guard let area = screen(window: window, pointer: pointer)?.area else { return nil }
        return CGPoint(x: (area.midX - size.width / 2).rounded(.down), y: (area.minY + (area.height - size.height) * 0.75).rounded(.down))
    }

    /// The origin of a float of this size: centred on the pointer, and moved in so that it lies whole in the free area of the
    /// pointer's screen (W4). Nil with no screen.
    public func origin(of size: CGSize, under pointer: CGPoint) -> CGPoint? {
        guard let area = screen(window: nil, pointer: pointer)?.area else { return nil }
        let x = min(max(pointer.x - size.width / 2, area.minX), area.maxX - size.width)
        let y = min(max(pointer.y - size.height / 2, area.minY), area.maxY - size.height)
        return CGPoint(x: x.rounded(.down), y: y.rounded(.down))
    }

    /// The origin of a toast of this size: hung centred under the menu bar item and moved in to lie whole on the item's
    /// screen, or with no item, at the top centre of the main screen's free area. Nil with no screen.
    public func origin(ofToast size: CGSize, under item: CGRect?) -> CGPoint? {
        if let item, let area = screens.first(where: { $0.frame.intersects(item) })?.area {
            let x = min(max(item.midX - size.width / 2, area.minX), area.maxX - size.width)
            return CGPoint(x: x.rounded(.down), y: (item.minY - size.height).rounded(.down))
        }
        guard let area = screens.first?.area else { return nil }
        return CGPoint(x: (area.midX - size.width / 2).rounded(.down), y: area.maxY - size.height)
    }

    /// How far Edit Spots lifts the panel, whose content is this rect from the window's top, so that the window's top meets
    /// the top of the free area, and where the store lies then: centred under the content, whole on the screen, and from
    /// the bottom of the free area up to a margin under the lifted content, one line of rows high at least.
    public static func edit(under content: CGRect, in area: CGRect) -> (lift: CGFloat, dock: CGRect) {
        let margin = SpotTokens.dockMargin
        let lift = area.maxY - content.maxY
        let width = min(SpotTokens.dockWidth, area.width - 2 * margin)
        let x = min(max(content.midX - width / 2, area.minX + margin), area.maxX - margin - width).rounded(.down)
        let height = max(content.minY + lift - area.minY - 2 * margin, SpotTokens.dockHeight(rows: 1))
        return (lift, CGRect(x: x, y: area.minY + margin, width: width, height: height))
    }

    private func screen(window: CGRect?, pointer: CGPoint) -> Screen? {
        if let window, let holding = screens.max(by: { Self.share(of: window, on: $0) < Self.share(of: window, on: $1) }),
           Self.share(of: window, on: holding) > 0 {
            return holding
        }
        return screens.first { $0.frame.contains(pointer) } ?? screens.first
    }

    private static func share(of window: CGRect, on screen: Screen) -> CGFloat {
        let part = window.intersection(screen.frame)
        return part.isNull ? 0 : part.width * part.height
    }

    /// A window's frame from the bounds that Core Graphics gives, which count from the top left of the main screen down.
    public static func frame(ofBounds bounds: CGRect, mainHeight: CGFloat) -> CGRect {
        CGRect(x: bounds.minX, y: mainHeight - bounds.maxY, width: bounds.width, height: bounds.height)
    }
}
