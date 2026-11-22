import CoreGraphics
import Foundation

public struct PartFrame: Equatable, Sendable {
    public enum Side: Equatable, Sendable {
        case fill, start, center, end
    }

    public let rect: CGRect
    public let horizontal: Side
    public let vertical: Side
    public let roundSize: CGFloat

    public init(node size: CGSize, part: SpotPart) {
        rect = CGRect(origin: .zero, size: size)
        horizontal = Self.side(part.align, default: part.fillsWidth ? .fill : .center)
        vertical = part.fillsHeight ? .fill : .center
        roundSize = min(size.width, size.height, SpotTokens.partMaxRound)
    }

    private static func side(_ align: SpotPart.Align?, default fallback: Side) -> Side {
        switch align {
        case nil: fallback
        case .left: .start
        case .center: .center
        case .right: .end
        }
    }
}
