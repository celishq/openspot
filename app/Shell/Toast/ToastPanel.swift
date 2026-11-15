import AppKit
import OpenspotCore
import SwiftUI

final class ToastPanel: NSPanel {
    static let margin: CGFloat = 16
    private static let maxSize = NSSize(width: 560, height: 120)
    private static let duration: TimeInterval = 5

    let toast = Toast()
    private lazy var measure = NSHostingController(rootView: ToastView(toast: Toast()))
    private var shows = 0
    private var fixKey: HotKey.Registration?
    weak var item: OpenspotItem?

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
