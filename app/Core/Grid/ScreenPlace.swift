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

    /// Where the dock of Edit Spots lies: along the bottom of the free area, centred under the panel's content and whole on
    /// the screen, with as many rows as fit under that content, up to `dockRows`, and one at least.
    public static func dock(under panel: CGRect, in area: CGRect) -> CGRect {
        let margin = SpotTokens.dockMargin
        let width = min(SpotTokens.dockWidth, area.width - 2 * margin)
        let x = min(max(panel.midX - width / 2, area.minX + margin), area.maxX - margin - width).rounded(.down)
        let room = panel.minY - area.minY - 2 * margin
        let rows = (1...SpotTokens.dockRows).last { SpotTokens.dockHeight(rows: $0) <= room } ?? 1
        return CGRect(x: x, y: area.minY + margin, width: width, height: SpotTokens.dockHeight(rows: rows))
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
