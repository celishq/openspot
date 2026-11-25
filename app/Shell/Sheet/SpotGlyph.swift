import OpenspotCore
import SwiftUI

struct SpotGlyph: View {
    let entry: SpotsModel.Entry
    var showsDisc = true
    var side = SpotTokens.glyph
    var font = SpotType.glyph
    @Environment(\.spotIsOnSolid) private var isOnSolid

    var body: some View {
        if entry.showsHeaderPicture {
            SpotItemIcon(icon: entry.spot.fileIcon, glyph: entry.spot.glyph, symbol: nil, size: side)
        } else {
            SpotWorkingSymbol(entry: entry)
                .font(font)
                .foregroundStyle(isOnSolid ? AnyShapeStyle(SpotTheme.glyphOnSolid) : AnyShapeStyle(SpotTheme.glassInk))
                .frame(width: side, height: side)
                .background(SpotTheme.ink.opacity(showsDisc ? SpotTheme.disc : 0), in: Circle())
        }
    }
}
