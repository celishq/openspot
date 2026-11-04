import AppKit
import SwiftUI

/// A blur of what lies behind the window, with no tint. Its radius animates with the surrounding animation.
struct SpotBlur: View, @preconcurrency Animatable {
    var radius: CGFloat

    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    var body: some View {
        Backing(radius: radius)
    }
}

/// The system blur view behind a `SpotBlur`, with its tint hidden.
private struct Backing: NSViewRepresentable {
    var radius: CGFloat

    final class Surface: NSVisualEffectView {
        var radius: CGFloat = 0

        override func layout() {
            super.layout()
            applyBlur()
        }

        override func updateLayer() {
            super.updateLayer()
            applyBlur()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { self.applyBlur() }
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            DispatchQueue.main.async { self.applyBlur() }
        }

        func applyBlur() {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }
            layer?.sublayers?.flatMap { $0.sublayers ?? [] }.forEach { part in
                part.isHidden = part.name != "backdrop"
                guard part.name == "backdrop" else { return }
                let kept = part.filters?.filter { ($0 as? NSObject)?.value(forKey: "name") as? String != "colorSaturate" }
                if kept?.count != part.filters?.count { part.filters = kept }
                part.setValue(radius, forKeyPath: "filters.gaussianBlur.inputRadius")
            }
        }
    }

    func makeNSView(context: Context) -> Surface {
        let surface = Surface()
        surface.blendingMode = .behindWindow
        surface.state = .active
        surface.radius = radius
        return surface
    }

    func updateNSView(_ surface: Surface, context: Context) {
        guard surface.radius != radius else { return }
        surface.radius = radius
        surface.applyBlur()
    }
}
