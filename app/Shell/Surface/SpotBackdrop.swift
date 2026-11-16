import OpenspotCore
import SwiftUI

struct SpotBackdrop: View {
    let model: SpotsModel
    let motion: SheetMotion
    @Environment(\.spotDrawsGlass) private var drawsGlass
    @Environment(\.spotIsShown) private var isShown

    var body: some View {
        if drawsGlass {
            FootMotion(foot: model.panelFoot, motion: motion) { height in
                BackdropShape(rect: model.backdrop.offsetBy(dx: -model.panels.frame.minX, dy: 0), height: height)
            }
            .modifier(PanelSpan(panels: model.panels))
            .modifier(SpotShownFade(isShown: isShown))
            .allowsHitTesting(false)
        }
    }
}

private struct BackdropShape: View, @preconcurrency Animatable {
    var rect: CGRect
    let height: CGFloat

    var animatableData: CGRect.AnimatableData {
        get { rect.animatableData }
        set { rect.animatableData = newValue }
    }

    var body: some View {
        var rect = rect
        rect.size.height = height
        return ZStack(alignment: .topLeading) {
            ForEach(Array(BackdropEdge.blurs.enumerated()), id: \.offset) { step, edge in
                SpotBackdropBlur(radius: SpotTheme.backdropBlur * CGFloat(step + 1) / CGFloat(BackdropEdge.blurs.count))
                    .mask { SpotBackdropEdge(edge: edge, rect: rect) }
            }
            SpotBackdropEdge(edge: .shade, rect: rect)
                .foregroundStyle(SpotTheme.shade)
        }
    }
}
