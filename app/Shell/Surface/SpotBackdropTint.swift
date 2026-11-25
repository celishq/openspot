import AppKit
import OpenspotCore
import SwiftUI

struct SpotBackdropTint: NSViewRepresentable {
    final class Surface: NSView {
        private let shape = CALayer()
        private var color: Color
        private var area: CGRect
        private var isMoving = false
        private let mask = SpotBackdropMask()
        private var drawn: (fade: SpotBackdropFade, isMoving: Bool)?

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

        func take(color next: Color, area nextArea: CGRect, isMoving moving: Bool) {
            if next != color {
                color = next
                needsDisplay = true
            }
            guard nextArea != area || moving != isMoving else { return }
            area = nextArea
            isMoving = moving
            applyFade()
        }

        private func applyFade() {
            let fade = SpotBackdropFade(fade: .current(blur: nil), area: area, size: bounds.size)
            guard fade != drawn?.fade || isMoving != drawn?.isMoving else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }
            shape.frame = bounds
            shape.contents = mask.image(of: fade, isMoving: isMoving)
            drawn = (fade, isMoving)
        }
    }

    let color: Color
    let area: CGRect
    let isMoving: Bool

    init(color: Color, fadingIn area: CGRect, isMoving: Bool) {
        self.color = color
        self.area = area
        self.isMoving = isMoving
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: Surface, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    func makeNSView(context: Context) -> Surface {
        Surface(color: color, area: area)
    }

    func updateNSView(_ surface: Surface, context: Context) {
        surface.take(color: color, area: area, isMoving: isMoving)
    }
}
