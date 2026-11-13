import AppKit
import Carbon.HIToolbox
import ObjectiveC
import OpenspotCore
import SwiftUI

final class SpotsPanel: NSPanel {
    private var model: SpotsModel?
    let place = SpotsWindowPlace()
    private let cover = SpotsCover()
    /// The frame that the window had before Edit Spots grew it.
    private var restFrame: NSRect?
    private var pressWatch: Task<Void, Never>?
    private var tap = ModifierTap()
    /// The stage of the trackpad's press: 1 for a click, 2 for a force click.
    private var pressStage = 0
    /// Whether a force click opened the menu and its button is still down, so that its release runs the row under it.
    private var isForceDragging = false

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
            try? await Task.sleep(for: .seconds(2 * MotionTokens.fadeIn))
            if self?.model?.isWarming == true {
                self?.model?.isWarming = false
                self?.hide(then: done)
            } else {
                done()
            }
        }
    }

    private func endWarming() {
        model?.isWarming = false
        alphaValue = 1
        ignoresMouseEvents = false
    }

    /// Moves the panel onto the screen of the app's front window, or with none, of the pointer (A18). An open panel stays.
    /// With one screen it asks for no window, since the panel can open nowhere else.
    func place(over app: NSRunningApplication?) {
        guard model?.isShown != true || model?.isWarming == true else { return }
        let screens = ScreenPlace.Screen.all
        let mainHeight = NSScreen.screens.first?.frame.maxY ?? 0
        let window = screens.count < 2 ? nil : app.flatMap(Self.frontWindow).map { ScreenPlace.frame(ofBounds: $0, mainHeight: mainHeight) }
        guard let origin = ScreenPlace(screens: screens).origin(of: frame.size, window: window, pointer: NSEvent.mouseLocation) else { return }
        setFrameOrigin(origin)
    }

    /// The bounds of the app's front window, as Core Graphics gives them, or nil when it shows none. They need no permission.
    private static func frontWindow(of app: NSRunningApplication) -> CGRect? {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let front = windows.first {
            ($0[kCGWindowOwnerPID as String] as? pid_t) == app.processIdentifier && ($0[kCGWindowLayer as String] as? Int) == 0
        }
        return (front?[kCGWindowBounds as String] as? NSDictionary).flatMap { CGRect(dictionaryRepresentation: $0) }
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
        model?.panelWillShow(holding: Self.modifiers(of: NSEvent.modifierFlags))
        order()
    }

    /// Whether a point on the screen lies on the part of the panel that takes a drop. The window is taller than that.
    func showsDrop(at point: NSPoint) -> Bool {
        guard let model, model.isShown else { return false }
        let height = SpotTokens.backdropHeight(gridHeight: SpotGrid.height(of: model.placements))
        return NSRect(x: frame.minX, y: frame.maxY - height, width: frame.width, height: height).contains(point)
    }

    /// Grows the window in Edit Spots to hold the store from the top of the screen to its bottom, glides the panel up to the
    /// top, and fades the store in under it. When Edit Spots ends, the store fades out and the panel glides back, and then
    /// the window gets its frame back. A panel that closes keeps its frame until it is gone.
    private func followEditing() {
        guard let model else { return }
        let isEditing = withObservationTracking { model.isEditing } onChange: { [weak self] in
            Task { @MainActor in self?.followEditing() }
        }
        if isEditing, restFrame == nil, let area = screen?.visibleFrame {
            restFrame = frame
            place.isOut = false
            layOutEditing(in: area, isSettled: false)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.model?.isEditing == true else { return }
                withAnimation(SpotMotion.move) {
                    self.place.isOut = true
                    self.place.lift = 0
                }
            }
        } else if !isEditing, let rest = restFrame, model.isShown {
            withAnimation(SpotMotion.move) {
                place.isOut = false
                place.lift = frame.maxY - rest.maxY - place.panel.y
            } completion: { [weak self] in
                if self?.model?.isEditing == false { self?.restoreFrame() }
            }
        }
    }

    /// Grows the window in Edit Spots from its frame at rest to hold the store under the panel, with the panel lifted as far
    /// as the store needs. A settled panel is drawn at its lifted place, and one that is not yet settled at its place at rest.
    private func layOutEditing(in area: NSRect, isSettled: Bool) {
        guard let model, let panel = restFrame else { return }
        let content = SpotTokens.backdropHeight(gridHeight: SpotGrid.height(of: model.placements)) - SpotTokens.halo
        let edit = ScreenPlace.edit(under: NSRect(x: panel.minX, y: panel.maxY - content, width: panel.width, height: content), in: area)
        let lifted = panel.offsetBy(dx: 0, dy: edit.lift)
        let whole = panel.union(lifted).union(edit.dock)
        place.panel = CGPoint(x: lifted.minX - whole.minX, y: whole.maxY - lifted.maxY)
        place.lift = isSettled ? 0 : edit.lift
        place.dock = CGRect(x: edit.dock.minX - whole.minX, y: whole.maxY - edit.dock.maxY, width: edit.dock.width, height: edit.dock.height)
        place.storeSize = edit.dock.size
        model.dockFrame = place.dock?.offsetBy(dx: -place.panel.x, dy: -place.panel.y)
        resize(to: whole)
    }

    /// Gives the window the width of the grid's columns about the same middle, and in Edit Spots lays the store out again.
    private func followColumns() {
        guard let model else { return }
        let width = withObservationTracking { SpotTokens.panelWidth(columns: model.columns) } onChange: { [weak self] in
            Task { @MainActor in self?.followColumns() }
        }
        if let rest = restFrame {
            guard rest.width != width, let area = screen?.visibleFrame else { return }
            restFrame = NSRect(x: (rest.midX - width / 2).rounded(.down), y: rest.minY, width: width, height: rest.height)
            layOutEditing(in: area, isSettled: true)
        } else if frame.width != width {
            resize(to: NSRect(x: (frame.midX - width / 2).rounded(.down), y: frame.minY, width: width, height: frame.height))
        }
    }

    /// Shows the wallpaper over the other apps while the panel shows in Edit Spots, and takes it away when either ends.
    private func followCover() {
        guard let model else { return }
        let covers = withObservationTracking { model.isEditing && model.isShown } onChange: { [weak self] in
            Task { @MainActor in self?.followCover() }
        }
        if covers {
            cover.show(under: self) { [weak model] in model?.endEditing() }
        } else {
            cover.hide()
        }
    }

    /// Gives the window the frame it had before Edit Spots grew it, with the panel at its top left corner and no dock.
    private func restoreFrame() {
        guard let rest = restFrame else { return }
        restFrame = nil
        place.isOut = false
        place.dock = nil
        place.panel = .zero
        place.lift = 0
        model?.dockFrame = nil
        resize(to: rest)
    }

    /// Gives the window this frame and lays its content out at the new places in the same commit, so that no frame shows the
    /// content at its old place in the new frame.
    private func resize(to frame: NSRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        setFrame(frame, display: false)
        contentView?.layoutSubtreeIfNeeded()
        displayIfNeeded()
        CATransaction.commit()
    }

    /// Starts the close motion, and takes the panel off the screen when it ends. Then it runs the given work.
    func hide(then done: (() -> Void)? = nil) {
        model?.panelWillHide()
        DispatchQueue.main.asyncAfter(deadline: .now() + MotionTokens.fadeOut) {
            defer { done?() }
            guard self.model?.isShown == false else { return }
            self.orderOut(nil)
            if self.model?.isEditing == false { self.restoreFrame() }
            self.alphaValue = 1
            self.ignoresMouseEvents = false
            self.model?.panelDidHide()
        }
    }

    /// Gives each key to the actions first, so that they work whichever field has the focus.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .flagsChanged {
            model?.takeHeld(Self.modifiers(of: event.modifierFlags))
            if let modifier = tap.take(Self.modifiers(of: event.modifierFlags), at: event.timestamp), model?.recording != nil {
                model?.recordTap(modifier)
            }
        }
        if event.type == .pressure { takePressure(event) }
        if isForceDragging, let model {
            switch event.type {
            case .leftMouseDragged:
                model.dragMenu(to: panelPoint(of: event))
            case .leftMouseUp:
                isForceDragging = false
                super.sendEvent(event)
                model.releaseMenu(at: panelPoint(of: event))
                return
            default: break
            }
        }
        if event.type == .rightMouseDown, let model, model.isShown, !model.isEditing, model.openList == nil {
            openMenu(at: event)
            return
        }
        if event.type == .keyDown {
            tap.spoil()
            if model?.recording != nil {
                if Int(event.keyCode) == kVK_Escape {
                    model?.stopRecording()
                } else {
                    model?.record(code: UInt32(event.keyCode), modifiers: Self.modifiers(of: event.modifierFlags))
                }
                return
            }
            if Int(event.keyCode) == kVK_Return, event.modifierFlags.contains(.command), model?.openSoleSettings() == true { return }
            if let key = Self.actionKey(of: event), !textKeepsArrow(key), model?.handleKey(key) == true { return }
            if model?.handleChain(code: UInt32(event.keyCode), modifiers: Self.modifiers(of: event.modifierFlags)) == true { return }
        }
        super.sendEvent(event)
    }

    /// Opens the actions menu of the card under a force click, when the press reaches its second stage.
    private func takePressure(_ event: NSEvent) {
        defer { pressStage = event.stage }
        guard event.stage == 2, pressStage < 2 else { return }
        openMenu(at: event)
        isForceDragging = model?.menu != nil
    }

    /// Opens the actions menu of the card under the pointer of this event.
    private func openMenu(at event: NSEvent) {
        model?.openMenu(at: panelPoint(of: event))
    }

    /// Where the pointer of this event lies in the panel, from its top left corner.
    private func panelPoint(of event: NSEvent) -> CGPoint {
        CGPoint(x: event.locationInWindow.x, y: (contentView?.bounds.height ?? 0) - event.locationInWindow.y)
    }

    /// Whether the text view that has the focus keeps an up or down arrow: up while its caret lies below its first line, and
    /// down while it lies above its last. At an edge, the arrow moves the focus to the next part of the sheet.
    private func textKeepsArrow(_ key: ActionKey) -> Bool {
        guard key == ActionKey(name: "up") || key == ActionKey(name: "down"),
              let text = firstResponder as? NSTextView, text.isEditable, !text.isFieldEditor
        else { return false }
        let line = { (location: Int) in text.firstRect(forCharacterRange: NSRange(location: location, length: 0), actualRange: nil).midY }
        let caret = line(text.selectedRange().location)
        let edge = line(key.name == "up" ? 0 : (text.string as NSString).length)
        return abs(caret - edge) > 1
    }

    static func modifiers(of flags: NSEvent.ModifierFlags) -> Shortcut.Modifiers {
        var modifiers: Shortcut.Modifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        return modifiers
    }

    static func actionKey(of event: NSEvent) -> ActionKey? {
        let isCommand = event.modifierFlags.contains(.command)
        let isShift = event.modifierFlags.contains(.shift)
        let name: String
        switch Int(event.keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter: name = "return"
        case kVK_Delete: name = "backspace"
        case kVK_Escape: name = "escape"
        case kVK_UpArrow: name = "up"
        case kVK_DownArrow: name = "down"
        case kVK_LeftArrow: name = "left"
        case kVK_RightArrow: name = "right"
        default:
            guard let typed = event.charactersIgnoringModifiers else { return nil }
            return ActionKey(typed: typed, code: event.keyCode, isCommand: isCommand, isShift: isShift, latin: SpotKeyLayouts.latin)
        }
        return ActionKey(name: name, isCommand: isCommand, isShift: isShift)
    }

    override func becomeKey() {
        super.becomeKey()
        pressWatch?.cancel()
    }

    /// Closes the panel when another app takes the focus. A press that took it can start a drag of files toward a card, so
    /// the panel waits for the press to end, and a new drag of files keeps it open for the drag (D7).
    override func resignKey() {
        super.resignKey()
        pressWatch?.cancel()
        guard model?.isShown == true, model?.holdsFocus != true else { return }
        let loss = FocusLoss(dragCount: NSPasteboard(name: .drag).changeCount)
        guard !take(step(of: loss)) else { return }
        pressWatch = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: SpotsModel.dragWatchPause)
                guard !Task.isCancelled, let self, self.model?.isShown == true else { return }
                if self.take(self.step(of: loss)) { return }
            }
        }
    }

    /// One look at the press and the drag pasteboard after a loss of the focus.
    private func step(of loss: FocusLoss) -> FocusLoss.Step {
        let drag = NSPasteboard(name: .drag)
        return loss.step(isPressed: NSEvent.pressedMouseButtons != 0, dragCount: drag.changeCount, holdsFiles: !SpotGridDrop.paths(on: drag).isEmpty)
    }

    /// Closes the panel, or keeps it open for a drag. Returns false while the panel still waits.
    private func take(_ step: FocusLoss.Step) -> Bool {
        switch step {
        case .wait: return false
        case .close: hide()
        case .followDrag: model?.prepareForDrag()
        }
        return true
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
        let hosting = NSHostingView(rootView: SpotsWindowView(model: model, place: panel.place))
        hosting.sizingOptions = []
        panel.contentView = hosting
        panel.watchPaste(model: model)
        panel.center()
        panel.followEditing()
        panel.followCover()
        panel.followColumns()
        return panel
    }
}
