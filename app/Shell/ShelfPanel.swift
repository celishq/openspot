import AppKit
import SwiftUI

final class ShelfPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    static func make(model: ShelfModel) -> ShelfPanel {
        let panel = ShelfPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: ShelfView(model: model, close: { panel.orderOut(nil) }))
        panel.center()
        return panel
    }
}
