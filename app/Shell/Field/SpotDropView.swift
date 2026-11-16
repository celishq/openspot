import OpenspotCore
import SwiftUI

struct SpotDropView: View {
    let drop: SpotDrop

    var body: some View {
        HStack(spacing: SpotTokens.wordsGap) {
            Image(systemName: drop.symbol)
                .font(SpotType.glyph)
                .foregroundStyle(SpotTheme.ink)
                .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
                .background(SpotTheme.ink.opacity(SpotTheme.disc), in: Circle())
            VStack(alignment: .leading, spacing: SpotType.lineGap) {
                Text(drop.title)
                    .font(SpotType.title)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                if let detail = drop.detail {
                    Text(detail)
                        .font(SpotType.detail)
                        .modifier(SpotSecondaryText())
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
