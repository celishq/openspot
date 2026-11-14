import AppKit
import OpenspotCore
import SwiftUI

/// The window of one float: a spot's sheet or card at the pointer, outside the panel. It floats over other apps, stays when
/// another app takes the focus, and moves by a drag of its background (W4–W6).
final class SpotFloatPanel: NSPanel {
    private var model: SpotsModel?
    private var id = ""

    override var canBecomeKey: Bool { true }

    /// Gives each key to the float first, so that its rows and actions work whichever part has the focus (W8).
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, let model, let key = SpotsPanel.actionKey(of: event), model.handleFloatKey(key, in: id) { return }
        super.sendEvent(event)
    }

    /// Shows the float centred on the pointer, or moves it there. During a drag it does not take the focus, so that the drag
    /// goes on and the app that it came from keeps the focus (W5).
    func show(at pointer: NSPoint, isDragging: Bool) {
        let place = ScreenPlace(screens: ScreenPlace.Screen.all)
        if let origin = place.origin(of: frame.size, under: pointer) { setFrameOrigin(origin) }
        if isDragging {
            orderFrontRegardless()
        } else {
            NSApp.activate(ignoringOtherApps: true)
            makeKeyAndOrderFront(nil)
        }
    }

    /// Gives the window the size of its content. Its top edge stays, and it stays whole on its screen.
    func fit(_ size: CGSize) {
        guard size != frame.size else { return }
        var next = NSRect(x: frame.minX, y: frame.maxY - size.height, width: size.width, height: size.height)
        if let area = screen?.visibleFrame, next.minY < area.minY { next.origin.y = area.minY }
        setFrame(next, display: true)
    }

    static func make(model: SpotsModel, id: String) -> SpotFloatPanel {
        let panel = SpotFloatPanel(
            contentRect: NSRect(x: 0, y: 0, width: SpotTokens.gridWidth, height: SpotTokens.rowHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.model = model
        panel.id = id
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = NSHostingView(rootView: SpotFloatView(model: model, id: id) { [weak panel] in panel?.fit($0) })
        view.sizingOptions = []
        panel.contentView = view
        return panel
    }
}
