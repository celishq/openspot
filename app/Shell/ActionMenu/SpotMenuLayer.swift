import OpenspotCore
import SwiftUI

/// The open actions menu at the selected card or row, or the closing one at its last place. With no selected item it opens
/// under the field. It alone reads the menu, so that a key in the menu reruns this view and not the panel.
struct SpotMenuLayer: View {
    let model: SpotsModel
    let item: SpotMenuAnchor.Item?
    /// Whether the search field lies in the open sheet, which moves the top of the menu's room down to under it.
    let fieldIsInSheet: Bool
    @Environment(\.spotPanelWidth) private var panelWidth

    var body: some View {
        GeometryReader { proxy in
            if let session = model.menuSession {
                let menu = session.menu
                let rect = item.map { proxy[$0.bounds] } ?? SpotFieldView.rect
                let isClosing = session.phase == .closing
                let fresh = ActionMenuFrame(item: rect, menu: menu, bounds: bounds)
                let resting = ActionMenuFrame(item: model.menuItemAtRest(rect), menu: menu, bounds: bounds)
                let frame = isClosing ? model.menuFrame ?? fresh : fresh
                let shown = frame.rect(of: menu)
                let isGrown = session.isGrown
                let scale = isGrown ? 1 : MotionTokens.menuStartScale
                let corner = UnitPoint(x: frame.side == .left ? 0 : 1, y: frame.stillEdge == .top ? 0 : 1)
                ZStack(alignment: .topLeading) {
                    SpotSurface(rect: Self.rect(shown, scaledBy: scale, from: corner), radius: SpotActionMenuView.radius * scale, glass: isGrown ? 1 : 0)
                    SpotActionMenuView(menu: menu, frame: frame, isSettled: session.phase == .settled, work: { model.work(of: $0) }, onPress: { model.pressMenu(row: $0) }, onPoint: { model.point(at: .menuRow($0)) }, onSearch: { model.searchMenu($0) }, selection: { model.menuSession?.menu.selected ?? 0 })
                        .equatable()
                        .scaleEffect(scale, anchor: corner)
                        .opacity(isGrown ? 1 : 0)
                        .offset(x: shown.minX, y: shown.minY)
                }
                .allowsHitTesting(!isClosing)
                .transition(.opacity)
                .onChange(of: resting, initial: true) { model.placeMenu(resting) }
            }
        }
    }

    /// Where the menu may lie: under the field, down to the panel's foot.
    private var bounds: CGRect {
        ActionMenuFrame.bounds(under: fieldIsInSheet ? SpotTokens.halo + SpotTokens.sheetFieldDrop + SpotTokens.listRowHeight + SpotTokens.rowGap : SpotTokens.gridTop, panelWidth: panelWidth)
    }

    /// The rect of the menu's glass at a scale from its corner nearest its item, as its rows scale, so that the blur behind
    /// it stays still.
    private static func rect(_ rect: CGRect, scaledBy scale: CGFloat, from corner: UnitPoint) -> CGRect {
        let size = CGSize(width: rect.width * scale, height: rect.height * scale)
        return CGRect(x: rect.minX + (rect.width - size.width) * corner.x, y: rect.minY + (rect.height - size.height) * corner.y, width: size.width, height: size.height)
    }
}
