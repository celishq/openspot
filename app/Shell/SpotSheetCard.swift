import OpenspotCore
import SwiftUI

/// The card that an open sheet grows from, on the grid: the sheet's own card, or else a widget that opens it. Its size can
/// differ from the size it prefers.
struct SpotSheetCard {
    let id: String
    let placement: SpotPlacement
    /// The widget that opens the sheet, whose look the sheet takes at the size of its card. Nil for the sheet's own card.
    let widget: SpotsModel.Entry?

    /// The card of a sheet among the model's visible cards, or nil when none shows it.
    @MainActor
    static func of(_ sheetID: String?, in model: SpotsModel) -> SpotSheetCard? {
        guard let sheetID else { return nil }
        let visible = model.visible
        let index = visible.firstIndex { $0.id == sheetID }
            ?? visible.firstIndex { $0.kind == .widget && $0.command.opens == sheetID }
        guard let index, let placement = model.placements.first(where: { $0.index == index }) else { return nil }
        let entry = visible[index]
        return SpotSheetCard(id: entry.id, placement: placement, widget: entry.id == sheetID ? nil : entry)
    }

    /// Where the card lies in the panel, with the grid scrolled this far.
    func frame(scrollOffset: CGFloat) -> CGRect {
        CGRect(
            x: SpotTokens.halo + CGFloat(placement.column) * (SpotTokens.cell + SpotTokens.columnGap),
            y: SpotsView.gridTop + CGFloat(placement.row) * (SpotTokens.rowHeight + SpotTokens.rowGap) - scrollOffset,
            width: SpotTokens.width(columns: placement.size.columns),
            height: SpotTokens.height(rows: placement.size.rows)
        )
    }
}
