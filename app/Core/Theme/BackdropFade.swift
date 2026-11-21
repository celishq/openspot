import Foundation

public struct BackdropFade: Equatable, Sendable {
    public struct Ring: Equatable, Sendable {
        public let rect: CGRect
        public let corner: CGFloat
        public let strength: CGFloat
    }

    public let size: CGFloat
    public let padding: CGFloat

    public init(size: CGFloat, padding: CGFloat) {
        self.size = size
        self.padding = padding
    }

    public init(backdrop: Theme.Backdrop) {
        self.init(size: CGFloat(backdrop.size), padding: CGFloat(backdrop.padding))
    }

    public func rings(around content: CGRect) -> [Ring] {
        let steps = SpotTokens.backdropFadeSteps
        return (0...steps).map { step in
            let strength = CGFloat(step) / CGFloat(steps)
            let outset = size - strength * (size - padding)
            return Ring(rect: content.insetBy(dx: -outset, dy: -outset), corner: SpotTokens.cardRadius + outset, strength: strength)
        }
    }
}
