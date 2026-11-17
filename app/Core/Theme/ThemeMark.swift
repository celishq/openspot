import Foundation

public struct ThemeMark: Equatable, Sendable {
    public enum Shape: Equatable, Sendable {
        case band
        case arc(centre: CGPoint, radius: CGFloat)
    }

    public let key: ThemeKey
    public let rect: CGRect
    public let hit: CGRect
    public let shape: Shape
    public let axis: CGVector
    public let rate: CGFloat

    public init(key: ThemeKey, rect: CGRect, hit: CGRect? = nil, shape: Shape = .band, axis: CGVector, rate: CGFloat = 1) {
        self.key = key
        self.rect = rect
        self.hit = hit ?? rect
        self.shape = shape
        self.axis = axis
        self.rate = rate
    }

    public func value(after translation: CGSize, from start: Double, kind: ThemeKind) -> ConfigDocument.Value {
        let moved = Double((translation.width * axis.dx + translation.height * axis.dy) * rate)
        return kind.value(((start + moved) / kind.step).rounded() * kind.step)
    }
}
