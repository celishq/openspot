import OpenspotCore
import SwiftUI

/// The look of a card that the person lifts in Edit Spots: a little larger, on a solid fill with a shadow, so that it
/// hides the cards it passes over. The fill shows at once when the card lifts, stays while it lands, then fades.
struct SpotLiftedCard: ViewModifier {
    let isLifted: Bool
    /// Whether the card is lifted or still on its way to its place.
    let isSolid: Bool
    let size: SpotSize

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: SpotTokens.corner(for: size), style: .continuous)
        return content
            .background {
                shape.fill(SpotTheme.window)
                    .shadow(color: .black.opacity(SpotTheme.liftShadowStrength), radius: SpotTheme.liftShadow, y: 4)
                    .opacity(isSolid ? 1 : 0)
                    .animation(isSolid ? nil : SpotMotion.fade(isShown: true), value: isSolid)
            }
            .scaleEffect(isLifted ? MotionTokens.liftedScale : 1)
    }
}
