import AppKit
import SwiftUI

/// Makes the window redraw the whole blur together while it is active, so that a text change never redraws a patch of
/// it alone. It draws a faint layer that changes each frame, too faint to see.
struct SpotWholeRedraw: NSViewRepresentable {
    private static let key = "wholeRedraw"
    private static let tint = 0.004

    let isActive: Bool
    let radius: CGFloat

    final class Surface: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    func makeNSView(context: Context) -> Surface {
        let view = Surface()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.withAlphaComponent(Self.tint).cgColor
        view.layer?.cornerRadius = radius
        view.layer?.cornerCurve = .continuous
        return view
    }

    func updateNSView(_ view: Surface, context: Context) {
        guard let layer = view.layer else { return }
        guard isActive else {
            layer.removeAnimation(forKey: Self.key)
            return
        }
        guard layer.animation(forKey: Self.key) == nil else { return }
        let change = CABasicAnimation(keyPath: "opacity")
        change.fromValue = 1
        change.toValue = 0.9
        change.duration = 0.5
        change.autoreverses = true
        change.repeatCount = .infinity
        layer.add(change, forKey: Self.key)
    }
}
