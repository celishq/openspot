import OpenspotCore
import SwiftUI

/// The tip that the pointer rests on in Edit Spots, centred under its control or its dock card, over the panel and the dock.
/// It shows after the pointer rests for `delay`, and goes at once. Its place comes from the layout of the grid and the dock.
struct SpotTipView: View {
    static let delay: Duration = .milliseconds(500)
    private static let gap: CGFloat = 4

    let model: SpotsModel
    /// Where the panel lies in the window.
    let panel: CGPoint
    @State private var isShown = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let tip = model.tip, model.isEditing, model.carry == nil, model.resize == nil, let top = top(of: tip) {
                Text(tip.text)
                    .font(SpotType.detail)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, SpotTokens.hintKeyPadding)
                    .frame(height: SpotTokens.hintPillHeight)
                    .background(SpotTheme.keycap, in: Capsule())
                    .overlay(Capsule().strokeBorder(SpotTheme.ink.opacity(SpotTheme.track)))
                    .position(x: panel.x + top.x, y: panel.y + top.y + Self.gap + SpotTokens.hintPillHeight / 2)
                    .opacity(isShown ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .task(id: model.tip) {
            isShown = false
            guard model.tip != nil else { return }
            try? await Task.sleep(for: Self.delay)
            if !Task.isCancelled { withAnimation(SpotMotion.handleFade) { isShown = true } }
        }
    }

    /// The middle of the tip's top edge in the panel: under the control on the rim of a card's top corner, on the grid or in
    /// the dock, or under the card of the dock.
    private func top(of tip: SpotTip) -> CGPoint? {
        if tip.anchor == .dockCard || tip.anchor == .dockCorner {
            guard let dock = model.dockFrame, let index = model.dock.shown.firstIndex(where: { $0.id == tip.id }) else { return nil }
            let rect = model.dock.rects(columns: SpotTokens.dockColumns(width: dock.width))[index]
                .offsetBy(dx: dock.minX + SpotTokens.padding, dy: dock.minY + SpotTokens.dockRowsTop - model.dockScroll)
            guard tip.anchor == .dockCorner else { return CGPoint(x: rect.midX, y: rect.maxY) }
            let inset = SpotTokens.corner(for: model.dock.shown[index].size) * SpotTokens.rimPoint
            return CGPoint(x: rect.minX + inset, y: rect.minY + inset + SpotTokens.keycap / 2)
        }
        guard let index = model.visible.firstIndex(where: { $0.id == tip.id }),
              let placement = model.placements.first(where: { $0.index == index }) else { return nil }
        let rect = placement.rect
        let inset = SpotTokens.corner(for: placement.size) * SpotTokens.rimPoint
        let origin = SpotTokens.gridOrigin(scrollOffset: model.gridScroll)
        let x = tip.anchor == .trailingCorner ? rect.maxX - inset : rect.minX + inset
        return CGPoint(x: origin.x + x, y: origin.y + rect.minY + inset + SpotTokens.keycap / 2)
    }
}
