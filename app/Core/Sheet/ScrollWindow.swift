import Foundation

public struct ScrollWindow: Equatable, Sendable {
    public let top: Double
    public let bottom: Double
    public let viewHeight: Double
    public let contentHeight: Double

    public init(top: Double, bottom: Double, viewHeight: Double, contentHeight: Double) {
        self.top = top
        self.bottom = bottom
        self.viewHeight = viewHeight
        self.contentHeight = contentHeight
    }

    public func offset(showing span: ClosedRange<Double>, from offset: Double) -> Double {
        var moved = offset
        if span.upperBound - moved > bottom { moved = span.upperBound - bottom }
        if span.lowerBound - moved < top { moved = span.lowerBound - top }
        return min(max(moved, 0), max(contentHeight - viewHeight, 0))
    }

    public func offset(scrolling point: Double, from offset: Double, by step: Double, over zone: Double) -> Double {
        let shown = point - offset
        let depth = shown > bottom ? min((shown - bottom) / zone, 1) : shown < top ? -min((top - shown) / zone, 1) : 0
        return min(max(offset + step * depth, 0), max(contentHeight - viewHeight, 0))
    }
}
