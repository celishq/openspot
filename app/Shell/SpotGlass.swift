import SwiftUI

/// A Control Center surface: a heavier blur, a light grey fill and a rim.
/// A solid surface is the plain solid colour, with no rim. A bare surface draws no blur and no rim.
struct SpotGlass: ViewModifier {
    var radius: CGFloat = SpotTokens.radius
    var isSolid = false
    var isBare = false
    private static let shadowRadius: CGFloat = 10
    private static let shadowDrop: CGFloat = 3

    var strength = 1.0
    var shade = SpotTheme.glass
    @Environment(\.spotIsShown) private var isShown

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .opacity(isShown ? 1 : 0)
            .animation(SpotMotion.surface(isShown: isShown), value: isShown)
            .background {
                shape.fill(SpotTheme.shadowBase)
                    .shadow(color: SpotTheme.shadow, radius: Self.shadowRadius, y: Self.shadowDrop)
                    .opacity(isShown && !isBare ? 1 : 0)
                SpotBlur(radius: isShown ? SpotTheme.blur * strength : 0)
                    .overlay(shade)
                    .clipShape(shape)
                    .opacity(isShown && !isSolid && !isBare ? 1 : 0)
                shape.fill(SpotTheme.solid).opacity(isShown && isSolid ? 1 : 0)
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
