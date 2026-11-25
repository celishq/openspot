import Foundation

public struct CardPush: Equatable, Sendable {
    public let from: CGRect
    public let by: CGSize

    public init(from: CGRect, by: CGSize) {
        self.from = from
        self.by = by
    }

    public func fade(within bounds: CGRect) -> ClosedRange<Double>? {
        let axes = [
            (from.midX, by.width, bounds.maxX),
            (-from.midX, -by.width, -bounds.minX),
            (from.midY, by.height, bounds.maxY),
            (-from.midY, -by.height, -bounds.minY)
        ]
        let ends = axes.compactMap { centre, move, limit -> Double? in
            guard move > 0, centre + move > limit else { return nil }
            return min(max(Double((limit - centre) / move), 0), 1)
        }
        return ends.min().map { 0...$0 }
    }
}
