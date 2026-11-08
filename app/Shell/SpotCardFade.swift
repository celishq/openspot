import SwiftUI

/// The fade and shrink of a pushed card, in step with the sheet's spring: over the shares of the push in `fade`, and back
/// over the same places as a closing sheet brings the card back.
struct SpotCardFade: CustomAnimation {
    /// The shares of the push over which the card fades.
    let fade: ClosedRange<Double>
    let isOpen: Bool

    func animate<V: VectorArithmetic>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? {
        guard time < (isOpen ? SpotMotion.openDuration : SpotMotion.closeDuration) else { return nil }
        let travel = SpotMotion.sheetShare(isOpen: isOpen, at: time)
        let place = isOpen ? travel : 1 - travel
        let span = fade.upperBound - fade.lowerBound
        let faded = span > 0 ? min(max((place - fade.lowerBound) / span, 0), 1) : place >= fade.upperBound ? 1 : 0
        return value.scaled(by: isOpen ? faded : 1 - faded)
    }
}
