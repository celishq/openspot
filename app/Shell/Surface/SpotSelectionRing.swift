import OpenspotCore
import SwiftUI

struct SpotSelectionRing<Edge: InsettableShape>: ViewModifier {
    static var width: CGFloat { SpotTokens.ring }

    let isSelected: Bool
    let shape: Edge
    var width = Self.width
    var progress: Double?
    var marksMenu = false
    var marksNow = true

    @ViewBuilder
    func body(content: Content) -> some View {
        if marksMenu {
            content.overlay(ring.allowsHitTesting(false))
                .background(MenuMark(isOn: isSelected && marksNow))
        } else {
            content.overlay(ring.allowsHitTesting(false))
        }
    }

    private struct MenuMark: View {
        let isOn: Bool

        @ViewBuilder
        var body: some View {
            if isOn {
                Color.clear.anchorPreference(key: SpotMenuAnchor.self, value: .bounds) { SpotMenuAnchor.Item(bounds: $0) }
            } else {
                Color.clear
            }
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
