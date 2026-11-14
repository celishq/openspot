import OpenspotCore
import SwiftUI

struct SpotSurface: View {
    let rect: CGRect
    let radius: CGFloat
    var glass = 1.0
    var fill = 0.0
    @Environment(\.spotIsShown) private var isShown
    @Environment(\.spotPanels) private var panels

    var body: some View {
        let rect = rect.offsetBy(dx: -panels.frame.minX, dy: 0)
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
        .modifier(PanelSpan(panels: panels))
        .allowsHitTesting(false)
    }
}
