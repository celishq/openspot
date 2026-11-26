import OpenspotCore
import SwiftUI

struct StoreTile: View {
    let store: Store
    let card: StoreCard

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.storeTilePadding) {
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(height: SpotTokens.storePreviewHeight)
            HStack(spacing: SpotTokens.wordsGap) {
                VStack(alignment: .leading, spacing: SpotType.lineGap) {
                    Text(card.spot.name)
                        .font(SpotType.title)
                        .lineLimit(1)
                    Text(card.spot.subtitle ?? "")
                        .font(SpotType.detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if card.mark == nil {
                    Button("Install") { Task { await store.install(card.id) } }
                } else {
                    Text("Installed")
                        .font(SpotType.detail)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(SpotTokens.storeTilePadding)
        .background(SpotTheme.ink.opacity(SpotTheme.hover), in: SpotRoundShape(radius: SpotTokens.storeTileRadius))
        .contentShape(Rectangle())
        .onTapGesture { Task { await store.open(card.id) } }
        .accessibilityAddTraits(.isButton)
        .draggable(card.id) { StoreTileLift(card: card) }
    }

    private var preview: some View {
        StoreCardPreview(spot: card.spot, face: card.preview.face, size: card.preview.size)
    }
}
