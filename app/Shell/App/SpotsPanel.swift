import AppKit
import ObjectiveC
import OpenspotCore
import SwiftUI

final class SpotsPanel: NSPanel {
    private var model: SpotsModel?
    let place = SpotsWindowPlace()
    private var pressWatch: Task<Void, Never>?
    private var tap = ModifierTap()
    private var swipe = FlowSwipe()
    private var pressStage = 0
    private var isForceDragging = false
    private var screenBackdrop: SpotScreenBackdrop?
    private var restFrame: NSRect?

    override var canBecomeKey: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.isDisjoint(with: [.option, .control]), let key = event.actionKey else { return super.performKeyEquivalent(with: event) }
        if key == ActionKey(name: "v", isCommand: true), model?.isShown == true, model?.pasteSpot() == true { return true }
        if super.performKeyEquivalent(with: event) { return true }
        guard isKeyWindow, firstResponder is NSText, let item = EditMenu.item(of: key), let action = item.action,
              let target = NSApp.target(forAction: action, to: nil, from: item) as? NSResponder,
              (target as? NSUserInterfaceValidations)?.validateUserInterfaceItem(item) ?? true
        else { return false }
        return NSApp.sendAction(action, to: target, from: item)
    }

    func warm(then done: @escaping () -> Void) {
        model?.isWarming = true
        alphaValue = 0
        ignoresMouseEvents = true
        open { orderFrontRegardless() }
        Task { @MainActor [weak self] in
            await self?.model?.waitForShows()
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
        let window = screens.count < 2 ? nil : SpotFrontWindow.frame(of: app)
        let rest = restFrame ?? frame
        guard let origin = ScreenPlace(screens: screens).origin(of: rest.size, window: window, pointer: NSEvent.mouseLocation) else { return }
        guard restFrame != nil else { return setFrameOrigin(origin) }
        restFrame = NSRect(origin: origin, size: rest.size)
        cover()
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
        model?.panelWillShow()
        order()
        if model?.isWarming != true { screenBackdrop?.show(on: screen, below: self) }
    }

    private func takeBackdrop() {
        guard let model else { return }
        if SpotTokens.backdrop.reach == .screen {
            if screenBackdrop == nil { screenBackdrop = SpotScreenBackdrop.make(model: model) }
        } else if let screenBackdrop {
            screenBackdrop.close()
            self.screenBackdrop = nil
        }
    }

    func showsDrop(at point: NSPoint) -> Bool {
        guard let model, model.isShown else { return false }
        let height = model.gridHeight
        return NSRect(x: frame.minX, y: frame.maxY - height, width: frame.width, height: height).contains(point)
    }

    private func resize(to frame: NSRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        setFrame(frame, display: false)
        contentView?.layoutSubtreeIfNeeded()
        displayIfNeeded()
        CATransaction.commit()
    }

    func layOut() {
        let rest = restFrame ?? frame
        let width = SpotTokens.panelWidth
        let next = NSRect(x: rest.midX - width / 2, y: rest.maxY - SpotTokens.panelHeight, width: width, height: SpotTokens.panelHeight)
        if restFrame == nil {
            resize(to: next)
        } else {
            restFrame = next
            cover()
        }
        takeBackdrop()
    }

    func arrange(_ isOn: Bool) {
        if isOn {
            guard restFrame == nil else { return }
            restFrame = frame
            cover()
        } else if let rest = restFrame {
            restFrame = nil
            place.left = 0
            place.top = 0
            place.screen = nil
            resize(to: rest)
        }
    }

    private func cover() {
        guard let rest = restFrame else { return }
        let middle = NSPoint(x: rest.midX, y: rest.midY)
        guard let area = (NSScreen.screens.first { $0.frame.contains(middle) } ?? screen ?? NSScreen.main)?.visibleFrame else { return }
        place.left = rest.minX - area.minX
        place.top = area.maxY - rest.maxY
        place.screen = area.size
        model?.placeShelf(screen: area.size, panelOrigin: CGPoint(x: place.left, y: place.top))
        resize(to: area)
    }

    func hide(then done: (() -> Void)? = nil) {
        model?.panelWillHide()
        DispatchQueue.main.asyncAfter(deadline: .now() + MotionTokens.fadeOut) {
            defer { done?() }
            guard self.model?.isShown == false else { return }
            self.orderOut(nil)
            self.screenBackdrop?.orderOut(nil)
            self.alphaValue = 1
            self.ignoresMouseEvents = false
            self.model?.panelDidHide()
        }
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged: takeFlags(event)
        case .pressure: takePressure(event)
        case .keyDown: if takeKey(event) { return }
        case .keyUp: model?.releaseKey()
        case .scrollWheel: if takeSwipe(event) { return }
        case .rightMouseDown: if takeRightClick(event) { return }
        default: break
        }
        if isForceDragging, takeForceDrag(event) { return }
        super.sendEvent(event)
    }

    private func takeFlags(_ event: NSEvent) {
        model?.hold(event.keyModifiers)
        if let modifier = tap.take(event.keyModifiers, at: event.timestamp), model?.recording != nil {
            model?.recordTap(modifier)
        }
    }

    private func takeKey(_ event: NSEvent) -> Bool {
        tap.spoil()
        guard let model else { return false }
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.control, .option, .command], event.charactersIgnoringModifiers == "m" {
            model.toggleSlowMotion()
            return true
        }
        let key = event.actionKey
        if model.recording != nil {
            if event.isARepeat { return true }
            if let key, model.handleKey(key) { return true }
            model.record(code: UInt32(event.keyCode), modifiers: event.keyModifiers)
            return true
        }
        if let key, textKeeps(key) { return false }
        if let key, model.handleKey(key) { return true }
        return model.takesEveryKey
    }

    private func takeRightClick(_ event: NSEvent) -> Bool {
        guard let model, model.isShown, !model.isEditing, model.openSheetID == nil else { return false }
        openMenu(at: event)
        return true
    }

    private func takeForceDrag(_ event: NSEvent) -> Bool {
        guard let model else { return false }
        switch event.type {
        case .leftMouseDragged:
            model.dragMenu(to: panelPoint(of: event))
        case .leftMouseUp:
            isForceDragging = false
            super.sendEvent(event)
            model.releaseMenu(at: panelPoint(of: event))
            return true
        default: break
        }
        return false
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
        CGPoint(x: event.locationInWindow.x - place.left, y: (contentView?.bounds.height ?? 0) - event.locationInWindow.y - place.top)
    }

    private func takeSwipe(_ event: NSEvent) -> Bool {
        guard NSEvent.isSwipeTrackingFromScrollEventsEnabled, let model, model.openSheetID != nil, event.momentumPhase.isEmpty else { return false }
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

    private static let inputSourceChange = Notification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged")

    private func watchFrontApp(model: SpotsModel) {
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak model] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  let name = app.localizedName else { return }
            MainActor.assumeIsolated {
                guard let model, model.recording != nil else { return }
                model.appCameToFront(name)
            }
        }
    }

    private func watchInputSource(model: SpotsModel) {
        DistributedNotificationCenter.default().addObserver(forName: Self.inputSourceChange, object: nil, queue: .main) { [weak model] _ in
            MainActor.assumeIsolated {
                guard let model, model.recording != nil else { return }
                model.inputSourceChanged()
            }
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
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
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
        panel.watchFrontApp(model: model)
        panel.watchInputSource(model: model)
        panel.center()
        panel.takeBackdrop()
        return panel
    }
}
