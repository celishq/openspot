import OpenspotCore
import SwiftUI

struct SpotBackdrop: View {
    let model: SpotsModel
    let gridHeight: CGFloat
    let sheetHeight: CGFloat
    let menuHeight: CGFloat
    let drawsBlur: Bool
    @Environment(\.spotPanels) private var panels

    var body: some View {
        let phase = model.transition.phase
        let isOpen = model.transition.isOpen
        let gridIsTaller = max(gridHeight, menuHeight) >= max(sheetHeight, menuHeight)
        ZStack(alignment: .top) {
            blur(height: gridHeight, isShown: gridIsTaller ? !isOpen : phase != .open, fades: gridIsTaller)
            blur(height: sheetHeight, isShown: gridIsTaller ? phase != .closed : isOpen, fades: !gridIsTaller)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .modifier(SpotShownFade(isShown: model.isShown, hiddenScale: MotionTokens.backdropHiddenScale))
    }

    @ViewBuilder
    private func blur(height: CGFloat, isShown: Bool, fades: Bool) -> some View {
        let height = max(height, menuHeight)
        Group {
            if drawsBlur { SpotSoftBlur(height: height, width: panels.frame.width) } else { Color.clear }
        }
            .frame(height: height)
            .transaction { $0.animation = nil }
            .opacity(isShown ? 1 : MotionTokens.hiddenOpacity)
            .transaction { if !fades { $0.animation = nil } }
    }
}
