import Foundation

public struct ToastAnchor: Equatable, Sendable {
    public let midX: CGFloat
    public let top: CGFloat
    public let area: CGRect

    public func shift(for width: CGFloat) -> CGFloat {
        let half = min(width, area.width) / 2
        return min(max(midX, area.minX + half), area.maxX - half) - midX
    }
}
