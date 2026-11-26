import Foundation

public final class CardTilt {
    private var now = CGPoint.zero

    public init() {}

    public func next(toward pointer: CGPoint?, at time: Double) -> CGPoint {
        let reach = MotionTokens.cardSwayReach, speed = MotionTokens.cardSwaySpeed
        let goal = pointer ?? CGPoint(x: sin(time * speed.x) * reach.x, y: sin(time * speed.y) * reach.y)
        let rate = pointer == nil ? MotionTokens.cardDrift : MotionTokens.cardFollow
        now = CGPoint(x: now.x + (goal.x - now.x) * rate, y: now.y + (goal.y - now.y) * rate)
        return now
    }
}
