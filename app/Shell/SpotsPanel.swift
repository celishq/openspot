import AppKit
import Carbon.HIToolbox
import ObjectiveC
import OpenspotCore
import SwiftUI

final class SpotsPanel: NSPanel {
    private var model: SpotsModel?

    override var canBecomeKey: Bool { true }

    /// Brings the panel to the front and starts its open motion.
    func show() {
        model?.isOpenForDrag = false
        open { makeKeyAndOrderFront(nil) }
    }

    /// Shows the panel under a drag with no change of focus: it does not become key, and it closes when the drag ends.
    func showForDrag() {
        model?.prepareForDrag()
        open { orderFrontRegardless() }
    }

    private func open(ordering order: () -> Void) {
        model?.finishPick()
        model?.selected = 0
        model?.takeHeld(Self.modifiers(of: NSEvent.modifierFlags))
        model?.panelWillShow()
        order()
        DispatchQueue.main.async { self.model?.isShown = true }
    }

    /// Whether a point on the screen lies on the part of the panel that shows the drop state. The window is taller than that.
    func showsDrop(at point: NSPoint) -> Bool {
        guard let model, model.isShown else { return false }
        let rows = model.placements.map { $0.row + $0.size.rows }.max() ?? 0
        let height = SpotTokens.backdropHeight(rows: max(rows, SpotsModel.dropRows))
        return NSRect(x: frame.minX, y: frame.maxY - height, width: frame.width, height: height).contains(point)
    }

    /// Starts the close motion, and takes the panel off the screen when it ends.
    func hide() {
        model?.takeHeld([])
        model?.stopRecording()
        model?.closeMenu()
        model?.isShown = false
        DispatchQueue.main.asyncAfter(deadline: .now() + SpotMotion.fadeOutDuration) {
            guard self.model?.isShown == false else { return }
            self.orderOut(nil)
            self.model?.finishPick()
            self.model?.panelDidHide()
        }
    }

    /// Gives each key to the actions first, so that they work whichever field has the focus.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .flagsChanged { model?.takeHeld(Self.modifiers(of: event.modifierFlags)) }
        if event.type == .keyDown {
            if model?.recordingPart != nil {
                if Int(event.keyCode) == kVK_Escape {
                    model?.stopRecording()
                } else {
                    model?.record(code: UInt32(event.keyCode), modifiers: Self.modifiers(of: event.modifierFlags))
                }
                return
            }
            if let key = Self.actionKey(of: event), model?.handleKey(key) == true { return }
            if model?.handleChain(code: UInt32(event.keyCode), modifiers: Self.modifiers(of: event.modifierFlags)) == true { return }
        }
        super.sendEvent(event)
    }

    private static func modifiers(of flags: NSEvent.ModifierFlags) -> Shortcut.Modifiers {
        var modifiers: Shortcut.Modifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        return modifiers
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
        if model?.isShown == true, model?.isReviewing != true { hide() }
    }

    /// Takes ⌘V for a copied `.spot` file while the panel shows. The Edit menu takes the key before the panel sees it, so this
    /// looks first. It goes by the key's place, which holds on any keyboard layout.
    private func watchPaste(model: SpotsModel) {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak model] event in
            guard Int(event.keyCode) == kVK_ANSI_V, Self.modifiers(of: event.modifierFlags) == .command else { return event }
            let isTaken = MainActor.assumeIsolated { model?.isShown == true && model?.pasteSpot() == true }
            return isTaken ? nil : event
        }
    }

    /// Takes the system's low-resolution glow off each text cursor whenever the cursor draws, so that none ever shows.
    private static let plainCursors: Void = {
        typealias Draw = @convention(c) (NSView, Selector) -> Void
        let selector = #selector(NSView.updateLayer)
        guard let method = class_getInstanceMethod(NSTextInsertionIndicator.self, selector) else { return }
        let original = unsafeBitCast(method_getImplementation(method), to: Draw.self)
        let plain: @convention(block) (NSTextInsertionIndicator) -> Void = { cursor in
            original(cursor, selector)
            cursor.automaticModeOptions = []
            for layer in cursor.layer?.sublayers ?? [] where layer.sublayers?.contains(where: { $0.filters?.isEmpty == false }) == true {
                layer.removeFromSuperlayer()
            }
        }
        method_setImplementation(method, imp_implementationWithBlock(plain))
    }()

    static func make(model: SpotsModel) -> SpotsPanel {
        _ = plainCursors
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
        panel.contentView = NSHostingView(rootView: SpotsView(model: model))
        panel.watchPaste(model: model)
        panel.center()
        return panel
    }
}
