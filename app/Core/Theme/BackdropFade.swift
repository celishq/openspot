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
    public let ease: CGFloat
    public let roundness: CGFloat

    public init(size: CGFloat, padding: CGFloat, corner: CGFloat, blur: CGFloat?, ease: CGFloat, roundness: CGFloat) {
        self.size = size
        self.padding = padding
        self.corner = corner
        self.blur = blur
        self.ease = ease
        self.roundness = roundness
    }

    public static func current(blur: CGFloat?) -> BackdropFade {
        let backdrop = SpotTokens.backdrop
        return BackdropFade(
            size: CGFloat(backdrop.size), padding: CGFloat(backdrop.padding), corner: SpotTokens.cardRadius, blur: blur,
            ease: CGFloat(backdrop.ease), roundness: CGFloat(backdrop.roundness)
        )
    }

    public func rings(in area: CGRect) -> [Ring] {
        let content = area.insetBy(dx: SpotTokens.halo, dy: SpotTokens.halo)
        let under = blur == nil ? 0 : SpotTokens.backdropUnderTiles
        let fade = max(size - padding, SpotTokens.backdropLeastFade) + under
        let steps = SpotTokens.backdropFadeSteps
        return (0...steps).map { step in
            let place = CGFloat(step) / CGFloat(steps)
            let outset = size - place * fade
            return Ring(rect: content.insetBy(dx: -outset, dy: -outset), corner: max(corner + roundness * outset, 0), strength: strength(at: place))
        }
    }

    private func strength(at place: CGFloat) -> CGFloat {
        guard let blur, blur > 0 else { return place }
        let least = SpotTokens.backdropLeastBlur
        let radius = least * (pow((blur + least) / least, pow(place, ease)) - 1)
        return min(pow(radius / blur, 1 / SpotTokens.backdropBlurResponse), 1)
    }
}
