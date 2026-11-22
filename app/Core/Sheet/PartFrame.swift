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

    public var hasDetailUnderTitle: Bool {
        rect.height >= SpotTokens.listRow * 2
    }

    public init(node size: CGSize, part: SpotPart) {
        rect = CGRect(origin: .zero, size: size)
        horizontal = part.fillsWidth ? .fill : .center
        vertical = part.fillsHeight ? .fill : .center
        roundSize = min(size.width, size.height, SpotTokens.partMaxRound)
    }
}
