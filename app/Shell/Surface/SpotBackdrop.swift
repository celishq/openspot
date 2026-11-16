import OpenspotCore
import SwiftUI

struct SpotBackdrop: View {
    let model: SpotsModel
    let motion: SheetMotion
    @Environment(\.spotDrawsGlass) private var drawsGlass
    @Environment(\.spotIsShown) private var isShown

    var body: some View {
        if drawsGlass {
            BackdropShape(rect: model.backdrop.offsetBy(dx: -model.panels.frame.minX, dy: 0), foot: model.panelFoot, motion: motion)
                .modifier(PanelSpan(panels: model.panels))
                .modifier(SpotShownFade(isShown: isShown))
                .allowsHitTesting(false)
        }
    }
}

private struct BackdropShape: View, @preconcurrency Animatable {
    var rect: CGRect
    var foot: PanelFoot
    var motion: SheetMotion

    var animatableData: AnimatablePair<CGRect.AnimatableData, AnimatablePair<PanelFoot.AnimatableData, Double>> {
        get { AnimatablePair(rect.animatableData, AnimatablePair(foot.animatableData, motion.progress)) }
        set {
            rect.animatableData = newValue.first
            foot.animatableData = newValue.second.first
            motion.progress = newValue.second.second
        }
    }

    var body: some View {
        var rect = rect
        rect.size.height = motion.place(of: foot)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(BackdropEdge.blurs.enumerated()), id: \.offset) { step, edge in
                SpotBackdropBlur(radius: SpotTheme.backdropBlur * CGFloat(step + 1) / CGFloat(BackdropEdge.blurs.count))
                    .mask { SpotBackdropEdge(edge: edge, rect: rect) }
            }
        }
    }
}
