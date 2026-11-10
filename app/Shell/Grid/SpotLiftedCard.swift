import OpenspotCore
import SwiftUI

/// The look of a card that the person lifts in Edit Spots: a little larger, on a solid fill with a shadow, so that it
/// hides the cards it passes over.
struct SpotLiftedCard: ViewModifier {
    let isLifted: Bool
    let size: SpotSize

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: SpotTokens.corner(for: size), style: .continuous)
        return content
            .background {
                shape.fill(SpotTheme.window)
                    .shadow(color: .black.opacity(SpotTheme.liftShadowStrength), radius: SpotTheme.liftShadow, y: 4)
                    .opacity(isLifted ? 1 : 0)
            }
            .scaleEffect(isLifted ? SpotMotion.liftedScale : 1)
    }
}
