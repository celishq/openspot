import AppKit
import SwiftUI

final class ShelfPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    static func make(model: ShelfModel) -> ShelfPanel {
        let panel = ShelfPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: ShelfView(model: model, close: { panel.orderOut(nil) }))
        panel.center()
        return panel
    }
}
