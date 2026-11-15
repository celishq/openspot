import OpenspotCore
import SwiftUI

struct SpotSelectionRing<Edge: InsettableShape>: ViewModifier {
    static var width: CGFloat { SpotTokens.ring }

    let isSelected: Bool
    let shape: Edge
    var width = Self.width
    var progress: Double?
    var marksMenu = false

    func body(content: Content) -> some View {
        content.overlay(ring.allowsHitTesting(false))
        .transformAnchorPreference(key: SpotMenuAnchor.self, value: .bounds) { item, bounds in
            if isSelected, marksMenu { item = SpotMenuAnchor.Item(bounds: bounds) }
        }
    }

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
