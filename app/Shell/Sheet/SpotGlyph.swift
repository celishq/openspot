import OpenspotCore
import SwiftUI

struct SpotGlyph: View {
    let entry: SpotsModel.Entry
    var showsDisc = true
    @Environment(\.spotIsOnSolid) private var isOnSolid

    var body: some View {
        if entry.showsHeaderPicture {
            SpotItemIcon(icon: entry.spot.fileIcon, glyph: entry.spot.glyph, symbol: nil, size: SpotTokens.glyph)
        } else {
            Image(systemName: entry.symbol)
                .font(SpotType.glyph)
                .foregroundStyle(isOnSolid ? AnyShapeStyle(SpotTheme.glyphOnSolid) : AnyShapeStyle(SpotTheme.glassInk))
                .frame(width: SpotTokens.glyph, height: SpotTokens.glyph)
                .background(SpotTheme.ink.opacity(showsDisc ? SpotTheme.disc : 0), in: Circle())
        }
    }
}
