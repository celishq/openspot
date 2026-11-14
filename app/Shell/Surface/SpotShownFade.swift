import OpenspotCore
import SwiftUI

struct SpotShownFade: ViewModifier {
    let isShown: Bool
    var hiddenScale: CGFloat = 1
    var anchor = UnitPoint.center

    func body(content: Content) -> some View {
        content.animation(SpotMotion.fade(isShown: isShown)) {
            $0.opacity(isShown ? 1 : MotionTokens.hiddenOpacity)
                .scaleEffect(isShown ? 1 : hiddenScale, anchor: anchor)
        }
        .allowsHitTesting(isShown)
    }
}
