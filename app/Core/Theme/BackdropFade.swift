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
    public let blur: CGFloat?

    public init(size: CGFloat, padding: CGFloat, corner: CGFloat, blur: CGFloat?) {
        self.size = size
        self.padding = padding
        self.corner = corner
        self.blur = blur
    }

    public static func current(blur: CGFloat?) -> BackdropFade {
        BackdropFade(size: CGFloat(SpotTokens.backdrop.size), padding: CGFloat(SpotTokens.backdrop.padding), corner: SpotTokens.cardRadius, blur: blur)
    }

    public func rings(in area: CGRect) -> [Ring] {
        let content = area.insetBy(dx: SpotTokens.halo, dy: SpotTokens.halo)
        let fade = max(size - padding, SpotTokens.backdropLeastFade)
        let steps = SpotTokens.backdropFadeSteps
        return (0...steps).map { step in
            let place = CGFloat(step) / CGFloat(steps)
            let outset = size - place * fade
            return Ring(rect: content.insetBy(dx: -outset, dy: -outset), corner: corner + SpotTokens.backdropCornerGrowth * outset, strength: strength(at: place))
        }
    }

    private func strength(at place: CGFloat) -> CGFloat {
        guard let blur, blur > 0 else { return place }
        let lost = place * place
        guard lost < 1 else { return 1 }
        let radius = SpotTokens.backdropHalfDetailBlur * pow(lost / (1 - lost), 1 / SpotTokens.backdropDetailFalloff)
        return min(pow(radius / blur, 1 / SpotTokens.backdropBlurResponse), 1)
    }
}
