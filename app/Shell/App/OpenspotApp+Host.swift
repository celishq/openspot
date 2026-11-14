import AppKit
import LocalAuthentication
import OpenspotCore
import SwiftUI

extension OpenspotApp: SpotsHost {
    func dismiss() {
        panel?.hide()
        if NSApp.isActive { previousApp?.activate() }
    }

    func show() {
        if !model.isShown || model.isWarming { showPanel() }
    }

    func notify(_ text: String) {
        toast?.show(text, kind: .failure)
    }

    func notify(_ text: String, fix: URL) {
        toast?.show(text, kind: .failure, fix: { NSWorkspace.shared.open(fix) }, key: model.config.fixKey)
    }

    func notifyKeyFault(_ text: String) {
        toast?.show(text, kind: .failure, fix: { [weak self] in self?.openSettings() }, key: model.config.fixKey)
    }

    func confirm(_ text: String) {
        toast?.show(text, kind: .confirm)
    }

    func work(_ text: String) {
        toast?.show(text, kind: .work, for: nil)
    }

    func float(_ entry: SpotsModel.Entry, followsDrag: Bool) {
        let pointer = NSEvent.mouseLocation
        if let shown = floats[entry.id] {
            shown.show(at: pointer, isDragging: followsDrag)
            return
        }
        let window = SpotFloatPanel.make(model: model, id: entry.id)
        floats[entry.id] = window
        Task { @MainActor [model] in
            let end = ContinuousClock.now + .seconds(model.runs.opening.answerPause)
            while model.sheets[entry.id]?.kind == .waiting, ContinuousClock.now < end {
                try? await Task.sleep(for: .milliseconds(10))
            }
            guard floats[entry.id] === window else { return }
            window.contentView?.layoutSubtreeIfNeeded()
            window.show(at: pointer, isDragging: followsDrag)
        }
    }

    func land(_ id: String) {
        floats.removeValue(forKey: id)?.orderOut(nil)
        spotWindows.removeValue(forKey: id)?.close()
    }

    func showForDrag() {
        showPanelForDrag(beside: spotWindows.values.first(where: \.isVisible)?.frame)
    }

    func window(_ entry: SpotsModel.Entry) {
        if model.isShown { panel?.hide() }
        let window = spotWindows[entry.id] ?? SpotSheetWindow.make(model: model, entry: entry)
        spotWindows[entry.id] = window
        window.show()
    }

    func hold(_ keys: [GlobalKey]) {
        wantedKeys = keys
        holdWantedKeys()
    }

    func takesDrop(at point: NSPoint) -> Bool {
        liesOnPanelDrop(point) || floats.values.contains { $0.isVisible && $0.frame.contains(point) }
    }

    var isPointerOverDrop: Bool {
        liesOnPanelDrop(NSEvent.mouseLocation)
    }

    var isPointerOverWindow: Bool {
        spotWindows.values.contains { $0.isVisible && $0.frame.contains(NSEvent.mouseLocation) }
    }

    private func liesOnPanelDrop(_ point: NSPoint) -> Bool {
        panel?.showsDrop(at: point) == true || item?.contains(point) == true
    }

    var draggedPaths: [String] {
        SpotGridDrop.paths
    }

    var isMouseDown: Bool {
        NSEvent.pressedMouseButtons & 1 != 0
    }

    var pastedPaths: [String] {
        SpotGridDrop.paths(on: .general)
    }

    func takeFocus() {
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }

    func allows(_ reason: String) async -> Bool {
        if let passed = Self.touchIDPassed, Date().timeIntervalSince(passed) < Self.touchIDReuse { return true }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return true }
        guard (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) == true else { return false }
        Self.touchIDPassed = Date()
        return true
    }

    func copy(_ file: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([file as NSURL])
    }

    func prepare(_ items: [SpotItem], glyphs: [String]) async {
        if !glyphs.isEmpty { SpotItemIcon.bind(glyphs: glyphs) }
        await SpotIconStore.shared.prepare(items)
    }

    func prepareCards(glyphs: [String]) {
        SpotItemIcon.prepare(glyphs: glyphs, size: SpotTokens.glyphSize)
    }

    func agentPrompt(for folder: URL) -> AgentPrompt {
        AgentPrompt(folder: folder, guide: Bundle.main.url(forResource: "GUIDE", withExtension: "md") ?? folder, app: AgentPrompt.command(of: Bundle.main.executablePath ?? ""))
    }

    func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void) {
        var transaction = Transaction(animation: motion.map(SpotMotion.animation))
        transaction.disablesAnimations = motion == nil
        transaction.addAnimationCompletion(criteria: .logicallyComplete) { MainActor.assumeIsolated { completion() } }
        withTransaction(transaction, body)
    }
}
