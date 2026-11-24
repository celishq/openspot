import Foundation

public struct SpringEnd: Hashable, Sendable {
    public let duration: Double
    public let bounce: Double

    public init(duration: Double, bounce: Double) {
        self.duration = duration
        self.bounce = bounce
    }

    var pace: Double { 2 * .pi / duration }
    var damping: Double { 1 - bounce }
    var swing: Double { pace * (1 - min(damping, 1) * min(damping, 1)).squareRoot() }

    public func isDone(offset: Double, speed: Double, travel: Double) -> Bool {
        reach(offset: offset, speed: speed) < MotionTokens.restFraction * travel
    }

    public func reach(offset: Double, speed: Double) -> Double {
        if damping >= 1 {
            let lift = speed + pace * offset
            return lift == 0 ? 0 : lift / pace * exp(pace * offset / lift - 1)
        }
        let turn = (speed + damping * pace * offset) / swing
        return (offset * offset + turn * turn).squareRoot()
    }
}
