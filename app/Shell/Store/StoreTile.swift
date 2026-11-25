import OpenspotCore
import SwiftUI

struct StoreTile: View {
    let card: StoreCard
    let isFromSource: Bool

    var body: some View {
        let tile = VStack(alignment: .leading, spacing: SpotTokens.storeTileLineGap) {
            HStack(alignment: .top) {
                SpotGlyph(entry: SpotsModel.Entry(spot: card.spot, run: nil))
                Spacer(minLength: 0)
                if let mark = card.mark { StoreMarkView(mark: mark) }
            }
            Spacer(minLength: 0)
            Text(card.spot.name)
                .font(SpotType.strong)
                .lineLimit(1)
            Text(card.spot.subtitle ?? " ")
                .font(SpotType.detail)
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
                .lineLimit(1)
        }
        .padding(SpotTokens.storeTilePadding)
        .frame(height: SpotTokens.storeTileSize.height)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SpotTheme.ink.opacity(SpotTheme.hover), in: SpotRoundShape(radius: SpotTokens.storeTileRadius))
        .contentShape(SpotRoundShape(radius: SpotTokens.storeTileRadius))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        if isFromSource {
            tile.draggable(card.id) { StoreTileLift(card: card) }
        } else {
            tile
        }
    }
}
