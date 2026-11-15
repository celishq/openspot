import OpenspotCore
import SwiftUI

struct SpotGlass: ViewModifier {
    var radius: CGFloat = SpotTokens.radius
    var isSolid = false
    var isBare = false
    var blursBehind = true
    var rimSize: CGSize?
    @Environment(\.spotIsShown) private var isShown

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .opacity(isShown ? 1 : MotionTokens.hiddenOpacity)
            .animation(SpotMotion.fade(isShown: isShown), value: isShown)
            .allowsHitTesting(isShown)
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
