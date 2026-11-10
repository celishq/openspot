import OpenspotCore
import SwiftUI

/// A spot in the dock: its card as the grid draws it, 1x1 or wide, on the fill of a row, and the name under a 1x1 card,
/// which shows no words.
struct SpotDockTile: View {
    let entry: SpotsModel.Entry
    let model: SpotsModel

    var body: some View {
        let size: SpotSize = entry.size == .small ? .small : .wide
        let shape = RoundedRectangle(cornerRadius: SpotTokens.corner(for: size), style: .continuous)
        VStack(spacing: 4) {
            SpotCardView(
                entry: entry,
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
            if size == .small {
                Text(entry.command.name)
                    .font(SpotType.detail)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                    .frame(width: SpotTokens.cell + SpotTokens.columnGap)
            }
        }
    }
}
