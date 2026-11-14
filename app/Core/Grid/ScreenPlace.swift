import Foundation

public struct ScreenPlace: Sendable {
    public struct Screen: Sendable {
        public let frame: CGRect
        public let area: CGRect

        public init(frame: CGRect, area: CGRect) {
            self.frame = frame
            self.area = area
        }
    }

    private let screens: [Screen]

    public init(screens: [Screen]) {
        self.screens = screens
    }

    public func origin(of size: CGSize, window: CGRect?, pointer: CGPoint) -> CGPoint? {
        guard let area = screen(window: window, pointer: pointer)?.area else { return nil }
        return CGPoint(x: (area.midX - size.width / 2).rounded(.down), y: (area.minY + (area.height - size.height) * 0.75).rounded(.down))
    }

    public func origin(of size: CGSize, beside window: CGRect) -> CGPoint? {
        guard let area = screen(window: window, pointer: CGPoint(x: window.midX, y: window.midY))?.area else { return nil }
        let right = window.maxX + Self.besideGap
        let x = right + size.width <= area.maxX ? right : max(window.minX - Self.besideGap - size.width, area.minX)
        let y = min(max(window.maxY - size.height, area.minY), area.maxY - size.height)
        return CGPoint(x: x.rounded(.down), y: y.rounded(.down))
    }

    static let besideGap: CGFloat = 12

    public func origin(of size: CGSize, under pointer: CGPoint) -> CGPoint? {
        guard let area = screen(window: nil, pointer: pointer)?.area else { return nil }
        let x = min(max(pointer.x - size.width / 2, area.minX), area.maxX - size.width)
        let y = min(max(pointer.y - size.height / 2, area.minY), area.maxY - size.height)
        return CGPoint(x: x.rounded(.down), y: y.rounded(.down))
    }

    public func origin(ofToast size: CGSize, inset: CGFloat, under item: CGRect?) -> CGPoint? {
        let lift = inset - SpotTokens.toastGap
        if let item, let area = screens.first(where: { $0.frame.intersects(item) })?.area {
            let x = min(max(item.midX - size.width / 2, area.minX), area.maxX - size.width)
            return CGPoint(x: x.rounded(.down), y: (item.minY - size.height + lift).rounded(.down))
        }
        guard let area = screens.first?.area else { return nil }
        return CGPoint(x: (area.midX - size.width / 2).rounded(.down), y: area.maxY - size.height + lift)
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

    public static func frame(ofBounds bounds: CGRect, mainHeight: CGFloat) -> CGRect {
        CGRect(x: bounds.minX, y: mainHeight - bounds.maxY, width: bounds.width, height: bounds.height)
    }
}
