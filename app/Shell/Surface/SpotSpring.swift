import OpenspotCore
import SwiftUI

struct SpotSpring: CustomAnimation {
    let base: Animation
    let end: SpringEnd

    private struct Travel: AnimationStateKey {
        static var defaultValue: Double { 0 }
    }

    func animate<V: VectorArithmetic>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? {
        guard let current = base.animate(value: value, time: time, context: &context) else { return nil }
        let travel = max(context.state[Travel.self], value.magnitudeSquared.squareRoot())
        context.state[Travel.self] = travel
        let offset = (value - current).magnitudeSquared.squareRoot()
        let speed = base.velocity(value: value, time: time, context: context)?.magnitudeSquared.squareRoot() ?? 0
        return end.isDone(offset: offset, speed: speed, travel: travel) ? nil : current
    }

    func velocity<V: VectorArithmetic>(value: V, time: TimeInterval, context: AnimationContext<V>) -> V? {
        base.velocity(value: value, time: time, context: context)
    }

    func shouldMerge<V: VectorArithmetic>(previous: Animation, value: V, time: TimeInterval, context: inout AnimationContext<V>) -> Bool {
        base.shouldMerge(previous: (previous.base as? SpotSpring)?.base ?? previous, value: value, time: time, context: &context)
    }
}
