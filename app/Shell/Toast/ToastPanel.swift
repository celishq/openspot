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
    private var anchor: ToastAnchor?
    weak var item: OpenspotItem?
    var front: () -> CGRect? = { nil }

    func measure(_ toast: Toast) -> CGSize {
        let measure = NSHostingController(rootView: ToastView(toast: toast.copy))
        measure.sizingOptions = []
        let widest = SpotTokens.toastMaxWidth - 2 * SpotTokens.toastRoom
        let width = min(measure.sizeThatFits(in: NSSize(width: widest, height: .greatestFiniteMagnitude)).width.rounded(.up) + 1, widest)
        return measure.sizeThatFits(in: NSSize(width: width, height: .greatestFiniteMagnitude))
    }

    func reach(_ height: CGFloat) {
        if anchor == nil {
            let screens = ScreenPlace.Screen.all
            anchor = ScreenPlace(screens: screens).toastAnchor(inset: SpotTokens.toastRoom, under: item?.frame, window: screens.count < 2 ? nil : front(), pointer: NSEvent.mouseLocation)
        }
        guard let anchor else { return }
        let tall = height + 2 * SpotTokens.toastRoom
        guard !isVisible || tall > frame.height else { return }
        let size = CGSize(width: SpotTokens.toastMaxWidth, height: isVisible ? max(tall, frame.height) : tall)
        setFrame(NSRect(origin: CGPoint(x: (anchor.midX - size.width / 2).rounded(.down), y: (anchor.top - size.height).rounded(.down)), size: size), display: true)
        pointer.check()
    }

    func shift(for width: CGFloat) -> CGFloat {
        anchor?.shift(for: width) ?? 0
    }

    private var surface: CGRect {
        guard let toasts, isVisible else { return .zero }
        let size = toasts.frontSize
        return CGRect(x: frame.midX + toasts.frontShift - size.width / 2, y: frame.maxY - SpotTokens.toastRoom - size.height, width: size.width, height: size.height)
    }

    func bringToFront() {
        orderFrontRegardless()
        contentView?.layoutSubtreeIfNeeded()
        pointer.start()
    }

    func putAway() {
        anchor = nil
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

    func move(_ body: () -> Void) {
        withAnimation(SpotMotion.move, body)
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
