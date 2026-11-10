import OpenspotCore
import SwiftUI

/// The round button on the top left corner of a card in Edit Spots: a minus that hides the card from the grid, or on a
/// hidden card a plus that shows it on the grid again.
struct SpotHideButton: View {
    let model: SpotsModel
    let id: String
    let isHidden: Bool
    let size: SpotSize

    var body: some View {
        let inset = SpotTokens.corner(for: size) * SpotTokens.rimPoint - SpotTokens.keycap / 2
        Button { model.setOnGrid(isHidden, for: id) } label: {
            Image(systemName: isHidden ? "plus" : "minus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(SpotTheme.ink)
                .frame(width: SpotTokens.keycap, height: SpotTokens.keycap)
                .background(SpotTheme.keycap, in: Circle())
                .overlay(Circle().strokeBorder(SpotTheme.ink.opacity(SpotTheme.track)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(isHidden ? "Show on Grid" : "Hide from Grid")
        .offset(x: inset, y: inset)
    }
}
