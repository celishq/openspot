import OpenspotCore
import SwiftUI

/// The accent ring inside the edge of the selected card, row, cell or item: the one mark of what Enter acts on. It moves
/// at once between items. On a sheet that grows out of its card, it fades as the card's look does.
struct SpotSelectionRing<Edge: InsettableShape>: ViewModifier {
    static var width: CGFloat { 2 }
    static var thinWidth: CGFloat { 1.5 }

    let isSelected: Bool
    let shape: Edge
    var width = Self.width
    /// How far a sheet that grows out of this card is open, from 0 to 1, or nil for an item with no sheet.
    var progress: Double?
    /// Whether the actions menu opens at this item while it is selected.
    var marksMenu = false

    func body(content: Content) -> some View {
        content.overlay(ring.allowsHitTesting(false))
        .transformAnchorPreference(key: SpotMenuAnchor.self, value: .bounds) { item, bounds in
            if isSelected, marksMenu { item = SpotMenuAnchor.Item(bounds: bounds, corner: (shape as? RoundedRectangle)?.cornerSize.width ?? 0) }
        }
    }

    /// The ring, which takes its fade from the sheet's motion only while a sheet grows out of this item.
    @ViewBuilder
    private var ring: some View {
        let stroke = shape.strokeBorder(SpotTheme.accent, lineWidth: width)
        if let progress {
            stroke.morph(progress, opacity: { [isSelected] in isSelected ? SheetMorph.cardLook(at: $0) : 0 })
        } else {
            stroke.opacity(isSelected ? 1 : MotionTokens.hiddenOpacity)
        }
    }
}
