import Foundation

public struct BackdropFade: Equatable, Sendable {
    public struct Ring: Equatable, Sendable {
        public let rect: CGRect
        public let corner: CGFloat
        public let strength: CGFloat
    }

    public struct Stretch: Equatable, Sendable {
        public let split: Int
        public let shift: Int
    }

    public let size: CGFloat
    public let padding: CGFloat
    public let corner: CGFloat
    public let blur: CGFloat?
    public let ease: CGFloat
    public let roundness: CGFloat
    public let inset: CGFloat

    public init(size: CGFloat, padding: CGFloat, corner: CGFloat, blur: CGFloat?, ease: CGFloat, roundness: CGFloat, inset: CGFloat) {
        self.size = size
        self.padding = padding
        self.corner = corner
        self.blur = blur
        self.ease = ease
        self.roundness = roundness
        self.inset = inset
    }

    public static func current(blur: CGFloat?) -> BackdropFade {
        let backdrop = SpotTokens.backdrop
        return BackdropFade(
            size: CGFloat(backdrop.size), padding: CGFloat(backdrop.padding), corner: SpotTokens.cardRadius, blur: blur,
            ease: CGFloat(backdrop.ease), roundness: CGFloat(backdrop.roundness), inset: CGFloat(backdrop.inset)
        )
    }

    public func rings(in area: CGRect) -> [Ring] {
        let content = area.insetBy(dx: SpotTokens.halo, dy: SpotTokens.halo)
        let under = blur == nil ? 0 : inset
        let fade = max(size - padding, SpotTokens.backdropLeastFade) + under
        let steps = SpotTokens.backdropFadeSteps
        return (0...steps).map { step in
            let place = CGFloat(step) / CGFloat(steps)
            let outset = size - place * fade
            let rect = content.insetBy(dx: -outset, dy: -outset)
            let corner = min(max(corner + roundness * outset, 0), rect.width / 2, rect.height / 2)
            return Ring(rect: rect, corner: corner, strength: strength(at: place))
        }
    }

    public func stretch(from picture: CGRect, to area: CGRect, height: CGFloat, scale: CGFloat) -> Stretch? {
        guard area.minX == picture.minX, area.width == picture.width, area.minY == picture.minY, area.height <= picture.height else { return nil }
        let rings = rings(in: area)
        guard let top = rings.map({ $0.rect.minY + $0.corner }).max(), let foot = rings.map({ $0.rect.maxY - $0.corner }).min() else { return nil }
        let offset = (height * scale).rounded(.up) - height * scale
        let split = (top * scale + offset).rounded(.up)
        guard top < foot, split >= 0, split <= foot * scale + offset else { return nil }
        return Stretch(split: Int(split), shift: Int(((picture.height - area.height) * scale).rounded()))
    }

    private func strength(at place: CGFloat) -> CGFloat {
        guard let blur, blur > 0 else { return place }
        let least = SpotTokens.backdropLeastBlur
        let radius = least * (pow((blur + least) / least, pow(place, ease)) - 1)
        return min(pow(radius / blur, 1 / SpotTokens.backdropBlurResponse), 1)
    }
}
