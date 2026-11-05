import AppKit
import SwiftUI

/// A window at the top of the screen for toasts, so they show when the spots panel is closed. It takes no input.
final class ToastPanel: NSPanel {
    static let margin: CGFloat = 16
    private static let size = NSSize(width: 560, height: 120)
    private static let duration: TimeInterval = 5
    static let failureSymbol = "exclamationmark.triangle.fill"

    private let toast = Toast()
    private var shows = 0

    /// Shows a message, in place of any toast on screen, and hides it after a while.
    func show(_ message: String, symbol: String? = nil, for duration: TimeInterval = ToastPanel.duration) {
        shows += 1
        let current = shows
        toast.message = message
        toast.symbol = symbol
        if let screen = NSScreen.main?.visibleFrame {
            setFrameOrigin(NSPoint(x: screen.midX - Self.size.width / 2, y: screen.maxY - Self.size.height))
        }
        orderFrontRegardless()
        DispatchQueue.main.async {
            if self.shows == current { self.toast.isShown = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            if self.shows == current { self.hide() }
        }
    }

    func hide() {
        shows += 1
        let current = shows
        toast.isShown = false
        DispatchQueue.main.asyncAfter(deadline: .now() + SpotMotion.fadeOutDuration) {
            if self.shows == current { self.orderOut(nil) }
        }
    }

    static func make() -> ToastPanel {
        let panel = ToastPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: ToastView(toast: panel.toast))
        return panel
    }
}
