import AppKit
import SwiftUI

/// The edge of a Control Center surface: light added to what lies behind at the top and bottom, with a narrow
/// glow inside it, and a thin dark line down the sides. Its radius animates with the surrounding animation. With a `rect`,
/// it lies at that rect of a view of a fixed size, so that a growing rim moves layers and resizes no view.
struct SpotRim: View, @preconcurrency Animatable {
    var radius: CGFloat
    var rect: CGRect?

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>>> {
        get {
            let rect = rect ?? .zero
            return AnimatablePair(radius, AnimatablePair(AnimatablePair(rect.minX, rect.minY), AnimatablePair(rect.width, rect.height)))
        }
        set {
            radius = newValue.first
            guard rect != nil else { return }
            let place = newValue.second
            rect = CGRect(x: place.first.first, y: place.first.second, width: place.second.first, height: place.second.second)
        }
    }

    var body: some View {
        Backing(radius: radius, rect: rect)
    }
}

/// The layers behind a `SpotRim`. They change in the same commit as the surface, because nothing draws them first.
private struct Backing: NSViewRepresentable {
    var radius: CGFloat
    var rect: CGRect?

    final class Surface: NSView {
        var radius: CGFloat = 0 {
            didSet {
                if radius != oldValue { place() }
            }
        }
        /// Where the rim lies in the view, or nil for its bounds.
        var shapeRect: CGRect? {
            didSet {
                if shapeRect != oldValue { place() }
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
            sides.locations = [0, 0.3, 0.7, 1]
            sides.mask = sideLine
            ends.locations = [0, 0.3, 0.7, 1]
            ends.compositingFilter = "plusL"
            ends.mask = endLines
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

        /// Takes the rim's colours from the theme of this appearance.
        private func applyTheme() {
            let theme = SpotTheme.palette(for: effectiveAppearance)
            sides.colors = SpotTheme.rimSideStrengths.map { SpotTheme.rimSides.withAlphaComponent($0).cgColor }
            let alpha = theme.rimEnds.alphaComponent
            ends.colors = [alpha, 0, 0, alpha].map { theme.rimEnds.withAlphaComponent($0).cgColor }
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            needsLayout = true
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
            place()
        }

        /// Sets the layers to the rim's rect and radius, with no layout of the view.
        private func place() {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }
            applyTheme()
            let scale = window?.backingScaleFactor ?? 2
            let rect = shapeRect ?? bounds
            let local = CGRect(origin: .zero, size: rect.size)
            for part in [sides, ends, sideLine, endLines, glowClip, glow, wideLine, thinLine] as [CALayer] {
                part.frame = part === sides || part === ends ? rect : local
                part.contentsScale = scale
            }
            glowClip.cornerRadius = radius
            for line in [sideLine, wideLine, thinLine, glow] {
                line.path = RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .inset(by: line.lineWidth / 2)
                    .path(in: local)
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
        surface.shapeRect = rect
        return surface
    }

    func updateNSView(_ surface: Surface, context: Context) {
        surface.radius = radius
        surface.shapeRect = rect
    }
}
