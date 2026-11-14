import AppKit
import OpenspotCore
import SwiftUI

final class SpotFloatPanel: NSPanel {
    private var model: SpotsModel?
    private var id = ""

    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, let model, let key = SpotsPanel.actionKey(of: event), model.handleFloatKey(key, in: id) { return }
        super.sendEvent(event)
    }

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
