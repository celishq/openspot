import AppKit
import OpenspotCore
import SwiftUI

final class ToastPanel: NSPanel {
    static let duration: TimeInterval = 5

    let toasts = Toasts()
    private var stack = ToastStack()
    private lazy var measure = NSHostingController(rootView: ToastStackView(toasts: Toasts()))
    private var ends: [Int: DispatchWorkItem] = [:]
    private var isHeld = false
    private var leaving: Set<Int> = []
    private var fixKey: (toast: Int, registration: HotKey.Registration)?
    weak var item: OpenspotItem?
    var front: () -> CGRect? = { nil }

    func show(_ message: String, kind: ToastKind, spot: String = "", id: String? = nil, press: (@MainActor @Sendable () -> Void)? = nil, fixKey key: Shortcut? = nil, for duration: TimeInterval? = ToastPanel.duration) {
        let added = stack.add(spot: spot, kind: kind, id: id)
        let number = added.number
        let open = closing(number, after: press ?? {})
        let held = press == nil ? nil : key.flatMap { holdFixKey(number, key: $0, open: open) }
        let words = held.map { "\(message) Press `\($0.label)` to fix it." } ?? message
        if !added.isNew, let shown = toasts.shown.first(where: { $0.id == number }) {
            shown.message = words
            shown.kind = kind
            shown.duration = duration
            shown.open = open
            shown.fixKey = press == nil ? nil : key
            place()
            ends.removeValue(forKey: number)?.cancel()
            if !isHeld { end(shown) }
            return
        }
        let toast = Toast(id: number, message: words, kind: kind, duration: duration)
        toast.open = open
        toast.fixKey = press == nil ? nil : key
        added.dropped.forEach(leave)
        withAnimation(SpotMotion.move) { toasts.shown.insert(toast, at: 0) }
        place()
        ignoresMouseEvents = false
        orderFrontRegardless()
        contentView?.layoutSubtreeIfNeeded()
        DispatchQueue.main.async {
            guard self.isStacked(number) else { return }
            toast.isShown = true
            self.toasts.takeLead()
        }
        if !isHeld { end(toast) }
    }

    func drop(_ id: String, of spot: String) {
        stack.number(of: id, spot: spot).map(leave)
    }

    func hide() {
        stack.entries.map(\.number).forEach(leave)
    }

    private func leave(_ number: Int) {
        stack.remove(number)
        ends.removeValue(forKey: number)?.cancel()
        guard let toast = toasts.shown.first(where: { $0.id == number }), leaving.insert(number).inserted else { return }
        toast.isShown = false
        toasts.takeLead()
        if fixKey?.toast == number { passFixKey() }
        DispatchQueue.main.asyncAfter(deadline: .now() + MotionTokens.fadeOut) {
            self.leaving.remove(number)
            withAnimation(SpotMotion.move) { self.toasts.shown.removeAll { $0.id == number } }
            DispatchQueue.main.asyncAfter(deadline: .now() + MotionTokens.move) { self.settle() }
        }
    }

    private func closing(_ number: Int, after act: @escaping @MainActor @Sendable () -> Void) -> @MainActor @Sendable () -> Void {
        { [weak self] in
            act()
            self?.leave(number)
        }
    }

    private func isStacked(_ number: Int) -> Bool {
        stack.entries.contains { $0.number == number }
    }

    private func settle() {
        guard stack.entries.isEmpty else { return place() }
        guard toasts.shown.isEmpty else { return }
        ignoresMouseEvents = true
        isHeld = false
        orderOut(nil)
    }

    private func end(_ toast: Toast) {
        guard let duration = toast.duration else { return }
        let work = DispatchWorkItem { [weak self] in self?.leave(toast.id) }
        ends[toast.id]?.cancel()
        ends[toast.id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func hold(_ isHovered: Bool) {
        guard isHovered != isHeld else { return }
        isHeld = isHovered
        if isHovered {
            ends.values.forEach { $0.cancel() }
            ends.removeAll()
        } else {
            toasts.shown.filter { isStacked($0.id) }.forEach(end)
        }
    }

    private func place() {
        let copy = Toasts()
        copy.shown = toasts.shown.map { Toast(id: $0.id, message: $0.message, kind: $0.kind, duration: nil) }
        measure.rootView = ToastStackView(toasts: copy)
        let width = min(measure.view.fittingSize.width.rounded(.up) + 1, SpotTokens.toastMaxSize.width)
        let size = measure.sizeThatFits(in: NSSize(width: width, height: SpotTokens.toastMaxSize.height * CGFloat(ToastStack.limit)))
        let screens = ScreenPlace.Screen.all
        let window = screens.count < 2 ? nil : front()
        let place = ScreenPlace(screens: screens)
        if let origin = place.origin(ofToast: size, inset: SpotTokens.toastRoom, under: item?.frame, window: window, pointer: NSEvent.mouseLocation) {
            setFrame(NSRect(origin: origin, size: size), display: true)
        }
    }

    @discardableResult
    private func holdFixKey(_ number: Int, key: Shortcut, open: @escaping @MainActor @Sendable () -> Void) -> Shortcut? {
        fixKey.map { HotKey.unregister($0.registration) }
        fixKey = nil
        guard let registration = HotKey.register(key, action: { DispatchQueue.main.async(execute: open) }) else { return nil }
        fixKey = (number, registration)
        return key
    }

    private func passFixKey() {
        fixKey.map { HotKey.unregister($0.registration) }
        fixKey = nil
        guard let next = toasts.shown.first(where: { $0.fixKey != nil && isStacked($0.id) }), let key = next.fixKey, let open = next.open else { return }
        holdFixKey(next.id, key: key, open: open)
    }

    static func make() -> ToastPanel {
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
        panel.toasts.hover = { [weak panel] in panel?.hold($0) }
        let view = NSHostingView(rootView: ToastStackView(toasts: panel.toasts).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top))
        view.sizingOptions = []
        panel.contentView = view
        return panel
    }
}
