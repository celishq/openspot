import OpenspotCore
import SwiftUI

/// A Control Center surface at a rect of the panel: one blur of a fixed size seen through its shape, a tint, a fill and a
/// rim. Only the shape moves, so a surface that grows lays out nothing and resizes no AppKit view.
struct SpotSurface: View {
    let rect: CGRect
    let radius: CGFloat
    /// How strong the blur, the tint and the rim are, from 0 to 1.
    var glass = 1.0
    /// How strong the fill of a row is, from 0 to 1.
    var fill = 0.0
    @Environment(\.spotIsShown) private var isShown
    @Environment(\.spotPanelWidth) private var panelWidth

    var body: some View {
        let shape = SpotSurfaceShape(rect: rect, radius: radius)
        ZStack(alignment: .topLeading) {
            SpotBlur(radius: SpotTheme.blur)
                .overlay(SpotTheme.glass)
                .mask(shape)
                .opacity(isShown ? glass : MotionTokens.hiddenOpacity)
                .animation(SpotMotion.fade(isShown: isShown), value: isShown)
            shape.fill(SpotTheme.ink.opacity(SpotTheme.fill * fill))
            SpotRim(radius: radius, rect: rect)
                .opacity(isShown ? glass : MotionTokens.hiddenOpacity)
                .animation(SpotMotion.fade(isShown: isShown), value: isShown)
        }
        .frame(width: panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}
