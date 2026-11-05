import AppKit
import Carbon.HIToolbox
import OpenspotCore
import SwiftUI

final class SpotsPanel: NSPanel {
    private var model: SpotsModel?

    override var canBecomeKey: Bool { true }

    /// Brings the panel to the front and starts its open motion.
    func show() {
        model?.finishPick()
        model?.selected = 0
        Task { await model?.reload() }
        makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { self.model?.isShown = true }
    }

    /// Starts the close motion, and takes the panel off the screen when it ends.
    func hide() {
        model?.closeMenu()
        model?.isShown = false
        DispatchQueue.main.asyncAfter(deadline: .now() + SpotMotion.fadeOutDuration) {
            guard self.model?.isShown == false else { return }
            self.orderOut(nil)
            self.model?.finishPick()
        }
    }

    /// Gives each key to the actions first, so that they work whichever field has the focus.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, let key = Self.actionKey(of: event), model?.handleKey(key) == true { return }
        super.sendEvent(event)
    }

    private static func actionKey(of event: NSEvent) -> ActionKey? {
        let name: String?
        switch Int(event.keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter: name = "return"
        case kVK_Delete: name = "backspace"
        case kVK_Escape: name = "escape"
        case kVK_UpArrow: name = "up"
        case kVK_DownArrow: name = "down"
        default: name = event.charactersIgnoringModifiers?.lowercased()
        }
        return name.map {
            ActionKey(name: $0, isCommand: event.modifierFlags.contains(.command), isShift: event.modifierFlags.contains(.shift))
        }
    }

    override func resignKey() {
        super.resignKey()
        if model?.isShown == true { hide() }
    }

    override func update() {
        super.update()
        if let field = (firstResponder as? NSTextView)?.delegate as? NSView {
            Self.removeCursorGlow(in: field)
        }
    }

    /// Removes the system's low-resolution glow from each text cursor in a view.
    private static func removeCursorGlow(in view: NSView) {
        if let cursor = view as? NSTextInsertionIndicator {
            cursor.automaticModeOptions = []
            for layer in cursor.layer?.sublayers ?? [] where layer.sublayers?.contains(where: { $0.filters?.isEmpty == false }) == true {
                layer.removeFromSuperlayer()
            }
        }
        view.subviews.forEach(removeCursorGlow)
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
