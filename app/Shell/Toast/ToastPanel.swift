import AppKit
import OpenspotCore
import SwiftUI

final class ToastPanel: NSPanel {
    static let duration: TimeInterval = 5

    let toasts = Toasts()
    private var stack = ToastStack()
    private var ends: [Int: DispatchWorkItem] = [:]
    private var isHeld = false
    private var leaving: Set<Int> = []
    private var fixKey: (toast: Int, registration: HotKey.Registration)?
    weak var item: OpenspotItem?
    var front: () -> CGRect? = { nil }

    func show(_ message: String, kind: ToastKind, tree: ViewTree? = nil, spot: String = "", id: String? = nil, press: (@MainActor @Sendable () -> Void)? = nil, fixKey key: Shortcut? = nil, for duration: TimeInterval? = ToastPanel.duration) {
        let added = stack.add(spot: spot, kind: kind, id: id)
        let number = added.number
        let open = closing(number, after: press ?? {})
        let held = press == nil ? nil : key.flatMap { holdFixKey(number, key: $0, open: open) }
        let words = held.map { "\(message) Press `\($0.label)` to fix it." } ?? message
        if !added.isNew, let shown = toasts.shown.first(where: { $0.id == number }) {
            shown.message = words
            shown.kind = kind
            shown.tree = tree
            shown.duration = duration
            shown.open = open
            shown.fixKey = press == nil ? nil : key
            measure(shown)
            toasts.widen()
            withAnimation(SpotMotion.move) { toasts.arrange() }
            place()
            ends.removeValue(forKey: number)?.cancel()
            if !isHeld { end(shown) }
            return
        }
        let toast = Toast(id: number, message: words, kind: kind, tree: tree, duration: duration)
        toast.open = open
        toast.fixKey = press == nil ? nil : key
        added.dropped.forEach(leave)
        measure(toast)
        toasts.shown.insert(toast, at: 0)
        toasts.widen()
        withAnimation(SpotMotion.move) { toasts.arrange() }
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
            withAnimation(SpotMotion.move) {
                self.toasts.shown.removeAll { $0.id == number }
                self.toasts.arrange()
            }
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
        toasts.widen()
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
        toasts.isExpanded = isHovered
        withAnimation(SpotMotion.move) { toasts.arrange() }
        if isHovered {
            place()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + MotionTokens.move) {
                if !self.isHeld { self.place() }
            }
        }
    }

    private func measure(_ toast: Toast) {
        let copy = Toast(id: toast.id, message: toast.message, kind: toast.kind, tree: toast.tree, duration: nil)
        let measure = NSHostingController(rootView: ToastView(toast: copy, showsContent: true))
        measure.sizingOptions = []
        let widest = SpotTokens.toastMaxSize.width - 2 * SpotTokens.toastRoom
        let width = min(measure.sizeThatFits(in: NSSize(width: widest, height: SpotTokens.toastMaxSize.height)).width.rounded(.up) + 1, widest)
        toast.size = measure.sizeThatFits(in: NSSize(width: width, height: SpotTokens.toastMaxSize.height))
    }

    private func place() {
        let room = 2 * SpotTokens.toastRoom
        let size = CGSize(width: (toasts.width ?? 0) + room, height: toasts.height + room)
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
        let view = NSHostingView(rootView: ToastStackView(toasts: panel.toasts))
        view.sizingOptions = []
        panel.contentView = view
        return panel
    }
}
