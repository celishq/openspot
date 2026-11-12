import OpenspotCore
import SwiftUI

/// The face of a spot in the store: its picture, its name and its description, at the size and in the shape of its card on
/// the grid. It shows no live content, so that the store opens with no work for each spot.
struct SpotStoreCard: View {
    let item: SpotDock.Item
    /// Whether the line under the name stays empty for the Add pill, in place of the description.
    var leavesRoomForAdd = false

    var body: some View {
        let size = item.size
        let icon = SpotItemIcon(icon: item.spot.icon, glyph: item.spot.glyph, symbol: item.spot.symbol, size: SpotTokens.glyphSize)
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
            Text(item.spot.name)
                .font(SpotType.title)
                .foregroundStyle(SpotTheme.ink)
                .frame(height: SpotTokens.nameHeight)
            if leavesRoomForAdd {
                Color.clear.frame(width: SpotTokens.addWidth, height: SpotTokens.addHeight)
            } else if let detail = item.spot.subtitle {
                Text(detail)
                    .font(SpotType.detail)
                    .modifier(SpotSecondaryText())
            }
        }
        .lineLimit(1)
    }
}
