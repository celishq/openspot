import SwiftUI

/// The accent ring inside the edge of the selected row, cell or card: the one mark of what Enter acts on.
struct SpotSelectionRing<Edge: InsettableShape>: ViewModifier {
    static var width: CGFloat { 2 }
    static var thinWidth: CGFloat { 1.5 }

    let isSelected: Bool
    let shape: Edge
    var width = Self.width

    func body(content: Content) -> some View {
        content.overlay(shape.strokeBorder(Color.accentColor, lineWidth: width).opacity(isSelected ? 1 : 0).allowsHitTesting(false))
    }
}
