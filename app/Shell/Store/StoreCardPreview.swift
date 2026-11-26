import OpenspotCore
import SwiftUI

struct StoreCardPreview: View {
    let spot: Spot
    let face: ViewTree
    let size: SpotSize
    var fits = true

    var body: some View {
        let frame = CGSize(width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows))
        let shape = SpotRoundShape(radius: SurfaceEdge(card: size).radius)
        let isDrawn = face.draws(on: size)
        content(isDrawn: isDrawn)
            .padding(SpotTokens.cardPadding(for: size, isDrawn: isDrawn))
            .frame(width: frame.width, height: frame.height)
            .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
            .spotGlass(in: shape)
            .environment(\.spotIsShown, true)
            .scaleEffect(fits ? min(1, SpotTokens.storePreviewWidth / frame.width, SpotTokens.storePreviewHeight / frame.height) : 1)
            .frame(height: fits ? SpotTokens.storePreviewHeight : frame.height)
            .allowsHitTesting(false)
            .task(id: spot.id) {
                for view in spot.views.values { await SpotViews.shared.load(view) }
            }
    }

    @ViewBuilder
    private func content(isDrawn: Bool) -> some View {
        if isDrawn {
            CardTreeView(face: face, size: size, spot: spot.id)
        } else if size == .small {
            glyph.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if size.rows > 1 {
            VStack(alignment: .leading, spacing: 0) {
                glyph
                Spacer(minLength: 0)
                words
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: SpotTokens.wordsGap) {
                glyph
                words.frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var glyph: some View {
        SpotGlyph(entry: SpotsModel.Entry(spot: spot, run: nil))
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            Text(spot.name)
                .font(SpotType.title)
                .lineLimit(1)
            if let subtitle = spot.subtitle {
                Text(subtitle)
                    .font(SpotType.detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
