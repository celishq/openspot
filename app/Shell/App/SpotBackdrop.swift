import OpenspotCore
import SwiftUI

/// The blur of the grid and the blur of the sheet, each with a fixed size. While the sheet moves, the shorter one stays whole
/// and the taller one fades on the sheet's own motion, so that where they overlap the backdrop keeps one strength. It alone
/// reads the phase of the sheet's motion.
struct SpotBackdrop: View {
    let model: SpotsModel
    let gridHeight: CGFloat
    let sheetHeight: CGFloat
    /// The height of the backdrop under the actions menu, which each blur keeps at the least.
    let menuHeight: CGFloat
    let drawsBlur: Bool
    @Environment(\.spotPanelWidth) private var panelWidth

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

    /// One blur of a fixed height. It fades on the sheet's motion when it `fades`, and else shows or hides at once.
    @ViewBuilder
    private func blur(height: CGFloat, isShown: Bool, fades: Bool) -> some View {
        let height = max(height, menuHeight)
        Group {
            if drawsBlur { SpotSoftBlur(height: height, width: panelWidth) } else { Color.clear }
        }
            .frame(height: height)
            .transaction { $0.animation = nil }
            .opacity(isShown ? 1 : MotionTokens.hiddenOpacity)
            .transaction { if !fades { $0.animation = nil } }
    }
}
