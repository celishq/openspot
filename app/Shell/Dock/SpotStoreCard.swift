import OpenspotCore
import SwiftUI

/// The face of a spot in the store: its picture, its name and its description, at the size and in the shape of its card on
/// the grid. It shows no live content, so that the store opens with no work for each spot.
struct SpotStoreCard: View {
    let item: SpotDock.Item

    var body: some View {
        let size = item.size
        let icon = SpotItemIcon(icon: item.command.icon, glyph: item.command.glyph, symbol: item.command.symbol, size: SpotTokens.glyphSize)
        Group {
            if size == .small {
                icon.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if size.rows > 1 {
                VStack(alignment: .leading, spacing: 0) {
                    icon
                    Spacer(minLength: 0)
                    words
                }
                .padding(SpotTokens.padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                HStack(spacing: SpotTokens.padding - 5) {
                    icon
                    words.frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, SpotTokens.padding)
                .frame(maxHeight: .infinity)
            }
        }
        .frame(width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows))
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(item.command.name)
                .font(SpotType.title)
                .foregroundStyle(SpotTheme.ink)
            if let detail = item.command.subtitle {
                Text(detail)
                    .font(SpotType.detail)
                    .modifier(SpotSecondaryText())
            }
        }
        .lineLimit(1)
    }
}
