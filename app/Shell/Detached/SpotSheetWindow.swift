import AppKit
import OpenspotCore
import SwiftUI

final class SpotSheetWindow: NSWindow, NSWindowDelegate {
    private var model: SpotsModel?
    private var id = ""
    private var isPresent = false
    private var declared: CGSize?
    private var book: SettingsBook?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, let key = event.actionKey, !key.isCommand, !textKeeps(key) {
            if key.name == "escape", !(firstResponder is NSText), book?.recording == nil { return performClose(nil) }
            if key.name != "escape", let model, model.handleFloatKey(key, in: id) { return }
        }
        super.sendEvent(event)
    }

    func show() {
        if !isPresent {
            isPresent = true
            AppPresence.open()
            if let declared {
                setContentSize(declared)
                center()
            }
        }
        contentView?.layoutSubtreeIfNeeded()
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
        let size = entry.spot.window
        let window = make(
            remembers: size == nil,
            title: entry.spot.name,
            name: "spot-window-\(entry.id)",
            size: size?.size ?? SpotTokens.windowSize,
            minSize: size?.minSize ?? SpotTokens.windowMinSize,
            content: SpotFloatView(model: model, id: entry.id, fills: true) { _ in }
        )
        window.model = model
        window.id = entry.id
        window.declared = size?.size
        if size != nil {
            window.toolbar = NSToolbar(identifier: "spot-window-\(entry.id)")
            window.toolbarStyle = .unified
        }
        return window
    }

    static func make(settings model: SpotsModel, content: some View) -> SpotSheetWindow {
        let size = WindowSize.settings
        let window = make(remembers: false, title: "Settings", name: "settings-window", size: size.size, minSize: size.minSize, bridges: true, content: content)
        window.book = model.settingsBook
        window.declared = size.size
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
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
