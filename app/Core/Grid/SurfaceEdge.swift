import Foundation

public struct SurfaceEdge: Equatable, Sendable {
    public var radius: CGFloat
    public var inset: CGFloat

    public init(radius: CGFloat, inset: CGFloat = 0) {
        self.radius = radius
        self.inset = inset
    }

    public init(card size: SpotSize) {
        self.init(radius: SpotTokens.corner(for: size))
    }

    public func inset(by amount: CGFloat) -> SurfaceEdge {
        SurfaceEdge(radius: radius, inset: inset + amount)
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
