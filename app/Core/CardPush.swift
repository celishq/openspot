import Foundation

/// A card that an opening sheet pushes from its rect by an offset, in a straight line.
public struct CardPush: Equatable, Sendable {
    public let from: CGRect
    public let by: CGSize

    public init(from: CGRect, by: CGSize) {
        self.from = from
        self.by = by
    }

    /// The share of the push, from 0 to 1, at which the card first lies partly outside `bounds`; 1 when it never does.
    public func exit(from bounds: CGRect) -> Double {
        let limits = [
            (from.maxX, by.width, bounds.maxX),
            (-from.minX, -by.width, -bounds.minX),
            (from.maxY, by.height, bounds.maxY),
            (-from.minY, -by.height, -bounds.minY)
        ]
        return limits.map { edge, move, limit -> Double in
            if edge > limit { return 0 }
            guard move > 0 else { return 1 }
            return min(Double((limit - edge) / move), 1)
        }.min() ?? 1
    }
}
