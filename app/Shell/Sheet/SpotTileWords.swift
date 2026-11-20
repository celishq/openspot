import OpenspotCore
import SwiftUI

struct SpotTileWords: View, Equatable {
    let item: SpotItem
    let side: CGFloat

    var body: some View {
        let circle = side * SpotTokens.wordsTileCircleShare
        VStack(spacing: SpotTokens.wordsTileGap) {
            SpotItemIcon(item: item, size: circle * SpotTokens.wordsTileIconShare)
                .frame(width: circle, height: circle)
                .background(SpotTheme.ink.opacity(SpotTheme.fill), in: Circle())
            Text(item.title)
                .font(SpotType.title)
                .foregroundStyle(SpotTheme.ink)
                .lineLimit(1)
            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(SpotType.detail)
                    .modifier(SpotSecondaryText())
                    .lineLimit(1)
            }
        }
    }
}
