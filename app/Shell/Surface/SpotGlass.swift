import OpenspotCore
import SwiftUI

struct SpotGlass: ViewModifier {
    var radius: CGFloat = SpotTokens.radius
    var isSolid: Bool?
    var isBare = false
    @Environment(\.spotIsShown) private var isShown
    @Environment(\.spotFade) private var fade
    @Environment(\.spotScrollFade) private var edge

    func body(content: Content) -> some View {
        let shape = SpotRoundShape(radius: radius)
        let fade = fade
        let edge = edge
        let space = SpotsView.panelSpace
        content
            .background {
                if let isSolid { shape.fill(SpotTheme.solid).opacity(isSolid ? 1 : MotionTokens.hiddenOpacity).allowsHitTesting(false) }
            }
            .opacity(fade)
            .visualEffect { content, place in content.opacity(edge?.strength(of: place.frame(in: .named(space))) ?? 1) }
            .spotGlass(isSolid != true && !isBare, in: shape)
            .visualEffect { content, place in
                content.opacity(SpotTheme.glassStrength(at: fade * (edge?.strength(of: place.frame(in: .named(space))) ?? 1)))
            }
            .opacity(isShown ? 1 : MotionTokens.hiddenOpacity)
            .allowsHitTesting(isShown)
            .scaleEffect(isShown ? 1 : MotionTokens.hiddenScale)
            .animation(SpotMotion.fade(isShown: isShown), value: isShown)
    }
}
