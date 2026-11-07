import SwiftUI

/// The fade or shrink of a pushed card, in step with the sheet's spring: over the shares of the push in `fade`, and back
/// over the same places as a closing sheet brings the card back. It starts `delay` seconds late.
struct SpotCardFade: CustomAnimation {
    /// The shares of the push over which the card changes.
    let fade: ClosedRange<Double>
    let isOpen: Bool
    let delay: Double

    func animate<V: VectorArithmetic>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? {
        let time = time - delay
        guard time < (isOpen ? SpotMotion.openDuration : SpotMotion.closeDuration) else { return nil }
        guard time > 0 else { return value.scaled(by: 0) }
        let travel = SpotMotion.sheetShare(isOpen: isOpen, at: time)
        let place = isOpen ? travel : 1 - travel
        let span = fade.upperBound - fade.lowerBound
        let faded = span > 0 ? min(max((place - fade.lowerBound) / span, 0), 1) : place >= fade.upperBound ? 1 : 0
        return value.scaled(by: isOpen ? faded : 1 - faded)
    }
}
