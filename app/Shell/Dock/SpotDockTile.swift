import OpenspotCore
import SwiftUI

/// A spot in the store: its store card, at its size, on the fill of a row, with a mark of its state on its top left
/// corner: a plus for a spot that is off, a check for one on the grid, or a slashed eye for one in search only. A spot of
/// the plugins folder that is off shows a cross that deletes it, and a spot that is off resizes by its corner. The store's
/// rows take the pointer for every tile, so that a tile draws and tracks nothing of its own.
struct SpotDockTile: View {
    let item: SpotDock.Item
    let model: SpotsModel

    var body: some View {
        let size = item.size
        let shape = RoundedRectangle(cornerRadius: SpotTokens.corner(for: size), style: .continuous)
        let card = SpotStoreCard(item: item)
            .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
            .overlay(alignment: .topLeading) { CornerMark(symbol: Self.mark(of: item).symbol, corner: .leading, size: size) }
            .overlay(alignment: .topTrailing) {
                if item.isOwn, item.state == .off { CornerMark(symbol: "xmark", corner: .trailing, size: size) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.command.name)
            .accessibilityValue(Self.mark(of: item).label)
            .accessibilityAction { model.openListing(item.id) }
        if item.state == .off {
            card.modifier(SpotEditControls(
                model: model,
                id: item.id,
                size: size,
                turnsOff: false,
                showsEye: false,
                isHidden: false,
                sizes: model.carry == nil ? model.sizes(of: SpotsModel.Entry(command: item.command, run: nil)) : [],
                isResizing: model.dockResize?.id == item.id,
                isDragging: model.carry != nil
            ))
        } else {
            card
        }
    }

    /// The symbol and the words of the mark of a spot's state.
    static func mark(of item: SpotDock.Item) -> (symbol: String, label: String) {
        switch item.state {
        case .off: ("plus", "Turn on")
        case .onGrid: ("checkmark", "On grid")
        case .searchOnly: ("eye.slash", "Search only")
        }
    }
}

/// A round mark on a top corner of a card, drawn as a corner button is, for a control that the store's rows take.
private struct CornerMark: View {
    let symbol: String
    let corner: SpotCornerButton.Corner
    let size: SpotSize

    var body: some View {
        let inset = SpotTokens.corner(for: size) * SpotTokens.rimPoint - SpotTokens.keycap / 2
        Image(systemName: symbol)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(SpotTheme.ink)
            .frame(width: SpotTokens.keycap, height: SpotTokens.keycap)
            .background(SpotTheme.keycap, in: Circle())
            .overlay(Circle().strokeBorder(SpotTheme.ink.opacity(SpotTheme.track)))
            .offset(x: corner == .leading ? inset : -inset, y: inset)
    }
}
