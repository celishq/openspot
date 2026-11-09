import Foundation

/// Where the panel opens (A18): on the screen that holds most of the front window, or with no window in front, on the
/// screen of the pointer. It sits as a centred window sits: in the middle across, and three quarters of the free height
/// up. Frames are in AppKit's points, which count from the bottom left of the main screen.
public struct PanelPlace: Sendable {
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
