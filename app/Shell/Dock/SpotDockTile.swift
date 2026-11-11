import OpenspotCore
import SwiftUI

/// A spot in the dock: its card as the grid draws it, at its size, on the fill of a row, and the name under a 1x1 card,
/// which shows no words. Its frame is the card's, drawn in a layer of its own, so that a move of the dock's tiles redraws
/// none. A spot of the plugins folder shows a cross that deletes it, and its corner handle resizes it as on the grid. A
/// right click turns the spot on.
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
            sizes: model.carry == nil ? model.sizes(of: SpotsModel.Entry(command: item.command, run: nil)) : [],
            isResizing: model.dockResize?.id == item.id,
            isDragging: model.carry != nil
        ))
        .overlay(alignment: .topLeading) {
            if item.isOwn {
                SpotCornerButton(symbol: "xmark", label: "Delete", corner: .leading, size: size) { model.delete(item.id) }
            }
        }
        .contextMenu {
            Button("Turn On") { model.turnOn(item.id) }
            if item.isOwn { Button("Delete") { model.delete(item.id) } }
        }
        .overlay(alignment: .top) {
            if size == .small {
                Text(item.command.name)
                    .font(SpotType.detail)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                    .frame(width: SpotTokens.cell + SpotTokens.columnGap, height: SpotTokens.dockNameHeight)
                    .offset(y: SpotTokens.rowHeight + SpotTokens.dockNameGap)
                    .allowsHitTesting(false)
            }
        }
    }
}
