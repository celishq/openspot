import OpenspotCore
import SwiftUI

/// A Control Center surface: a heavier blur, a light grey fill and a rim.
/// A solid surface is the plain solid colour, with no rim. A bare surface draws no blur and no rim.
struct SpotGlass: ViewModifier {
    var radius: CGFloat = SpotTokens.radius
    var isSolid = false
    var isBare = false
    /// Whether the surface draws its own blur. A card of the grid draws none: the grid's blur lies under it.
    var blursBehind = true
    /// The size of a surface that keeps one size, which draws its rim from a picture.
    var rimSize: CGSize?
    @Environment(\.spotIsShown) private var isShown

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .opacity(isShown ? 1 : MotionTokens.hiddenOpacity)
            .animation(SpotMotion.fade(isShown: isShown), value: isShown)
            .background {
                if blursBehind {
                    SpotBlur(radius: SpotTheme.blur)
                        .overlay(SpotTheme.glass)
                        .clipShape(shape)
                        .opacity(isSolid || isBare ? 0 : shown)
                }
                shape.fill(SpotTheme.solid).opacity(isSolid ? shown : 0)
            }
            .animation(SpotMotion.fade(isShown: isShown), value: isShown)
            .overlay {
                rim
                    .opacity(isSolid || isBare ? 0 : shown)
                    .animation(SpotMotion.fade(isShown: isShown), value: isShown)
                    .allowsHitTesting(false)
            }
            .scaleEffect(isShown ? 1 : MotionTokens.hiddenScale)
            .animation(SpotMotion.fade(isShown: isShown), value: isShown)
    }

    /// The strength of the surface's look: whole while the panel shows, and hidden but still drawn while it hides.
    private var shown: Double {
        isShown ? 1 : MotionTokens.hiddenOpacity
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
