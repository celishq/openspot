import Foundation

public struct PanelFoot: Equatable, Sendable {
    public var closed: CGFloat
    public var open: CGFloat

    public init(closed: CGFloat, open: CGFloat) {
        self.closed = closed
        self.open = open
    }

    public func path(at progress: Double) -> CGFloat {
        guard open < closed else { return closed }
        return closed + (open - closed) * CGFloat(min(progress / MotionTokens.cardShare, 1))
    }

    public func moved(by offset: CGFloat) -> PanelFoot {
        PanelFoot(closed: closed + offset, open: open + offset)
    }

    func meeting(of rect: CGRect, movingDown move: CGFloat) -> Double? {
        guard rect.maxY < closed else { return 0 }
        let rise = max(closed - open, 0) / CGFloat(MotionTokens.cardShare)
        if move + rise > 0 {
            let meeting = Double((closed - rect.maxY) / (move + rise))
            if rise == 0 || meeting <= MotionTokens.cardShare { return min(meeting, 1) }
        }
        guard move > 0 else { return nil }
        return min(Double((open - rect.maxY) / move), 1)
    }
}
