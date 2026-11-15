import OpenspotCore
import SwiftUI

struct SpotGridShade: View {
    let model: SpotsModel
    @Environment(\.spotScrollFade) private var edge

    var body: some View {
        let shade = model.gridShade
        let edge = edge
        let space = SpotsView.panelSpace
        ZStack(alignment: .topLeading) {
            ForEach(shade.cards) { card in
                SpotRoundShape(card.edge)
                    .fill(SpotTheme.dim)
                    .frame(width: card.rect.width, height: card.rect.height)
                    .visualEffect { content, place in content.opacity(SpotTheme.glassStrength(at: edge?.strength(of: place.frame(in: .named(space))) ?? 1)) }
                    .offset(x: card.rect.minX, y: card.rect.minY)
            }
        }
        .compositingGroup()
        .opacity(shade.isOn ? 1 : MotionTokens.hiddenOpacity)
        .allowsHitTesting(false)
    }
}
