import OpenspotCore
import SwiftUI

struct SpotBackdrop: View {
    let model: SpotsModel
    let morph: SheetMorph?
    let progress: Double
    @Environment(\.spotDrawsGlass) private var drawsGlass
    @Environment(\.spotIsShown) private var isShown

    var body: some View {
        if drawsGlass {
            BackdropShape(rect: model.backdrop.offsetBy(dx: -model.panels.frame.minX, dy: 0), morph: morph, progress: progress)
            .modifier(PanelSpan(panels: model.panels))
            .modifier(SpotShownFade(isShown: isShown))
            .allowsHitTesting(false)
        }
    }
}

private struct BackdropShape: View, @preconcurrency Animatable {
    var rect: CGRect
    let morph: SheetMorph?
    var progress: Double

    var animatableData: AnimatablePair<CGRect.AnimatableData, Double> {
        get { AnimatablePair(rect.animatableData, progress) }
        set {
            rect.animatableData = newValue.first
            progress = newValue.second
        }
    }

    var body: some View {
        var rect = rect
        if let morph { rect.size.height = max(rect.height, morph.foot(at: progress)) }
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
