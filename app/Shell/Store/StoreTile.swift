import OpenspotCore
import SwiftUI

struct StoreTile: View {
    let store: Store
    let card: StoreCard

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.storeTilePadding) {
            preview
                .frame(maxWidth: .infinity)
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
        .task(id: card.id) {
            for view in card.spot.views.values { await SpotViews.shared.load(view) }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let preview = card.preview {
            let size = CGSize(width: SpotTokens.width(columns: preview.size.columns), height: SpotTokens.height(rows: preview.size.rows))
            let shape = SpotRoundShape(radius: SurfaceEdge(card: preview.size).radius)
            CardTreeView(face: preview.face, size: preview.size, spot: card.id)
                .padding(SpotTokens.cardPadding(for: preview.size, isDrawn: true))
                .frame(width: size.width, height: size.height)
                .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
                .spotGlass(in: shape)
                .environment(\.spotIsShown, true)
                .scaleEffect(min(1, SpotTokens.storePreviewWidth / size.width, SpotTokens.storePreviewHeight / size.height))
                .allowsHitTesting(false)
        } else {
            SettingsSpotIcon(spot: card.spot, side: SpotTokens.storePreviewIcon)
        }
    }
}
