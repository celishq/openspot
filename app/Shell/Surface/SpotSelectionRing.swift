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
        content.overlay(
            shape.strokeBorder(SpotTheme.accent, lineWidth: width)
                .morph(progress ?? 0, opacity: { [isSelected, hasSheet = progress != nil] in
                    isSelected ? (hasSheet ? SheetMorph.cardLook(at: $0) : 1) : 0
                })
                .allowsHitTesting(false)
        )
        .transformAnchorPreference(key: SpotMenuAnchor.self, value: .bounds) { item, bounds in
            if isSelected, marksMenu { item = SpotMenuAnchor.Item(bounds: bounds, corner: (shape as? RoundedRectangle)?.cornerSize.width ?? 0) }
        }
    }
}
