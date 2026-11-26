import OpenspotCore
import SwiftUI

struct UseChip: View {
    let use: SpotStanding.UseNeeds

    var body: some View {
        let tile = SettingsTile(use: use.id, access: use.needs.first, side: SpotTokens.settingsChipTile)
        HStack(spacing: SpotTokens.settingsChipGap) {
            tile
            Text(use.id.title)
                .lineLimit(1)
        }
        .padding(.leading, SpotTokens.settingsChipInset)
        .padding(.trailing, SpotTokens.settingsChipPadding)
        .padding(.vertical, SpotTokens.settingsChipInset)
        .background(tile.color.opacity(SpotTheme.settingsChipFill), in: SpotRoundShape(radius: SpotTokens.settingsChipTile * SpotTokens.settingsTileCorner + SpotTokens.settingsChipInset))
        .help([use.id.purpose, use.needsLine].compactMap { $0 }.joined(separator: " "))
    }
}
