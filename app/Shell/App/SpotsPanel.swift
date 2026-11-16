import AppKit
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
        model?.panelWillShow()
        order()
    }

    func showsDrop(at point: NSPoint) -> Bool {
        guard let model, model.isShown else { return false }
        let height = SpotTokens.contentHeight(gridHeight: SpotGrid.height(of: model.placements))
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
        switch event.type {
        case .flagsChanged: takeFlags(event)
        case .pressure: takePressure(event)
        case .keyDown: if takeKey(event) { return }
        case .scrollWheel: if takeSwipe(event) { return }
        case .rightMouseDown: if takeRightClick(event) { return }
        default: break
        }
        if isForceDragging, takeForceDrag(event) { return }
        super.sendEvent(event)
    }

    private func takeFlags(_ event: NSEvent) {
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
            if let key, model.handleKey(key) { return true }
            model.record(code: UInt32(event.keyCode), modifiers: event.keyModifiers)
            return true
        }
        guard let key, !textKeeps(key) else { return false }
        return model.handleKey(key)
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
        CGPoint(x: event.locationInWindow.x - place.left, y: (contentView?.bounds.height ?? 0) - event.locationInWindow.y)
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

    private func watchPaste(model: SpotsModel) {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak model] event in
            let isTaken = MainActor.assumeIsolated {
                event.keyModifiers == .command && event.actionKey?.name == "v" && model?.isShown == true && model?.pasteSpot() == true
            }
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
