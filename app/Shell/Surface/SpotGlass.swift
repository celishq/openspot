import OpenspotCore
import SwiftUI

struct SpotGlass: ViewModifier {
    let shape: SpotRoundShape
    let isSolid: Bool?
    let isBare: Bool
    @Environment(\.spotIsShown) private var isShown
    @Environment(\.spotFade) private var fade

    init(shape: SpotRoundShape = SpotRoundShape(radius: SpotTokens.cardRadius), isSolid: Bool? = nil, isBare: Bool = false) {
        self.shape = shape
        self.isSolid = isSolid
        self.isBare = isBare
    }

    func body(content: Content) -> some View {
        let fade = fade
        content
            .background {
                if let isSolid { shape.fill(SpotTheme.solid).opacity(isSolid ? 1 : MotionTokens.hiddenOpacity).allowsHitTesting(false) }
            }
            .opacity(fade)
            .spotGlass(isSolid != true && !isBare, in: shape)
            .background { if !isBare { SpotCardShadow(shape: shape) } }
            .opacity(SpotTheme.glassStrength(at: fade))
            .opacity(isShown ? 1 : MotionTokens.hiddenOpacity)
            .allowsHitTesting(isShown)
            .scaleEffect(isShown ? 1 : MotionTokens.hiddenScale)
            .animation(SpotMotion.fade(isShown: isShown), value: isShown)
    }
}
