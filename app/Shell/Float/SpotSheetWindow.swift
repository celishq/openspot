import AppKit
import OpenspotCore
import SwiftUI

/// The window of a spot that offers one: its sheet on the panel's glass, in a window that the person moves, resizes and
/// closes by the buttons of its clear title bar. The app shows in the Dock and in Command-Tab while it is open.
final class SpotSheetWindow: NSWindow, NSWindowDelegate {
    private var model: SpotsModel?
    private var id = ""
    /// Whether the window counts in `AppPresence`, from its show until it closes.
    private var isPresent = false

    /// Gives each key to the spot first, so that its rows and actions work whichever part has the focus. Esc closes the
    /// window, as it does a float.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, !event.modifierFlags.contains(.command), let model, let key = SpotsPanel.actionKey(of: event),
           model.handleFloatKey(key, in: id) { return }
        super.sendEvent(event)
    }

    /// Brings the window and the app to the front, with the app regular while the window is open.
    func show() {
        if !isPresent {
            isPresent = true
            AppPresence.open()
        }
        contentView?.layoutSubtreeIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }

    /// Closes the window, and lands its spot when the person closed it.
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
        let view = NSHostingView(rootView: SpotFloatView(model: model, id: entry.id, fills: true) { _ in })
        view.sizingOptions = []
        window.contentView = view
        if window.frame.origin == .zero { window.center() }
        return window
    }
}
