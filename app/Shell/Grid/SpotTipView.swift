import OpenspotCore
import SwiftUI

/// The tip of the corner control that the pointer rests on in Edit Spots, centred under the control, over every card. It
/// shows after the pointer rests for `delay`, and goes at once. Its place comes from the card's place in the grid.
struct SpotTipView: View {
    static let delay: Duration = .milliseconds(500)
    private static let gap: CGFloat = 4

    let model: SpotsModel
    let scrollOffset: CGFloat
    @State private var isShown = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let tip = model.tip, model.isEditing, model.drag == nil, model.resize == nil, let centre = centre(of: tip) {
                Text(tip.text)
                    .font(SpotType.detail)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, SpotTokens.hintKeyPadding)
                    .frame(height: SpotTokens.hintPillHeight)
                    .background(SpotTheme.keycap, in: Capsule())
                    .overlay(Capsule().strokeBorder(SpotTheme.ink.opacity(SpotTheme.track)))
                    .position(x: centre.x, y: centre.y + SpotTokens.keycap / 2 + Self.gap + SpotTokens.hintPillHeight / 2)
                    .opacity(isShown ? 1 : 0)
            }
        }
        .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
        .allowsHitTesting(false)
        .task(id: model.tip) {
            isShown = false
            guard model.tip != nil else { return }
            try? await Task.sleep(for: Self.delay)
            if !Task.isCancelled { withAnimation(SpotMotion.handleFade) { isShown = true } }
        }
    }

    /// The centre of the tip's control in the panel: on the rim of the card's top corner.
    private func centre(of tip: SpotTip) -> CGPoint? {
        guard let index = model.visible.firstIndex(where: { $0.id == tip.id }),
              let placement = model.placements.first(where: { $0.index == index }) else { return nil }
        let rect = placement.rect
        let inset = SpotTokens.corner(for: placement.size) * SpotTokens.rimPoint
        let origin = SpotTokens.gridOrigin(scrollOffset: scrollOffset)
        return CGPoint(x: origin.x + (tip.isTrailing ? rect.maxX - inset : rect.minX + inset), y: origin.y + rect.minY + inset)
    }
}
