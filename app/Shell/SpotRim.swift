import AppKit
import SwiftUI

/// The edge of a Control Center surface: light added to what lies behind at the top and bottom, with a narrow
/// glow inside it, and a thin dark line down the sides. Its radius animates with the surrounding animation.
struct SpotRim: View, @preconcurrency Animatable {
    var radius: CGFloat

    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    var body: some View {
        Backing(radius: radius)
    }
}

/// The layers behind a `SpotRim`. They change in the same commit as the surface, because nothing draws them first.
private struct Backing: NSViewRepresentable {
    var radius: CGFloat

    final class Surface: NSView {
        var radius: CGFloat = 0 {
            didSet {
                if radius != oldValue { needsLayout = true }
            }
        }

        private let sides = CAGradientLayer()
        private let sideLine = CAShapeLayer()
        private let ends = CAGradientLayer()
        private let endLines = CALayer()
        private let wideLine = CAShapeLayer()
        private let thinLine = CAShapeLayer()
        private let glowClip = CALayer()
        private let glow = CAShapeLayer()

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer?.addSublayer(sides)
            layer?.addSublayer(ends)
            sides.colors = [0, 0.3, 0.3, 0].map { NSColor.black.withAlphaComponent($0).cgColor }
            sides.locations = [0, 0.3, 0.7, 1]
            sides.mask = sideLine
            ends.colors = [1, 0, 0, 1].map { NSColor.white.withAlphaComponent($0).cgColor }
            ends.locations = [0, 0.3, 0.7, 1]
            ends.mask = endLines
            ends.compositingFilter = "plusL"
            endLines.addSublayer(glowClip)
            endLines.addSublayer(wideLine)
            endLines.addSublayer(thinLine)
            glowClip.addSublayer(glow)
            glowClip.masksToBounds = true
            glowClip.cornerCurve = .continuous
            glow.filters = Self.blur.map { [$0] }
            setUp(sideLine, lineWidth: 0.5, strength: 1)
            setUp(wideLine, lineWidth: 1, strength: 0.25)
            setUp(thinLine, lineWidth: 0.5, strength: 0.15)
            setUp(glow, lineWidth: 2, strength: 0.3)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private static var blur: NSObject? {
            let filter = (NSClassFromString("CAFilter") as? NSObject.Type)?
                .perform(NSSelectorFromString("filterWithType:"), with: "gaussianBlur")?
                .takeUnretainedValue() as? NSObject
            filter?.setValue(2, forKey: "inputRadius")
            return filter
        }

        private func setUp(_ line: CAShapeLayer, lineWidth: CGFloat, strength: Float) {
            line.fillColor = nil
            line.strokeColor = NSColor.black.cgColor
            line.lineWidth = lineWidth
            line.opacity = strength
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }
            let scale = window?.backingScaleFactor ?? 2
            for part in [sides, ends, sideLine, endLines, glowClip, glow, wideLine, thinLine] as [CALayer] {
                part.frame = bounds
                part.contentsScale = scale
            }
            glowClip.cornerRadius = radius
            for line in [sideLine, wideLine, thinLine, glow] {
                line.path = RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .inset(by: line.lineWidth / 2)
                    .path(in: bounds)
                    .cgPath
            }
        }
    }

    /// Fills the surface it lies on, so that a resize asks AppKit for no size of its own.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: Surface, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    func makeNSView(context: Context) -> Surface {
        let surface = Surface()
        surface.radius = radius
        return surface
    }

    func updateNSView(_ surface: Surface, context: Context) {
        surface.radius = radius
    }
}
