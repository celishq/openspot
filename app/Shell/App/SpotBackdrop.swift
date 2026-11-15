import OpenspotCore
import SwiftUI

struct SpotBackdrop: View {
    let model: SpotsModel
    let gridHeight: CGFloat
    let sheetHeight: CGFloat
    let menuHeight: CGFloat
    let drawsBlur: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let height = max(model.transition.isOpen ? sheetHeight : gridHeight, menuHeight)
        ZStack(alignment: .top) {
            if drawsBlur {
                SpotSoftBlur()
                    .mask { SpotSoftMask(height: height, edge: SpotSoftMask.blur) }
                Color(nsColor: SpotTheme.palette(for: scheme).shade)
                    .mask { SpotSoftMask(height: height, edge: SpotSoftMask.tint) }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .modifier(SpotShownFade(isShown: model.isShown, hiddenScale: MotionTokens.backdropHiddenScale))
    }
}
