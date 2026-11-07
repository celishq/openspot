import SwiftUI

/// The accent ring inside the edge of the selected card, row, cell or item: the one mark of what Enter acts on. It moves
/// at once between items, unless a motion is given for a sheet that grows out of its card.
struct SpotSelectionRing<Edge: InsettableShape>: ViewModifier {
    static var width: CGFloat { 2 }
    static var thinWidth: CGFloat { 1.5 }

    let isSelected: Bool
    let shape: Edge
    var width = Self.width
    var motion: Animation?

    func body(content: Content) -> some View {
        content.overlay(
            shape.strokeBorder(SpotTheme.accent, lineWidth: width)
                .animation(motion) { $0.opacity(isSelected ? 1 : 0) }
                .allowsHitTesting(false)
        )
    }
}
