import OpenspotCore
import SwiftUI

struct SpotGlyph: View {
    let entry: SpotsModel.Entry
    var showsDisc = true
    @Environment(\.spotIsOnSolid) private var isOnSolid

    var body: some View {
        if entry.showsHeaderPicture {
            SpotItemIcon(icon: entry.spot.icon, glyph: entry.spot.glyph, symbol: nil, size: SpotTokens.glyphSize)
        } else {
            Image(systemName: entry.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isOnSolid ? SpotTheme.glyphOnSolid : SpotTheme.ink)
                .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
                .background(SpotTheme.ink.opacity(showsDisc ? SpotTheme.disc : 0), in: Circle())
        }
    }
}
