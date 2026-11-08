import SwiftUI

/// The field's words while the field passes the sheet's header: they leave in the first quarter of the sheet's motion and
/// return in its second half. It runs on each change of `isOpen`, with no state of its own.
struct SpotFieldCrossing: ViewModifier {
    let isOpen: Bool
    /// Whether the words cross a header at all. The install screen grows out of the field and has none.
    let crosses: Bool

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 1.0, trigger: isOpen) { words, strength in
            words.opacity(strength)
        } keyframes: { _ in
            let duration = isOpen ? SpotMotion.openDuration : SpotMotion.closeDuration
            KeyframeTrack {
                LinearKeyframe(crosses ? 0 : 1, duration: duration / 4, timingCurve: .easeOut)
                LinearKeyframe(crosses ? 0 : 1, duration: duration / 4)
                LinearKeyframe(1, duration: duration / 2, timingCurve: .easeIn)
            }
        }
    }
}
