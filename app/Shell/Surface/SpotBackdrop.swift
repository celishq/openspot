import OpenspotCore
import SwiftUI

struct SpotBackdrop: View {
    let model: SpotsModel
    @Environment(\.spotDrawsGlass) private var drawsGlass
    @Environment(\.spotIsShown) private var isShown

    var body: some View {
        if drawsGlass {
            let rect = model.backdrop.offsetBy(dx: -model.panels.frame.minX, dy: 0)
            ZStack(alignment: .topLeading) {
                ForEach(Array(BackdropEdge.blurs.enumerated()), id: \.offset) { step, edge in
                    SpotBackdropBlur(radius: SpotTheme.backdropBlur * CGFloat(step + 1) / CGFloat(BackdropEdge.blurs.count))
                        .mask { SpotBackdropEdge(edge: edge, rect: rect) }
                }
                SpotBackdropEdge(edge: .shade, rect: rect)
                    .foregroundStyle(SpotTheme.shade)
            }
            .modifier(PanelSpan(panels: model.panels))
            .modifier(SpotShownFade(isShown: isShown))
            .allowsHitTesting(false)
        }
    }
}
