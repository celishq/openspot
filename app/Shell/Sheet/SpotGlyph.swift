import OpenspotCore
import SwiftUI

/// The picture at the head of a spot's sheet: its running work, the picture that its header names, or its symbol on a disc.
struct SpotGlyph: View {
    let entry: SpotsModel.Entry
    /// Whether it lies on the solid fill of a card that is on.
    var isOnSolid = false
    /// Whether its symbol lies on a disc.
    var showsDisc = true

    var body: some View {
        if let call = entry.work {
            SpotWorkMark(call: call, isOnSolid: isOnSolid)
        } else if entry.showsHeaderPicture {
            SpotItemIcon(icon: entry.command.icon, glyph: entry.command.glyph, symbol: nil, size: SpotTokens.glyphSize)
        } else {
            Image(systemName: entry.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isOnSolid ? SpotTheme.glyphOnSolid : SpotTheme.ink)
                .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
                .background(SpotTheme.ink.opacity(showsDisc ? SpotTheme.disc : 0), in: Circle())
        }
    }
}
