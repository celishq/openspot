import OpenspotCore
import SwiftUI

struct SpotGridShade: View {
    let model: SpotsModel

    var body: some View {
        let shade = model.gridShade
        ZStack(alignment: .topLeading) {
            ForEach(shade.cards) { card in
                SpotRoundShape(card.edge)
                    .fill(SpotTheme.dim)
                    .frame(width: card.rect.width, height: card.rect.height)
                    .offset(x: card.rect.minX, y: card.rect.minY)
            }
        }
        .compositingGroup()
        .opacity(shade.isOn ? 1 : MotionTokens.hiddenOpacity)
        .allowsHitTesting(false)
    }
}
