import SwiftUI

/// A Control Center surface: a heavier blur, a light grey fill and a rim.
/// A solid surface is the plain solid colour, with no rim. A bare surface draws no blur and no rim.
struct SpotGlass: ViewModifier {
    var radius: CGFloat = SpotTokens.radius
    var isSolid = false
    var isBare = false

    var strength = 1.0
    /// Whether the surface draws its own blur. A card of the grid draws it only while pressed, over the grid's blur.
    var blursBehind = true
    /// The size of a surface that keeps one size, which draws its rim from a picture.
    var rimSize: CGSize?
    @Environment(\.spotIsShown) private var isShown

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .opacity(isShown ? 1 : 0)
            .animation(SpotMotion.surface(isShown: isShown), value: isShown)
            .background {
                if blursBehind {
                    SpotBlur(radius: isShown ? SpotTheme.blur * strength : 0)
                        .overlay(SpotTheme.glass)
                        .clipShape(shape)
                        .opacity(isShown && !isSolid && !isBare ? 1 : 0)
                }
                shape.fill(SpotTheme.solid).opacity(isShown && isSolid ? 1 : 0)
            }
            .animation(SpotMotion.surface(isShown: isShown), value: isShown)
            .overlay {
                rim
                    .opacity(isShown && !isSolid && !isBare ? 1 : 0)
                    .animation(SpotMotion.rim(isShown: isShown), value: isShown)
                    .allowsHitTesting(false)
            }
            .scaleEffect(isShown ? 1 : SpotMotion.hiddenScale)
            .animation(SpotMotion.surface(isShown: isShown), value: isShown)
    }

    @ViewBuilder
    private var rim: some View {
        if let rimSize {
            SpotRimPicture(size: rimSize, radius: radius)
        } else {
            SpotRim(radius: radius)
        }
    }
}
