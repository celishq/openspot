import Foundation

public struct SurfaceEdge: Equatable, Sendable {
    public var radius: CGFloat
    public var inset: CGFloat

    public init(radius: CGFloat, inset: CGFloat = 0) {
        self.radius = radius
        self.inset = inset
    }

    public static var sheet: SurfaceEdge { SurfaceEdge(radius: SpotTokens.cardRadius) }
    public static var window: SurfaceEdge { SurfaceEdge(radius: SpotTokens.windowRadius) }

    public init(card size: SpotSize) {
        self.init(radius: SpotTokens.corner(for: size))
    }

    public init(float kind: SpotKind, size: SpotSize) {
        self = kind.opensSheet ? .sheet : SurfaceEdge(card: size)
    }

    public init(card size: SpotSize, mark: CardMark) {
        self.init(card: size)
    }

    public var rim: CGFloat {
        radius * SpotTokens.rimPoint
    }

    public func inner(by padding: CGFloat = SpotTokens.padding) -> SurfaceEdge {
        SurfaceEdge(radius: max(radius - padding, 0))
    }

    public func inset(by amount: CGFloat) -> SurfaceEdge {
        SurfaceEdge(radius: radius, inset: inset + amount)
    }

    public func outset(by amount: CGFloat) -> SurfaceEdge {
        SurfaceEdge(radius: radius - amount, inset: inset - amount)
    }

    public func place(in rect: CGRect) -> CGRect {
        rect.insetBy(dx: inset, dy: inset)
    }

    public func corner(in rect: CGRect) -> CGFloat {
        let place = place(in: rect)
        return min(max(radius - inset, 0), min(place.width, place.height) / 2)
    }

    public func isCircular(in rect: CGRect) -> Bool {
        let place = place(in: rect)
        return 2 * corner(in: rect) >= min(place.width, place.height)
    }
}
