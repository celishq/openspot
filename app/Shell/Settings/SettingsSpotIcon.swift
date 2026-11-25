import OpenspotCore
import SwiftUI

struct SettingsSpotIcon: View {
    let spot: Spot
    let side: CGFloat

    var body: some View {
        if let icon = spot.fileIcon {
            SpotItemIcon(icon: icon, glyph: nil, symbol: nil, size: side)
                .frame(width: side, height: side)
        } else if let glyph = spot.glyph {
            SpotRoundShape(radius: side * SpotTokens.settingsTileCorner)
                .fill(SpotTheme.settingsSpot(spot.id).gradient)
                .frame(width: side, height: side)
                .overlay(Text(glyph).font(SpotType.settingsGlyph(side: side)))
        } else {
            SettingsTile(symbol: spot.symbol, color: SpotTheme.settingsSpot(spot.id), side: side)
        }
    }
}
