import AppKit
import OpenspotCore
import SwiftUI

final class SpotSheetWindow: NSWindow, NSWindowDelegate {
    private var model: SpotsModel?
    private var id = ""
    private var isPresent = false
    var takesEscape: () -> Bool = { false }
    private var declared: CGSize?
    private var book: SettingsBook?
    private var sidebar: CGFloat?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        record(event) || super.performKeyEquivalent(with: event)
    }

    override func sendEvent(_ event: NSEvent) {
        if record(event) { return }
        if event.type == .keyDown, let key = event.actionKey, !key.isCommand, !textKeeps(key) {
            if key.name == "escape", !(firstResponder is NSText), book?.recording == nil { return takesEscape() ? () : performClose(nil) }
            if key.name != "escape", let model, model.handleFloatKey(key, in: id) { return }
        }
        super.sendEvent(event)
    }

    private func record(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, let book, book.recording != nil else { return false }
        let modifiers = event.keyModifiers
        let name = Shortcut(code: UInt32(event.keyCode), modifiers: modifiers)?.name ?? event.actionKey?.name ?? ""
        return book.record(key: name, modifiers: Shortcut.Modifiers.all.filter { modifiers.contains($0) }.compactMap(\.word))
    }

    func show() {
        let opens = !isPresent
        if opens {
            isPresent = true
            AppPresence.open()
            if let declared {
                setContentSize(declared)
                center()
            }
        }
        contentView?.layoutSubtreeIfNeeded()
        if opens, let sidebar, let split = contentView?.firstSplitView {
            split.setPosition(sidebar, ofDividerAt: 0)
        }
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }

    func focus() {
        guard isPresent else { return }
        NSApp.activate(ignoringOtherApps: true)
        makeKey()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        book?.refresh()
    }

    func windowWillClose(_ notification: Notification) {
        guard isPresent else { return }
        isPresent = false
        AppPresence.close()
        book?.closed()
        if model?.runs.floating.contains(id) == true { model?.land(id) }
    }

    static func make(model: SpotsModel, entry: SpotsModel.Entry) -> SpotSheetWindow {
        let window = make(
            remembers: true,
            title: entry.spot.name,
            name: "spot-window-\(entry.id)",
            size: SpotTokens.windowSize,
            minSize: SpotTokens.windowMinSize,
            content: SpotFloatView(model: model, id: entry.id, fills: true) { _ in }
        )
        window.model = model
        window.id = entry.id
        return window
    }

    static func make(settings model: SpotsModel, content: some View) -> SpotSheetWindow {
        let window = make(
            remembers: false, title: "Settings", name: "settings-window", size: SpotTokens.settingsWindowSize, minSize: SpotTokens.settingsWindowMinSize, bridges: true, content: content
        )
        window.book = model.settingsBook
        window.declared = SpotTokens.settingsWindowSize
        window.sidebar = SpotTokens.settingsSidebarIdeal
        window.toolbarStyle = .unified
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.isMovableByWindowBackground = false
        return window
    }

    static func make(remembers: Bool = true, title: String, name: String, size: CGSize = SpotTokens.windowSize, minSize: CGSize = SpotTokens.windowMinSize, bridges: Bool = false, content: some View) -> SpotSheetWindow {
        let window = SpotSheetWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.minSize = minSize
        window.delegate = window
        if remembers { window.setFrameAutosaveName(name) }
        let host = NSHostingController(rootView: content)
        host.sizingOptions = []
        if bridges { host.sceneBridgingOptions = .all }
        window.contentViewController = host
        window.setContentSize(size)
        if window.frame.origin == .zero { window.center() }
        return window
    }
}

private extension NSView {
    var firstSplitView: NSSplitView? {
        self as? NSSplitView ?? subviews.lazy.compactMap(\.firstSplitView).first
    }
}
