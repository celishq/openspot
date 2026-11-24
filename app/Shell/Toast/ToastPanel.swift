import AppKit
import OpenspotCore
import SwiftUI

final class ToastPanel: NSPanel, ToastWindow {
    private(set) var toasts: Toasts?
    private var fixKey: HotKey.Registration?
    private let nextFrames = NextFrame()
    private lazy var pointer = ToastPointer(area: { [weak self] in self?.surface ?? .zero }) { [weak self] inside in
        self?.ignoresMouseEvents = !inside
        self?.toasts?.hold(inside)
    }
    weak var item: OpenspotItem?
    var front: () -> CGRect? = { nil }

    func measure(_ toast: Toast) -> CGSize {
        let measure = NSHostingController(rootView: ToastView(toast: toast.copy))
        measure.sizingOptions = []
        let widest = SpotTokens.toastMaxWidth - 2 * SpotTokens.toastRoom
        let width = min(measure.sizeThatFits(in: NSSize(width: widest, height: .greatestFiniteMagnitude)).width.rounded(.up) + 1, widest)
        return measure.sizeThatFits(in: NSSize(width: width, height: .greatestFiniteMagnitude))
    }

    func place() {
        guard let toasts else { return }
        let room = 2 * SpotTokens.toastRoom
        let size = CGSize(width: toasts.width + room, height: toasts.height + room)
        let screens = ScreenPlace.Screen.all
        let window = screens.count < 2 ? nil : front()
        let place = ScreenPlace(screens: screens)
        if let origin = place.origin(ofToast: size, inset: SpotTokens.toastRoom, under: item?.frame, window: window, pointer: NSEvent.mouseLocation) {
            setFrame(NSRect(origin: origin, size: size), display: true)
        }
        pointer.check()
    }

    private var surface: CGRect {
        guard let toasts, isVisible else { return .zero }
        let size = toasts.frontSize
        return CGRect(x: frame.midX - size.width / 2, y: frame.maxY - SpotTokens.toastRoom - size.height, width: size.width, height: size.height)
    }

    func bringToFront() {
        orderFrontRegardless()
        contentView?.layoutSubtreeIfNeeded()
        pointer.start()
    }

    func putAway() {
        pointer.stop()
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

    func move(_ body: () -> Void, completion: @escaping @MainActor () -> Void) {
        withAnimation(SpotMotion.move, completionCriteria: .logicallyComplete, body, completion: completion)
    }

    static func make(toasts: Toasts) -> ToastPanel {
        let panel = ToastPanel(
            contentRect: .zero,
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
        panel.acceptsMouseMovedEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.toasts = toasts
        toasts.window = panel
        let view = NSHostingView(rootView: ToastsView(toasts: toasts))
        view.sizingOptions = []
        panel.contentView = view
        return panel
    }
}
