import OpenspotCore
import SwiftUI

/// Shows a view while the panel shows, and fades and shrinks it as the panel hides. Only its own look moves on the fade, so
/// no other change that comes with a show or a hide moves the view's content.
struct SpotShownFade: ViewModifier {
    let isShown: Bool
    var hiddenScale: CGFloat = 1
    var anchor = UnitPoint.center

    func body(content: Content) -> some View {
        content.animation(SpotMotion.fade(isShown: isShown)) {
            $0.opacity(isShown ? 1 : MotionTokens.hiddenOpacity)
                .scaleEffect(isShown ? 1 : hiddenScale, anchor: anchor)
        }
    }
}
