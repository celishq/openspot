import AppKit
import OpenspotCore
import SwiftUI

final class ToastPanel: NSPanel, ToastWindow {
    private(set) var toasts: Toasts?
    private var fixKey: HotKey.Registration?
    private let nextFrames = NextFrame()
    weak var item: OpenspotItem?
    var front: () -> CGRect? = { nil }

    func show(_ message: String, kind: ToastKind, press: (@MainActor @Sendable () -> Void)? = nil, fixKey key: Shortcut? = nil, for duration: TimeInterval? = Toasts.duration) {
        toasts?.add(ToastNote(words: message), kind: kind, press: press, fixKey: key, for: duration)
    }

    func measure(_ toast: Toast) -> CGSize {
        let measure = NSHostingController(rootView: ToastView(toast: toast.copy, showsContent: true))
        measure.sizingOptions = []
        let widest = SpotTokens.toastMaxSize.width - 2 * SpotTokens.toastRoom
        let width = min(measure.sizeThatFits(in: NSSize(width: widest, height: SpotTokens.toastMaxSize.height)).width.rounded(.up) + 1, widest)
        return measure.sizeThatFits(in: NSSize(width: width, height: SpotTokens.toastMaxSize.height))
    }

    func place() {
        guard let toasts else { return }
        let room = 2 * SpotTokens.toastRoom
        let size = CGSize(width: (toasts.width ?? 0) + room, height: toasts.height + room)
        let screens = ScreenPlace.Screen.all
        let window = screens.count < 2 ? nil : front()
        let place = ScreenPlace(screens: screens)
        if let origin = place.origin(ofToast: size, inset: SpotTokens.toastRoom, under: item?.frame, window: window, pointer: NSEvent.mouseLocation) {
            setFrame(NSRect(origin: origin, size: size), display: true)
        }
    }

    func bringToFront() {
        ignoresMouseEvents = false
        orderFrontRegardless()
        contentView?.layoutSubtreeIfNeeded()
    }

    func putAway() {
        ignoresMouseEvents = true
        orderOut(nil)
    }

    func nextFrame(_ body: @escaping @MainActor () -> Void) {
        nextFrames.run(in: contentView, body)
    }

    func holdFixKey(_ key: Shortcut, press: @escaping @MainActor @Sendable () -> Void) -> Bool {
        fixKey = HotKey.register(key, action: { DispatchQueue.main.async(execute: press) })
        return fixKey != nil
    }

    func dropFixKey() {
        fixKey.map(HotKey.unregister)
        fixKey = nil
    }

    static func make(toasts: Toasts) -> ToastPanel {
        let panel = ToastPanel(
            contentRect: NSRect(origin: .zero, size: SpotTokens.toastMaxSize),
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
        panel.toasts = toasts
        toasts.window = panel
        let view = NSHostingView(rootView: ToastStackView(toasts: toasts))
        view.sizingOptions = []
        panel.contentView = view
        return panel
    }
}
