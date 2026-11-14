import AppKit
import Carbon.HIToolbox
import ObjectiveC
import OpenspotCore
import SwiftUI

final class SpotsPanel: NSPanel {
    private var model: SpotsModel?
    let place = SpotsWindowPlace()
    private var appliedRight: CGFloat = 0
    private var pressWatch: Task<Void, Never>?
    private var tap = ModifierTap()
    private var swipe = FlowSwipe()
    private var pressStage = 0
    private var isForceDragging = false

    override var canBecomeKey: Bool { true }

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

    func place(over app: NSRunningApplication?) {
        guard model?.isShown != true || model?.isWarming == true else { return }
        let screens = ScreenPlace.Screen.all
        let mainHeight = NSScreen.screens.first?.frame.maxY ?? 0
        let window = screens.count < 2 ? nil : app.flatMap(Self.frontWindow).map { ScreenPlace.frame(ofBounds: $0, mainHeight: mainHeight) }
        let center = NSSize(width: frame.width - place.left - appliedRight, height: frame.height)
        guard let origin = ScreenPlace(screens: screens).origin(of: center, window: window, pointer: NSEvent.mouseLocation) else { return }
        setFrameOrigin(NSPoint(x: origin.x - place.left, y: origin.y))
    }

    func place(beside window: NSRect) {
        guard model?.isShown != true || model?.isWarming == true else { return }
        let center = NSSize(width: frame.width - place.left - appliedRight, height: frame.height)
        guard let origin = ScreenPlace(screens: ScreenPlace.Screen.all).origin(of: center, beside: window) else { return }
        setFrameOrigin(NSPoint(x: origin.x - place.left, y: origin.y))
    }

    private static func frontWindow(of app: NSRunningApplication) -> CGRect? {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let front = windows.first {
            ($0[kCGWindowOwnerPID as String] as? pid_t) == app.processIdentifier && ($0[kCGWindowLayer as String] as? Int) == 0
        }
        return (front?[kCGWindowBounds as String] as? NSDictionary).flatMap { CGRect(dictionaryRepresentation: $0) }
    }

    func show() {
        endWarming()
        model?.isOpenForDrag = false
        open { makeKeyAndOrderFront(nil) }
    }

    func showForDrag() {
        endWarming()
        model?.prepareForDrag()
        open { orderFrontRegardless() }
    }

    private func open(ordering order: () -> Void) {
        model?.panelWillShow(holding: Self.modifiers(of: NSEvent.modifierFlags))
        order()
    }

    func showsDrop(at point: NSPoint) -> Bool {
        guard let model, model.isShown else { return false }
        let height = SpotTokens.backdropHeight(gridHeight: SpotGrid.height(of: model.placements))
        return NSRect(x: frame.minX, y: frame.maxY - height, width: frame.width, height: height).contains(point)
    }

    private func followSides() {
        guard let model else { return }
        let panels = withObservationTracking { model.panels } onChange: { [weak self] in
            Task { @MainActor in self?.followSides() }
        }
        let grown = (left: panels.leftExtent - place.left, right: panels.rightExtent - appliedRight)
        guard grown.left != 0 || grown.right != 0 else { return }
        let widened = { (frame: NSRect) in
            NSRect(x: frame.minX - grown.left, y: frame.minY, width: frame.width + grown.left + grown.right, height: frame.height)
        }
        place.left = panels.leftExtent
        appliedRight = panels.rightExtent
        resize(to: widened(frame))
        SpotSoftBlur.warm(SpotsView.blurHeights(of: model), width: panels.frame.width)
        SpotSoftBlur.warm(SpotsView.blurHeights(of: model), width: SpotTokens.panelWidth)
    }

    private func resize(to frame: NSRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        setFrame(frame, display: false)
        contentView?.layoutSubtreeIfNeeded()
        displayIfNeeded()
        CATransaction.commit()
    }

    func hide(then done: (() -> Void)? = nil) {
        model?.panelWillHide()
        DispatchQueue.main.asyncAfter(deadline: .now() + MotionTokens.fadeOut) {
            defer { done?() }
            guard self.model?.isShown == false else { return }
            self.orderOut(nil)
            self.alphaValue = 1
            self.ignoresMouseEvents = false
            self.model?.panelDidHide()
        }
    }

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
        if event.type == .scrollWheel, takeSwipe(event) { return }
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

    private func takePressure(_ event: NSEvent) {
        defer { pressStage = event.stage }
        guard event.stage == 2, pressStage < 2 else { return }
        openMenu(at: event)
        isForceDragging = model?.menu != nil
    }

    private func openMenu(at event: NSEvent) {
        model?.openMenu(at: panelPoint(of: event))
    }

    private func panelPoint(of event: NSEvent) -> CGPoint {
        CGPoint(x: event.locationInWindow.x - place.left, y: (contentView?.bounds.height ?? 0) - event.locationInWindow.y)
    }

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

    private func takeSwipe(_ event: NSEvent) -> Bool {
        guard NSEvent.isSwipeTrackingFromScrollEventsEnabled, let model, model.openList != nil, event.momentumPhase.isEmpty else { return false }
        let phase: FlowSwipe.Phase
        if event.phase.contains(.began) {
            phase = .began
        } else if event.phase.contains(.changed) {
            phase = .changed
        } else if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            phase = .ended
        } else {
            return false
        }
        let dx = Double(event.scrollingDeltaX) * (event.isDirectionInvertedFromDevice ? 1 : -1)
        switch swipe.take(dx: dx, dy: Double(event.scrollingDeltaY), phase: phase) {
        case .back: return model.back()
        case .forward: return model.forward()
        case nil: return false
        }
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

    private func step(of loss: FocusLoss) -> FocusLoss.Step {
        let drag = NSPasteboard(name: .drag)
        return loss.step(isPressed: NSEvent.pressedMouseButtons != 0, dragCount: drag.changeCount, holdsFiles: !SpotGridDrop.paths(on: drag).isEmpty)
    }

    private func take(_ step: FocusLoss.Step) -> Bool {
        switch step {
        case .wait: return false
        case .close: hide()
        case .followDrag: model?.prepareForDrag()
        }
        return true
    }

    private func watchPaste(model: SpotsModel) {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak model] event in
            guard Int(event.keyCode) == kVK_ANSI_V, Self.modifiers(of: event.modifierFlags) == .command else { return event }
            let isTaken = MainActor.assumeIsolated { model?.isShown == true && model?.pasteSpot() == true }
            return isTaken ? nil : event
        }
    }

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
        panel.followSides()
        return panel
    }
}
