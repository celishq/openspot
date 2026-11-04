import AppKit
import SwiftUI

final class SpotsPanel: NSPanel {
    private var model: SpotsModel?

    override var canBecomeKey: Bool { true }

    /// Brings the panel to the front and starts its open motion.
    func show() {
        model?.selected = 0
        makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { self.model?.isShown = true }
    }

    /// Starts the close motion, and takes the panel off the screen when it ends.
    func hide() {
        model?.isShown = false
        DispatchQueue.main.asyncAfter(deadline: .now() + SpotMotion.fadeOutDuration) {
            if self.model?.isShown == false { self.orderOut(nil) }
        }
    }

    override func resignKey() {
        super.resignKey()
        if model?.isShown == true { hide() }
    }

    static func make(model: SpotsModel) -> SpotsPanel {
        let panel = SpotsPanel(
            contentRect: NSRect(x: 0, y: 0, width: SpotTokens.panelWidth, height: SpotTokens.panelHeight),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.model = model
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        panel.contentView = NSHostingView(rootView: SpotsView(model: model, close: { panel.hide() }))
        panel.center()
        return panel
    }
}
