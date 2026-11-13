import AppKit
import OpenspotCore
import SwiftUI

/// A window for toasts under the Openspot menu bar item, or at the top of the screen when the item shows nowhere, so they
/// show when the spots panel is closed. It is as large as its message, up to 560 pt wide.
/// Only a toast with a fix takes input: a click on it, or its fix key, opens the fix (A15).
final class ToastPanel: NSPanel {
    static let margin: CGFloat = 16
    private static let maxSize = NSSize(width: 560, height: 120)
    private static let duration: TimeInterval = 5

    let toast = Toast()
    /// The view that sizes the window to a message, made once and given a copy of each toast.
    private lazy var measure = NSHostingController(rootView: ToastView(toast: Toast()))
    private var shows = 0
    private var fixKey: HotKey.Registration?
    /// The menu bar item that toasts hang from.
    weak var item: OpenspotItem?

    /// Shows a message, in place of any toast on screen, and hides it after a while, or keeps it with no duration. A fix opens
    /// on a click or on its key.
    func show(_ message: String, kind: ToastKind, fix: (@MainActor @Sendable () -> Void)? = nil, key: Shortcut? = nil, for duration: TimeInterval? = ToastPanel.duration) {
        shows += 1
        let current = shows
        toast.kind = kind
        let held = hold(fix: fix, key: key)
        toast.message = held.map { "\(message) Press `\($0.label)` to fix it." } ?? message
        let copy = Toast()
        copy.message = toast.message
        copy.kind = kind
        measure.rootView = ToastView(toast: copy)
        let width = min(measure.view.fittingSize.width.rounded(.up) + 1, Self.maxSize.width)
        let size = measure.sizeThatFits(in: NSSize(width: width, height: Self.maxSize.height))
        let place = ScreenPlace(screens: ScreenPlace.Screen.all)
        if let origin = place.origin(ofToast: size, inset: Self.margin, under: item?.frame) {
            setFrame(NSRect(origin: origin, size: size), display: true)
        }
        orderFrontRegardless()
        contentView?.layoutSubtreeIfNeeded()
        DispatchQueue.main.async {
            if self.shows == current { self.toast.isShown = true }
        }
        guard let duration else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            if self.shows == current { self.hide() }
        }
    }

    func hide() {
        shows += 1
        let current = shows
        hold(fix: nil, key: nil)
        toast.isShown = false
        DispatchQueue.main.asyncAfter(deadline: .now() + MotionTokens.fadeOut) {
            if self.shows == current { self.orderOut(nil) }
        }
    }

    /// Holds the fix key and takes clicks while a fix shows, and lets go of both when none does. It returns the key it holds.
    @discardableResult
    private func hold(fix: (@MainActor @Sendable () -> Void)?, key: Shortcut?) -> Shortcut? {
        fixKey.map(HotKey.unregister)
        fixKey = nil
        ignoresMouseEvents = fix == nil
        guard let fix else {
            toast.open = nil
            return nil
        }
        let open: @MainActor @Sendable () -> Void = { [weak self] in
            fix()
            self?.hide()
        }
        toast.open = open
        fixKey = key.flatMap { HotKey.register($0) { DispatchQueue.main.async(execute: open) } }
        return fixKey == nil ? nil : key
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
