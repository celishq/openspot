import AppKit
import OpenspotCore
import SwiftUI

struct SpotBackdropTint: NSViewRepresentable {
    final class Surface: NSView {
        private let shape = CALayer()
        private var color: Color
        private var area: CGRect
        private var drawn: SpotBackdropFade?

        init(color: Color, area: CGRect) {
            self.color = color
            self.area = area
            super.init(frame: .zero)
            wantsLayer = true
            layer?.mask = shape
        }

        required init?(coder: NSCoder) {
            nil
        }

        override var wantsUpdateLayer: Bool {
            true
        }

        override func updateLayer() {
            effectiveAppearance.performAsCurrentDrawingAppearance {
                layer?.backgroundColor = NSColor(color).cgColor
            }
        }

        override func layout() {
            super.layout()
            applyFade()
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        func take(color next: Color, area nextArea: CGRect) {
            if next != color {
                color = next
                needsDisplay = true
            }
            guard nextArea != area else { return }
            area = nextArea
            applyFade()
        }

        private func applyFade() {
            let fade = SpotBackdropFade(fade: .current(blur: nil), area: area, size: bounds.size)
            guard fade != drawn else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }
            shape.frame = bounds
            shape.contents = fade.image()
            drawn = fade
        }
    }

    let color: Color
    let area: CGRect

    init(color: Color, fadingIn area: CGRect) {
        self.color = color
        self.area = area
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: Surface, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    func makeNSView(context: Context) -> Surface {
        Surface(color: color, area: area)
    }

    func updateNSView(_ surface: Surface, context: Context) {
        surface.take(color: color, area: area)
    }
}
