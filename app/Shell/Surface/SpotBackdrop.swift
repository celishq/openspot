import OpenspotCore
import SwiftUI

struct SpotBackdrop: View {
    let model: SpotsModel
    let motion: SheetMotion
    @Environment(\.spotDrawsGlass) private var drawsGlass
    @Environment(\.spotIsShown) private var isShown

    var body: some View {
        if drawsGlass, SpotTokens.backdrop.reach == .tiles {
            BackdropShape(rect: model.backdrop.offsetBy(dx: -model.panels.frame.minX, dy: 0), foot: model.panelFoot, motion: motion, style: SpotTokens.backdrop.style)
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
    let style: Theme.Backdrop.Style

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
            switch style {
            case .blur:
                ForEach(Array(BackdropEdge.blurs.enumerated()), id: \.offset) { step, edge in
                    SpotBackdropBlur(radius: SpotTokens.backdrop.blur * CGFloat(step + 1) / CGFloat(BackdropEdge.blurs.count))
                        .mask { SpotBackdropEdge(edge: edge, rect: rect) }
                }
            case .tint:
                SpotTheme.backdropTint.mask { BackdropTintMask(rect: rect) }
            }
        }
    }
}

private struct BackdropTintMask: View {
    let rect: CGRect

    var body: some View {
        let edges = BackdropEdge.blurs
        ZStack(alignment: .topLeading) {
            ForEach(Array(edges.enumerated()), id: \.offset) { _, edge in
                SpotBackdropEdge(edge: edge, rect: rect)
                    .opacity(1 / CGFloat(edges.count))
                    .blendMode(.plusLighter)
            }
        }
        .compositingGroup()
    }
}
