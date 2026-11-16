import Foundation

public struct BackdropEdge: Hashable, Sendable {
    public struct Piece: Equatable, Sendable {
        public let source: CGRect
        public let origin: CGPoint
        public let scale: CGSize

        public var frame: CGRect {
            CGRect(x: origin.x, y: origin.y, width: source.width * scale.width, height: source.height * scale.height)
        }
    }

    public let inset: CGFloat
    public let softness: CGFloat

    public static let blurs = SpotTokens.backdropSteps.map { BackdropEdge(inset: SpotTokens.halo * (1 - $0 / SpotTokens.backdropParts), softness: SpotTokens.halo / SpotTokens.backdropParts) }
    public static let reach = SpotTokens.backdropReach
    public static let middle = SpotTokens.backdropMiddle

    public var corner: CGFloat {
        SpotTokens.radius + SpotTokens.halo - inset
    }

    public var cap: CGSize {
        CGSize(
            width: min((inset + corner + Self.reach * softness).rounded(.up), (SpotTokens.panelWidth / 2).rounded(.down)),
            height: (SpotTokens.contentHeight(gridHeight: 0) / 2).rounded(.down)
        )
    }

    public var pictureSize: CGSize {
        CGSize(width: 2 * cap.width + Self.middle, height: 2 * cap.height + Self.middle)
    }

    public func pieces(in rect: CGRect) -> [Piece] {
        let columns = Self.bands(cap: cap.width, from: rect.minX, length: rect.width)
        let rows = Self.bands(cap: cap.height, from: rect.minY, length: rect.height)
        return rows.flatMap { row in
            columns.map { column in
                Piece(
                    source: CGRect(x: column.source, y: row.source, width: column.length, height: row.length),
                    origin: CGPoint(x: column.origin, y: row.origin),
                    scale: CGSize(width: column.scale, height: row.scale)
                )
            }
        }
    }

    private static func bands(cap: CGFloat, from start: CGFloat, length: CGFloat) -> [(source: CGFloat, length: CGFloat, origin: CGFloat, scale: CGFloat)] {
        let stretch = max(length - 2 * cap, 0)
        return [
            (0, cap, start, 1),
            (cap, middle, start + cap, stretch / middle),
            (cap + middle, cap, start + cap + stretch, 1)
        ]
    }
}
