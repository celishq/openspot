import OpenspotCore
import SwiftUI

struct SpotGlass: ViewModifier {
    var radius: CGFloat = SpotTokens.radius
    var isSolid = false
    var isBare = false
    @Environment(\.spotIsShown) private var isShown

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background { shape.fill(SpotTheme.solid).opacity(isSolid ? 1 : 0) }
            .glassEffect(isSolid || isBare ? .identity : .regular, in: shape)
            .opacity(isShown ? 1 : MotionTokens.hiddenOpacity)
            .allowsHitTesting(isShown)
            .scaleEffect(isShown ? 1 : MotionTokens.hiddenScale)
            .animation(SpotMotion.fade(isShown: isShown), value: isShown)
    }
}
