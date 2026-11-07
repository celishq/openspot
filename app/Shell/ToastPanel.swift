import AppKit
import OpenspotCore
import SwiftUI

/// A window at the top of the screen for toasts, so they show when the spots panel is closed. It is as large as its message.
/// Only a toast with a fix takes input: a click on it, or its fix key, opens the fix (A15).
final class ToastPanel: NSPanel {
    static let margin: CGFloat = 16
    private static let maxSize = NSSize(width: 560, height: 120)
    private static let duration: TimeInterval = 5
    static let failureSymbol = "exclamationmark.triangle.fill"
    static let confirmSymbol = "checkmark.circle.fill"

    private let toast = Toast()
    private lazy var measure = NSHostingController(rootView: ToastView(toast: toast))
    private var shows = 0
    private var fixKey: HotKey.Registration?

    /// Shows a message, in place of any toast on screen, and hides it after a while. A fix opens on a click or on its key.
    func show(_ message: String, symbol: String? = nil, fix: (() -> Void)? = nil, key: Shortcut? = nil, for duration: TimeInterval = ToastPanel.duration) {
        shows += 1
        let current = shows
        toast.message = message
        toast.symbol = symbol
        hold(fix: fix, key: key)
        let size = measure.sizeThatFits(in: Self.maxSize)
        if let screen = NSScreen.main?.visibleFrame {
            setFrame(NSRect(x: screen.midX - size.width / 2, y: screen.maxY - size.height, width: size.width, height: size.height), display: true)
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
        hold(fix: nil, key: nil)
        toast.isShown = false
        DispatchQueue.main.asyncAfter(deadline: .now() + SpotMotion.fadeOutDuration) {
            if self.shows == current { self.orderOut(nil) }
        }
    }

    /// Holds the fix key and takes clicks while a fix shows, and lets go of both when none does.
    private func hold(fix: (() -> Void)?, key: Shortcut?) {
        fixKey.map(HotKey.unregister)
        fixKey = nil
        ignoresMouseEvents = fix == nil
        guard let fix else {
            toast.open = nil
            toast.key = nil
            return
        }
        let open = { [weak self] in
            fix()
            self?.hide()
        }
        toast.open = open
        fixKey = key.flatMap { HotKey.register($0) { DispatchQueue.main.async(execute: open) } }
        toast.key = fixKey == nil ? nil : key
    }

    static func make() -> ToastPanel {
        let panel = ToastPanel(
            contentRect: NSRect(origin: .zero, size: maxSize),
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
        let view = NSHostingView(rootView: ToastView(toast: panel.toast))
        view.sizingOptions = []
        panel.contentView = view
        return panel
    }
}
