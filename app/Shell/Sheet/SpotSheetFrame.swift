import OpenspotCore
import SwiftUI

/// Places the sheet in the panel, so that it can grow out of a card and collapse back into it. The content keeps the sheet's
/// size and moves by an offset alone; a shape that grows from the card's rect to the sheet's rect draws its glass and the fill
/// of a card that is on. Nothing clips the content: each part of it fades before the shape passes it. A frame of the motion
/// lays out nothing.
struct SpotSheetFrame: ViewModifier {
    /// Where the surface lies now: the card's rect before the sheet opens, and the sheet's rect when it is open.
    let rect: CGRect
    let radius: CGFloat
    /// Where the content lies when the sheet is open.
    let sheetRect: CGRect
    /// How far the content lies from its open place: as far as the card lies from the sheet's corner, and none when open.
    let shift: CGSize
    let showsRing: Bool
    /// Whether the shape shows the solid fill of a card that is on, and the fade of that fill.
    var showsSolid = false
    var solidFade: Animation?
    /// The arrow of the card, which stays at the moving trailing edge as the sheet grows out of the card.
    var arrow: AnyView?
    /// The size of the card, in whose top trailing corner the arrow lies.
    var arrowBox: CGSize = .zero
    @Environment(\.spotIsShown) private var isShown

    func body(content: Content) -> some View {
        let shape = SpotSurfaceShape(rect: rect, radius: radius)
        ZStack(alignment: .topLeading) {
            SpotSurface(rect: rect, radius: radius)
            shape.fill(SpotTheme.solid)
                .animation(solidFade) { $0.opacity(showsSolid ? 1 : 0) }
            content
                .frame(width: sheetRect.width, height: sheetRect.height, alignment: .topLeading)
                .offset(x: sheetRect.minX + shift.width, y: sheetRect.minY + shift.height)
                .opacity(isShown ? 1 : 0)
                .animation(SpotMotion.surface(isShown: isShown), value: isShown)
            if let arrow {
                arrow
                    .frame(width: arrowBox.width, height: arrowBox.height, alignment: .topTrailing)
                    .offset(x: rect.maxX - arrowBox.width, y: rect.minY)
            }
        }
        .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
        .modifier(SpotSelectionRing(isSelected: showsRing, shape: shape, motion: SpotMotion.sheetFade(isOpen: !showsRing, isLate: showsRing)))
        .scaleEffect(isShown ? 1 : SpotMotion.hiddenScale, anchor: UnitPoint(x: rect.midX / SpotTokens.panelWidth, y: rect.midY / SpotTokens.panelHeight))
        .animation(SpotMotion.surface(isShown: isShown), value: isShown)
    }
}
