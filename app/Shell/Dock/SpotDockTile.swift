import OpenspotCore
import SwiftUI

/// A spot in the store: its store card, at its size, on the fill of a row. A spot that is not on the grid shows an Add pill,
/// or a plus on the rim of a 1x1 card, and a spot of the plugins folder that is off shows a cross that deletes it. The
/// store's rows take the pointer for every tile, so that a tile draws and tracks nothing of its own.
struct SpotDockTile: View {
    let item: SpotDock.Item

    var body: some View {
        let size = item.size
        let shape = RoundedRectangle(cornerRadius: SpotTokens.corner(for: size), style: .continuous)
        let bounds = CGRect(x: 0, y: 0, width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows))
        let add = SpotDock.addRect(in: bounds, size: size)
        SpotStoreCard(item: item, leavesRoomForAdd: item.state != .onGrid && size != .small)
            .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
            .overlay(alignment: .topLeading) {
                if item.state != .onGrid {
                    AddMark(isRound: size == .small)
                        .frame(width: add.width, height: add.height)
                        .offset(x: add.minX, y: add.minY)
                }
            }
            .overlay(alignment: .topTrailing) {
                if item.isOwn, item.state == .off {
                    let inset = SpotTokens.corner(for: size) * SpotTokens.rimPoint - SpotTokens.keycap / 2
                    RoundMark(symbol: "xmark").offset(x: -inset, y: inset)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.spot.name)
    }
}

/// The Add of a store card: a pill with its word, or a round plus on a 1x1 card.
private struct AddMark: View {
    let isRound: Bool

    var body: some View {
        if isRound {
            RoundMark(symbol: "plus")
        } else {
            Text("Add")
                .font(SpotType.action)
                .foregroundStyle(SpotTheme.onSolid)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SpotTheme.ink, in: Capsule())
        }
    }
}

/// A round mark drawn as a corner button is, for a control that the store's rows take.
private struct RoundMark: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(SpotTheme.ink)
            .frame(width: SpotTokens.keycap, height: SpotTokens.keycap)
            .background(SpotTheme.keycap, in: Circle())
            .overlay(Circle().strokeBorder(SpotTheme.ink.opacity(SpotTheme.track)))
    }
}
