import SwiftUI

/// A Control Center surface: a heavier blur, a light grey fill and a rim.
/// A solid surface is plain white, with no rim. A bare surface draws no blur and no rim.
struct SpotGlass: ViewModifier {
    var radius: CGFloat = SpotTokens.radius
    var isSolid = false
    var isBare = false
    var strength = 1.0
    @Environment(\.spotIsShown) private var isShown

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .opacity(isShown ? 1 : 0)
            .animation(SpotMotion.surface(isShown: isShown), value: isShown)
            .background {
                SpotBlur(radius: isShown ? SpotTokens.cardBlur * strength : 0)
                    .overlay(Color.black.opacity(0.22))
                    .clipShape(shape)
                    .opacity(isShown && !isSolid && !isBare ? 1 : 0)
                shape.fill(Color.white).opacity(isShown && isSolid ? 1 : 0)
            }
            .animation(SpotMotion.surface(isShown: isShown), value: isShown)
            .overlay {
                SpotRim(radius: radius)
                    .opacity(isShown && !isSolid && !isBare ? 1 : 0)
                    .animation(SpotMotion.rim(isShown: isShown), value: isShown)
                    .allowsHitTesting(false)
            }
            .scaleEffect(isShown ? 1 : SpotMotion.hiddenScale)
            .animation(SpotMotion.surface(isShown: isShown), value: isShown)
    }
}
