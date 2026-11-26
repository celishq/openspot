import OpenspotCore
import SwiftUI

struct StoreTileLift: View {
    let card: StoreCard

    var body: some View {
        HStack(spacing: SpotTokens.wordsGap) {
            SpotGlyph(entry: SpotsModel.Entry(spot: card.spot, run: nil))
            Text(card.spot.name)
                .font(SpotType.strong)
        }
        .padding(SpotTokens.storeTilePadding)
        .background(SpotTheme.window, in: SpotRoundShape(radius: SpotTokens.storeTileRadius))
    }
}
