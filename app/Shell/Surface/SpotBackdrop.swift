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
                SpotBackdropBlur()
                    .mask { SpotBackdropEdge(look: SpotTheme.backdropBlurEdge, rect: rect) }
                SpotBackdropEdge(look: SpotTheme.backdropShadeEdge, rect: rect)
                    .foregroundStyle(SpotTheme.shade)
            }
            .modifier(PanelSpan(panels: model.panels))
            .modifier(SpotShownFade(isShown: isShown))
            .allowsHitTesting(false)
        }
    }
}
