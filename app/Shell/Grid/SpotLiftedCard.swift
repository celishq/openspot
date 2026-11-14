import OpenspotCore
import SwiftUI

struct SpotLiftedCard: ViewModifier {
    let isLifted: Bool
    let isSolid: Bool
    let size: SpotSize

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: SpotTokens.corner(for: size), style: .continuous)
        return content
            .background {
                ZStack {
                    if isSolid {
                        shape.fill(SpotTheme.window)
                            .shadow(color: .black.opacity(SpotTheme.liftShadowStrength), radius: SpotTheme.liftShadow, y: 4)
                            .transition(.opacity)
                    }
                }
                .animation(isSolid ? nil : SpotMotion.fade(isShown: true), value: isSolid)
            }
            .scaleEffect(isLifted ? MotionTokens.liftedScale : 1)
    }
}
