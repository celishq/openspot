import AppKit
import OpenspotCore
import SwiftUI

final class SpotSheetWindow: NSWindow, NSWindowDelegate {
    private var model: SpotsModel?
    private var id = ""
    private var isPresent = false

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, !event.modifierFlags.contains(.command), let model, let key = SpotsPanel.actionKey(of: event),
           key.name != "escape", model.handleFloatKey(key, in: id) { return }
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
        let window = SpotSheetWindow(
            contentRect: NSRect(origin: .zero, size: SpotTokens.windowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.model = model
        window.id = entry.id
        window.title = entry.spot.name
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.minSize = SpotTokens.windowMinSize
        window.delegate = window
        window.setFrameAutosaveName("spot-window-\(entry.id)")
        let host = NSHostingController(rootView: SpotFloatView(model: model, id: entry.id, fills: true) { _ in })
        host.sizingOptions = []
        host.sceneBridgingOptions = [.toolbars]
        window.contentViewController = host
        window.toolbarStyle = .unifiedCompact
        window.setContentSize(SpotTokens.windowSize)
        if window.frame.origin == .zero { window.center() }
        return window
    }
}
