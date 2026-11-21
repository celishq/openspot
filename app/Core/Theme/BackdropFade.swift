import Foundation

public struct BackdropFade: Equatable, Sendable {
    public struct Ring: Equatable, Sendable {
        public let rect: CGRect
        public let corner: CGFloat
        public let strength: CGFloat
    }

    public let size: CGFloat
    public let padding: CGFloat
    public let corner: CGFloat

    public init(size: CGFloat, padding: CGFloat, corner: CGFloat) {
        self.size = size
        self.padding = padding
        self.corner = corner
    }

    public static var current: BackdropFade {
        BackdropFade(size: CGFloat(SpotTokens.backdrop.size), padding: CGFloat(SpotTokens.backdrop.padding), corner: SpotTokens.cardRadius)
    }

    public func rings(in area: CGRect) -> [Ring] {
        let content = area.insetBy(dx: SpotTokens.halo, dy: SpotTokens.halo)
        let fade = max(size - padding, SpotTokens.backdropLeastFade)
        let steps = SpotTokens.backdropFadeSteps
        return (0...steps).map { step in
            let strength = CGFloat(step) / CGFloat(steps)
            let outset = size - strength * fade
            return Ring(rect: content.insetBy(dx: -outset, dy: -outset), corner: corner + outset, strength: strength)
        }
    }
}
