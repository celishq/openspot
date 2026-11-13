import OpenspotCore
import SwiftUI

/// Places the sheet in the panel, so that it can grow out of a card and collapse back into it. The content keeps the sheet's
/// size and moves by an offset alone; a shape that grows from the card's rect to the sheet's rect clips it and draws its
/// glass. A frame of the motion lays out nothing.
struct SpotSheetFrame: ViewModifier {
    /// Where the surface lies now: the card's rect before the sheet opens, and the sheet's rect when it is open.
    let rect: CGRect
    let radius: CGFloat
    /// Where the content lies when the sheet is open.
    let sheetRect: CGRect
    /// How far the content lies from its open place: as far as the card lies from the sheet's corner, and none when open.
    let shift: CGSize
    /// Reads whether the card is selected where it is called, which shows its ring as the card's look until the sheet opens.
    let isSelected: () -> Bool
    /// How far the sheet is open, from 0 on its card to 1.
    let progress: Double
    /// The arrow of the card, which stays at the moving trailing edge as the sheet grows out of the card.
    var arrow: AnyView?
    /// The size of the card, in whose top trailing corner the arrow lies.
    var arrowBox: CGSize = .zero
    @Environment(\.spotIsShown) private var isShown

    func body(content: Content) -> some View {
        let shape = SpotSurfaceShape(rect: rect, radius: radius)
        ZStack(alignment: .topLeading) {
            SpotSurface(rect: rect, radius: radius)
            content
                .frame(width: sheetRect.width, height: sheetRect.height, alignment: .topLeading)
                .offset(x: sheetRect.minX + shift.width, y: sheetRect.minY + shift.height)
                .opacity(isShown ? 1 : 0)
                .animation(SpotMotion.fade(isShown: isShown), value: isShown)
            if let arrow {
                arrow
                    .frame(width: arrowBox.width, height: arrowBox.height, alignment: .topTrailing)
                    .offset(x: rect.maxX - arrowBox.width, y: rect.minY)
            }
        }
        .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
        .clipShape(shape)
        .modifier(SheetRing(isSelected: isSelected, shape: shape, progress: progress))
        .scaleEffect(isShown ? 1 : MotionTokens.hiddenScale, anchor: UnitPoint(x: rect.midX / SpotTokens.panelWidth, y: rect.midY / SpotTokens.panelHeight))
        .animation(SpotMotion.fade(isShown: isShown), value: isShown)
    }
}

/// The ring of the card under the sheet. It reads the selection itself, so that a move of the selection reruns only it.
private struct SheetRing: ViewModifier {
    let isSelected: () -> Bool
    let shape: SpotSurfaceShape
    let progress: Double

    func body(content: Content) -> some View {
        content.modifier(SpotSelectionRing(isSelected: isSelected(), shape: shape, progress: progress))
    }
}
