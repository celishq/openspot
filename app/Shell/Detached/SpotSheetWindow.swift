import AppKit
import OpenspotCore
import SwiftUI

final class SpotSheetWindow: NSWindow, NSWindowDelegate {
    private var model: SpotsModel?
    private var id = ""
    private var isPresent = false

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, let key = event.actionKey, !key.isCommand, !textKeeps(key) {
            if key.name == "escape", !(firstResponder is NSText) { return performClose(nil) }
            if key.name != "escape", let model, model.handleFloatKey(key, in: id) { return }
        }
        super.sendEvent(event)
    }

    func show() {
        if !isPresent {
            isPresent = true
            AppPresence.open()
        }
        contentView?.layoutSubtreeIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard isPresent else { return }
        isPresent = false
        AppPresence.close()
        if model?.runs.floating.contains(id) == true { model?.land(id) }
    }

    static func make(model: SpotsModel, entry: SpotsModel.Entry) -> SpotSheetWindow {
        let window = make(title: entry.spot.name, name: "spot-window-\(entry.id)", content: SpotFloatView(model: model, id: entry.id, fills: true) { _ in })
        window.model = model
        window.id = entry.id
        return window
    }

    static func make(title: String, name: String, content: some View) -> SpotSheetWindow {
        let window = SpotSheetWindow(
            contentRect: NSRect(origin: .zero, size: SpotTokens.windowSize),
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
        window.minSize = SpotTokens.windowMinSize
        window.delegate = window
        window.setFrameAutosaveName(name)
        let host = NSHostingController(rootView: content)
        host.sizingOptions = []
        window.contentViewController = host
        window.setContentSize(SpotTokens.windowSize)
        if window.frame.origin == .zero { window.center() }
        return window
    }
}
