import OpenspotCore
import SwiftUI

/// A spot in the dock: its card as the grid draws it, 1x1 or wide, on the fill of a row, and the name under a 1x1 card,
/// which shows no words. Its frame is the card's. A spot of the plugins folder shows a cross that deletes it. A right click
/// turns the spot on.
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
        .frame(width: SpotTokens.width(columns: size.columns), height: SpotTokens.rowHeight)
        .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
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
