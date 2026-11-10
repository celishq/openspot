import AppKit
import Carbon.HIToolbox
import ObjectiveC
import OpenspotCore
import SwiftUI

final class SpotsPanel: NSPanel {
    private var model: SpotsModel?
    private let place = SpotsWindowPlace()
    /// The frame that the window had before Edit Spots grew it.
    private var restFrame: NSRect?
    /// How far the window rose when Edit Spots started.
    private var lift: CGFloat = 0
    private var pressWatch: Task<Void, Never>?

    override var canBecomeKey: Bool { true }

    /// Keeps each frame as given. The panel places itself on its screen, and in Edit Spots its clear edge may pass the top
    /// of the screen while its glass stays under it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

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
    func place(over app: NSRunningApplication?) {
        guard model?.isShown != true || model?.isWarming == true else { return }
        let screens = NSScreen.screens.map { ScreenPlace.Screen(frame: $0.frame, area: $0.visibleFrame) }
        let mainHeight = NSScreen.screens.first?.frame.maxY ?? 0
        let window = app.flatMap(Self.frontWindow).map { ScreenPlace.frame(ofBounds: $0, mainHeight: mainHeight) }
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
        let rows = model.placements.map { $0.row + $0.size.rows }.max() ?? 0
        let height = SpotTokens.backdropHeight(rows: rows)
        return NSRect(x: frame.minX, y: frame.maxY - height, width: frame.width, height: height).contains(point)
    }

    /// Grows the window in Edit Spots to hold the dock under the panel, as far below its place along the bottom of the
    /// screen as the two rise, then moves the window up while the dock fades in. When Edit Spots ends, the window moves back
    /// down, and then gets its frame back. A panel that closes keeps its place until it is gone.
    private func followEditing() {
        guard let model else { return }
        let isEditing = withObservationTracking { model.isEditing } onChange: { [weak self] in
            Task { @MainActor in self?.followEditing() }
        }
        if isEditing, restFrame == nil, let area = screen?.visibleFrame {
            let panel = frame
            let dock = ScreenPlace.dock(under: panel, in: area)
            lift = ScreenPlace.lift(of: panel, with: dock, in: area)
            let low = dock.offsetBy(dx: 0, dy: -lift)
            let whole = panel.union(low)
            restFrame = panel
            place.panel = CGPoint(x: panel.minX - whole.minX, y: whole.maxY - panel.maxY)
            place.dock = CGRect(x: low.minX - whole.minX, y: whole.maxY - low.maxY, width: low.width, height: low.height)
            place.isOut = false
            setFrame(whole, display: true)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.model?.isEditing == true else { return }
                self.rise(by: self.lift, showing: true)
            }
        } else if !isEditing, restFrame != nil, model.isShown {
            rise(by: -lift, showing: false) { [weak self] in
                if self?.model?.isEditing == false { self?.restoreFrame() }
            }
        }
    }

    /// Moves the window up this far, and shows or hides the dock, in one motion.
    private func rise(by distance: CGFloat, showing isOut: Bool, then done: @escaping @MainActor () -> Void = {}) {
        withAnimation(SpotMotion.edit) { place.isOut = isOut }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = SpotMotion.editDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().setFrame(frame.offsetBy(dx: 0, dy: distance), display: false)
        } completionHandler: {
            MainActor.assumeIsolated { done() }
        }
    }

    /// Gives the window the frame it had before Edit Spots grew it, with the panel at its top left corner and no dock.
    private func restoreFrame() {
        guard let rest = restFrame else { return }
        restFrame = nil
        lift = 0
        place.isOut = false
        place.dock = nil
        place.panel = .zero
        setFrame(rest, display: true)
    }

    /// Starts the close motion, and takes the panel off the screen when it ends. Then it runs the given work.
    func hide(then done: (() -> Void)? = nil) {
        model?.panelWillHide()
        DispatchQueue.main.asyncAfter(deadline: .now() + SpotMotion.fadeOutDuration) {
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
        return panel
    }
}
