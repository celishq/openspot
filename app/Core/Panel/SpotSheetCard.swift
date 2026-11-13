import Foundation

/// The card that an open sheet grows from, on the grid: the sheet's own card, or else a widget that opens it. Its size can
/// differ from the size it prefers.
public struct SpotSheetCard {
    public let id: String
    public let placement: SpotPlacement
    /// The card whose own look the sheet takes at the size of its card: a widget that opens it, or the sheet's own card when
    /// its script draws it. Nil for a card of the stock glyph and words.
    public let look: SpotsModel.Entry?
    /// How far the grid reaches left of the center panel.
    public var left: CGFloat = 0

    /// The card of a sheet among the model's visible cards, or nil when none shows it.
    @MainActor
    public static func of(_ sheetID: String?, in model: SpotsModel) -> SpotSheetCard? {
        guard let sheetID else { return nil }
        let visible = model.visible
        let index = visible.firstIndex { $0.id == sheetID }
            ?? visible.firstIndex { $0.kind == .widget && $0.spot.opens == sheetID }
        guard let index, let placement = model.placements.first(where: { $0.index == index }) else { return nil }
        let entry = visible[index]
        let face = entry.state.face
        let isDrawn = entry.item == nil && (face.layout(for: placement.size) != nil || face.hasView && entry.spot.view != nil)
        return SpotSheetCard(id: entry.id, placement: placement, look: entry.id != sheetID || isDrawn ? entry : nil, left: model.panels.leftExtent)
    }

    /// Where the card lies in the panel, with the grid scrolled this far.
    public func frame(scrollOffset: CGFloat) -> CGRect {
        let origin = SpotTokens.gridOrigin(scrollOffset: scrollOffset, left: left)
        return placement.rect.offsetBy(dx: origin.x, dy: origin.y)
    }
}
