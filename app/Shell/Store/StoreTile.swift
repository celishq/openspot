import OpenspotCore
import SwiftUI

struct StoreTile: View {
    let store: Store
    let card: StoreCard
    let drag: StoreDrag
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.storeTilePadding) {
            preview
                .opacity(drag.carry?.id == card.id ? MotionTokens.hiddenOpacity : 1)
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
                        .lineLimit(2)
                        .frame(height: 2 * SpotType.detailLine, alignment: .topLeading)
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
        .background(SpotTheme.ink.opacity(isHovered ? SpotTheme.fill : SpotTheme.hover), in: SpotRoundShape(radius: SpotTokens.pageTileRadius))
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture { Task { await store.open(card.id) } }
        .accessibilityAddTraits(.isButton)
        .gesture(DragGesture(coordinateSpace: .named(StoreDrag.space))
            .onChanged { drag.move(card, to: $0.location) }
            .onEnded { _ in drag.drop(store) })
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
