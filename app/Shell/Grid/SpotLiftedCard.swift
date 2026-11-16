import OpenspotCore
import SwiftUI

struct SpotLiftedCard: ViewModifier {
    let isLifted: Bool
    let isSolid: Bool
    let size: SpotSize

    func body(content: Content) -> some View {
        let shape = SpotRoundShape(SurfaceEdge(card: size, mark: .lift))
        return content
            .background {
                ZStack {
                    if isSolid {
                        shape.fill(SpotTheme.window)
                            .shadow(color: SpotTheme.liftShadowColor.opacity(SpotTheme.liftShadowStrength), radius: SpotTheme.liftShadow, y: SpotTheme.liftShadowDrop)
                            .transition(.opacity)
                    }
                }
                .animation(isSolid ? nil : SpotMotion.fade(isShown: true), value: isSolid)
            }
            .scaleEffect(isLifted ? MotionTokens.liftedScale : 1)
    }
}
