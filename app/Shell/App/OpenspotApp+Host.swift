import AppKit
import LocalAuthentication
import OpenspotCore
import SwiftUI

extension OpenspotApp: SpotsHost {
    func dismiss() {
        panel?.hide()
        if NSApp.isActive { previous.app?.activate() }
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

    func applyConfig(_ config: Config) {
        keys.apply(config)
    }

    func setEntryKey(on isOn: Bool) {
        keys.setEntry(on: isOn)
    }

    func hold(_ keys: [GlobalKey]) {
        self.keys.hold(keys)
    }

    func float(_ entry: SpotsModel.Entry, followsDrag: Bool) {
        windows.float(entry, followsDrag: followsDrag)
    }

    func land(_ id: String) {
        windows.land(id)
    }

    func window(_ entry: SpotsModel.Entry) {
        if model.isShown { panel?.hide() }
        recordFront()
        windows.window(entry)
    }

    func takesDrop(at point: NSPoint) -> Bool {
        liesOnPanelDrop(point) || windows.floatTakesDrop(at: point)
    }

    var isPointerOverDrop: Bool {
        liesOnPanelDrop(NSEvent.mouseLocation)
    }

    var isPointerOverWindow: Bool {
        windows.isPointerOverWindow
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
        if Self.unlocks.covers(reason, at: Date()) { return true }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            notify("Openspot cannot guard your account key on this Mac. Set a login password or Touch ID in System Settings, then try again.")
            return false
        }
        guard (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) == true else { return false }
        Self.unlocks.pass(reason, at: Date())
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

    func nextFrame(_ body: @escaping @MainActor () -> Void) {
        frame.run(in: panel?.contentView, body)
    }

    func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void) {
        var transaction = Transaction(animation: motion.map(SpotMotion.animation))
        transaction.disablesAnimations = motion == nil
        transaction.addAnimationCompletion(criteria: .logicallyComplete) { MainActor.assumeIsolated { completion() } }
        withTransaction(transaction, body)
    }
}
