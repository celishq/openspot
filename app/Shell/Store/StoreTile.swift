import OpenspotCore
import SwiftUI

struct StoreTile: View {
    let store: Store
    let card: StoreCard
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.storeTilePadding) {
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(height: SpotTokens.storePreviewHeight)
            HStack(spacing: SpotTokens.wordsGap) {
                SettingsSpotIcon(spot: card.spot, side: SpotTokens.settingsRowTile)
                VStack(alignment: .leading, spacing: SpotType.lineGap) {
                    Text(card.spot.name)
                        .font(SpotType.title)
                        .lineLimit(1)
                    Text(card.spot.subtitle ?? "")
                        .font(SpotType.detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(2, reservesSpace: true)
                }
                Spacer(minLength: 0)
                Group {
                    if card.mark == nil {
                        Button("Install") { Task { await store.install(card.id) } }
                    } else {
                        Label("Installed", systemImage: "checkmark")
                            .font(SpotType.detail)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: SpotTokens.storeActionWidth, alignment: .trailing)
            }
        }
        .padding(SpotTokens.storeTilePadding)
        .background(SpotTheme.ink.opacity(isHovered ? SpotTheme.fill : SpotTheme.hover), in: SpotRoundShape(radius: SpotTokens.storeTileRadius))
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture { Task { await store.open(card.id) } }
        .accessibilityAddTraits(.isButton)
        .draggable(card.id) { StoreTileLift(card: card) }
    }

    @ViewBuilder
    private var preview: some View {
        if card.preview.drawsCard {
            StoreCardPreview(spot: card.spot, face: card.preview.face, size: card.preview.size)
        } else {
            SettingsSpotIcon(spot: card.spot, side: SpotTokens.storePreviewIcon)
        }
    }
}
