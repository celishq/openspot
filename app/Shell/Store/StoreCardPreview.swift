import OpenspotCore
import SwiftUI

struct StoreCardPreview: View {
    let spot: Spot
    let preview: StorePreview

    var body: some View {
        let size = CGSize(width: SpotTokens.width(columns: preview.size.columns), height: SpotTokens.height(rows: preview.size.rows))
        let shape = SpotRoundShape(radius: SurfaceEdge(card: preview.size).radius)
        CardTreeView(face: preview.face, size: preview.size, spot: spot.id)
            .padding(SpotTokens.cardPadding(for: preview.size, isDrawn: true))
            .frame(width: size.width, height: size.height)
            .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
            .spotGlass(in: shape)
            .environment(\.spotIsShown, true)
            .scaleEffect(min(1, SpotTokens.storePreviewWidth / size.width, SpotTokens.storePreviewHeight / size.height))
            .frame(height: SpotTokens.storePreviewHeight)
            .allowsHitTesting(false)
            .task(id: spot.id) {
                for view in spot.views.values { await SpotViews.shared.load(view) }
            }
    }
}
