import OpenspotCore
import SwiftUI

/// A spot in the dock: a circle for a 1x1 spot, with its name under it, or a capsule that holds its name for any other.
struct SpotDockTile: View {
    let entry: SpotsModel.Entry

    var body: some View {
        let isSmall = entry.size == .small
        VStack(spacing: 5) {
            card(isSmall: isSmall)
                .frame(width: isSmall ? SpotTokens.cell : SpotTokens.width(columns: 2), height: SpotTokens.rowHeight)
                .background(SpotTheme.ink.opacity(SpotTheme.fill), in: Capsule())
            if isSmall {
                Text(entry.command.name)
                    .font(SpotType.detail)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                    .frame(width: SpotTokens.cell + SpotTokens.columnGap)
            }
        }
    }

    @ViewBuilder
    private func card(isSmall: Bool) -> some View {
        if isSmall {
            SpotGlyph(entry: entry, showsDisc: false)
        } else {
            HStack(spacing: 8) {
                SpotGlyph(entry: entry, showsDisc: false)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.command.name)
                        .font(SpotType.title)
                        .lineLimit(1)
                    if let subtitle = entry.command.subtitle {
                        Text(subtitle)
                            .font(SpotType.detail)
                            .opacity(SpotTheme.secondaryLight)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(SpotTheme.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
        }
    }
}
