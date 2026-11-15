import OpenspotCore
import SwiftUI

struct SpotMenuLayer: View {
    let model: SpotsModel
    let item: SpotMenuAnchor.Item?
    let fieldIsInSheet: Bool
    @Environment(\.spotPanels) private var panels

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

    private var bounds: CGRect {
        ActionMenuFrame.bounds(under: fieldIsInSheet ? SpotTokens.halo + SpotTokens.sheetFieldDrop + SpotTokens.listRowHeight + SpotTokens.rowGap : SpotTokens.gridTop, in: panels.frame)
    }

    private static func rect(_ rect: CGRect, scaledBy scale: CGFloat, from corner: UnitPoint) -> CGRect {
        let size = CGSize(width: rect.width * scale, height: rect.height * scale)
        return CGRect(x: rect.minX + (rect.width - size.width) * corner.x, y: rect.minY + (rect.height - size.height) * corner.y, width: size.width, height: size.height)
    }
}
