import AppKit
import Carbon.HIToolbox
import ObjectiveC
import OpenspotCore
import SwiftUI

final class SpotsPanel: NSPanel {
    private var model: SpotsModel?

    override var canBecomeKey: Bool { true }

    /// Opens the panel unseen, so that the first real open has its answers, its views and a ready text field. It then closes
    /// and runs the given work. A real open during this keeps the panel open.
    func warm(then done: @escaping () -> Void) {
        model?.isWarming = true
        alphaValue = 0
        ignoresMouseEvents = true
        open { orderFrontRegardless() }
        Task { @MainActor [weak self] in
            await self?.model?.waitForReads()
            self?.contentView?.layoutSubtreeIfNeeded()
            self?.displayIfNeeded()
            try? await Task.sleep(for: .seconds(2 * SpotMotion.fadeInDuration))
            if self?.model?.isWarming == true {
                self?.model?.isWarming = false
                self?.hide()
            }
            done()
        }
    }

    private func endWarming() {
        model?.isWarming = false
        alphaValue = 1
        ignoresMouseEvents = false
    }

    /// Brings the panel to the front and starts its open motion.
    func show() {
        endWarming()
        model?.isOpenForDrag = false
        open { makeKeyAndOrderFront(nil) }
    }

    /// Shows the panel under a drag with no change of focus: it does not become key, and it closes when the drag ends.
    func showForDrag() {
        endWarming()
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

    /// Starts the close motion, and takes the panel off the screen when it ends.
    func hide() {
        model?.takeHeld([])
        model?.stopRecording()
        model?.closeMenu()
        model?.endEditing(motion: nil)
        model?.isShown = false
        DispatchQueue.main.asyncAfter(deadline: .now() + SpotMotion.fadeOutDuration) {
            guard self.model?.isShown == false else { return }
            self.orderOut(nil)
            self.alphaValue = 1
            self.ignoresMouseEvents = false
            self.model?.finishPick()
            self.model?.panelDidHide()
        }
    }

    /// Gives each key to the actions first, so that they work whichever field has the focus.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .flagsChanged { model?.takeHeld(Self.modifiers(of: event.modifierFlags)) }
        if event.type == .keyDown {
            if model?.recording != nil {
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
        case kVK_LeftArrow: name = "left"
        case kVK_RightArrow: name = "right"
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
        panel.center()
        return panel
    }
}
