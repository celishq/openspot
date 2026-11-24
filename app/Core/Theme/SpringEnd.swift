import Foundation

public struct SpringEnd: Hashable, Sendable {
    public let duration: Double
    public let bounce: Double

    public init(duration: Double, bounce: Double) {
        self.duration = duration
        self.bounce = bounce
    }

    private var pace: Double { 2 * .pi / duration }
    private var damping: Double { 1 - bounce }
    private var swing: Double { pace * (1 - min(damping, 1) * min(damping, 1)).squareRoot() }

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

    public func path(at time: Double) -> (offset: Double, speed: Double) {
        let decay = exp(-min(damping, 1) * pace * time)
        if damping >= 1 {
            return ((1 + pace * time) * decay, pace * pace * time * decay)
        }
        let offset = decay * (cos(swing * time) + damping * pace / swing * sin(swing * time))
        return (offset, abs(decay * pace * pace / swing * sin(swing * time)))
    }

    public func end() -> Double? {
        guard damping > 0 else { return nil }
        let step = duration / 1000
        var time = 0.0
        while true {
            let now = path(at: time)
            if isDone(offset: abs(now.offset), speed: now.speed, travel: 1) { return time }
            time += step
        }
    }
}
