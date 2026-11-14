import OpenspotCore
import SwiftUI

struct SpotTipView: View {
    static let delay: Duration = .milliseconds(500)
    private static let gap: CGFloat = 4

    let model: SpotsModel
    let panelOrigin: CGPoint
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
                    .position(x: panelOrigin.x + top.x, y: panelOrigin.y + top.y + Self.gap + SpotTokens.hintPillHeight / 2)
                    .opacity(isShown ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .task(id: model.tip) {
            isShown = false
            guard model.tip != nil else { return }
            try? await Task.sleep(for: Self.delay)
            if !Task.isCancelled { withAnimation(SpotMotion.fade(isShown: true)) { isShown = true } }
        }
    }

    private func top(of tip: SpotTip) -> CGPoint? {
        guard let index = model.visible.firstIndex(where: { $0.id == tip.id }),
              let placement = model.placements.first(where: { $0.index == index }) else { return nil }
        let rect = placement.rect
        let inset = SpotTokens.corner(for: placement.size) * SpotTokens.rimPoint
        let origin = model.gridOrigin
        let x = tip.anchor == .trailingCorner ? rect.maxX - inset : rect.minX + inset
        return CGPoint(x: origin.x + x, y: origin.y + rect.minY + inset + SpotTokens.keycap / 2)
    }
}
