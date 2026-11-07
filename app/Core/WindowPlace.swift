import Foundation

/// A frame that a window is asked to take inside the usable area of its screen.
/// A window that keeps its own size holds each edge of the area that the frame touches, and is centred on the rest.
public struct WindowPlace: Equatable, Sendable {
    public let target: CGRect
    public let area: CGRect

    public init(target: CGRect, area: CGRect) {
        self.target = target
        self.area = area
    }

    /// The top left corner for a window of this real size.
    public func origin(for size: CGSize) -> CGPoint {
        CGPoint(
            x: Self.start(target.minX, target.maxX, area.minX, area.maxX, size.width),
            y: Self.start(target.minY, target.maxY, area.minY, area.maxY, size.height)
        )
    }

    private static func start(_ low: CGFloat, _ high: CGFloat, _ areaLow: CGFloat, _ areaHigh: CGFloat, _ length: CGFloat) -> CGFloat {
        if abs(low - areaLow) < 1 { return low }
        if abs(high - areaHigh) < 1 { return high - length }
        return (low + (high - low - length) / 2).rounded()
    }
}
