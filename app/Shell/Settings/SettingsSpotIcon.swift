import OpenspotCore
import SwiftUI

struct SettingsSpotIcon: View {
    let spot: Spot
    let side: CGFloat

    var body: some View {
        ZStack {
            if let icon = spot.fileIcon {
                SpotItemIcon(icon: icon, glyph: nil, symbol: nil, size: side)
            } else {
                SpotRoundShape(radius: side * SpotTokens.settingsTileCorner)
                    .fill(Color.primary.opacity(SpotTheme.settingsIconFill))
                if let glyph = spot.glyph {
                    Text(glyph).font(SpotType.settingsGlyph(side: side))
                } else {
                    Image(systemName: spot.symbol).font(SpotType.settingsSymbol(side: side))
                }
            }
        }
        .frame(width: side, height: side)
    }
}
