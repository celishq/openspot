import OpenspotCore
import SwiftUI

/// A spot in the store: its card as the grid draws it, at its size, on the fill of a row, with a mark of its state on its
/// top left corner: a plus that turns it on, a check that selects its card on the grid, or a slashed eye for search only.
/// The pointer over a card shows its description as a tip, with its name on a 1x1 card. A click opens its listing. A spot of the plugins folder that is off shows a cross that deletes it, and its
/// corner handle resizes it as on the grid.
struct SpotDockTile: View {
    let item: SpotDock.Item
    let model: SpotsModel

    var body: some View {
        let size = item.size
        let shape = RoundedRectangle(cornerRadius: SpotTokens.corner(for: size), style: .continuous)
        SpotCardView(
            entry: SpotsModel.Entry(command: item.command, run: nil),
            size: size,
            index: -1,
            isPressed: false,
            takesDrag: false,
            isDropTarget: false,
            chainLetter: nil,
            showsChain: false,
            isHiddenFromGrid: false,
            model: model,
            onTap: {}
        )
        .frame(width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows))
        .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
        .drawingGroup()
        .modifier(SpotEditControls(
            model: model,
            id: item.id,
            size: size,
            turnsOff: false,
            showsEye: false,
            isHidden: false,
            sizes: model.carry == nil && item.state == .off ? model.sizes(of: SpotsModel.Entry(command: item.command, run: nil)) : [],
            isResizing: model.dockResize?.id == item.id,
            isDragging: model.carry != nil
        ))
        .overlay(alignment: .topLeading) {
            SpotCornerButton(symbol: mark.symbol, label: mark.label, corner: .leading, size: size, onHover: tip(.dockCorner, text: mark.label)) {
                item.state == .off ? model.turnOn(item.id) : model.dragDockSpot(item.id, by: .zero)
            }
        }
        .overlay(alignment: .topTrailing) {
            if item.isOwn, item.state == .off {
                SpotCornerButton(symbol: "xmark", label: "Delete", corner: .trailing, size: size, onHover: tip(.dockCard, text: "Delete")) { model.delete(item.id) }
            }
        }
        .onTapGesture { model.openListing(item.id) }
        .contextMenu {
            if item.state == .off { Button("Turn On") { model.turnOn(item.id) } }
            if item.isOwn, item.state == .off { Button("Delete") { model.delete(item.id) } }
        }
        .onHover { isOver in
            let words = size == .small ? [item.command.name, item.command.subtitle].compactMap { $0 } : [item.command.subtitle].compactMap { $0 }
            guard !words.isEmpty else { return }
            let tip = SpotTip(id: item.id, anchor: .dockCard, text: words.joined(separator: " · "))
            if isOver {
                model.tip = tip
            } else if model.tip == tip {
                model.tip = nil
            }
        }
    }

    /// The symbol and the words of the mark of the spot's state.
    private var mark: (symbol: String, label: String) {
        switch item.state {
        case .off: ("plus", "Turn on")
        case .onGrid: ("checkmark", "On grid")
        case .searchOnly: ("eye.slash", "Search only")
        }
    }

    /// Shows a tip at this anchor while the pointer lies over the control.
    private func tip(_ anchor: SpotTip.Anchor, text: String) -> (Bool) -> Void {
        let tip = SpotTip(id: item.id, anchor: anchor, text: text)
        return { isOver in
            if isOver {
                model.tip = tip
            } else if model.tip == tip {
                model.tip = nil
            }
        }
    }
}
