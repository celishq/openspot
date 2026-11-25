import Foundation
@testable import OpenspotCore

extension SpringEnd {
    func path(at time: Double) -> (offset: Double, speed: Double) {
        let decay = exp(-min(damping, 1) * pace * time)
        if damping >= 1 {
            return ((1 + pace * time) * decay, pace * pace * time * decay)
        }
        let offset = decay * (cos(swing * time) + damping * pace / swing * sin(swing * time))
        return (offset, abs(decay * pace * pace / swing * sin(swing * time)))
    }

    func end() -> Double? {
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
