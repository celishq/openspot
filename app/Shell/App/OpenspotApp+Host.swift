import AppKit
import OpenspotCore
import SwiftUI

/// The app as the host of the panel's model: its windows, its toasts, its keys, the clipboard, the drag and the springs.
extension OpenspotApp: SpotsHost {
    func dismiss() {
        panel?.hide()
        if NSApp.isActive { previousApp?.activate() }
    }

    func show() {
        if !model.isShown || model.isWarming { showPanel() }
    }

    func notify(_ text: String) {
        toast?.show(text, symbol: ToastPanel.failureSymbol)
    }

    func notify(_ text: String, fix: URL) {
        toast?.show(text, symbol: ToastPanel.failureSymbol, fix: { NSWorkspace.shared.open(fix) }, key: model.files.config.read().fixKey)
    }

    /// Tells the person of a key that macOS refused, with Settings as the fix.
    func notifyKeyFault(_ text: String) {
        toast?.show(text, symbol: ToastPanel.failureSymbol, fix: { [weak self] in self?.openSettings() }, key: model.files.config.read().fixKey)
    }

    func confirm(_ text: String) {
        toast?.show(text, symbol: ToastPanel.confirmSymbol)
    }

    /// Shows the float of a spot at the pointer once its first answer comes, or after the pause of a sheet (W4), or moves
    /// its float there.
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
    }

    func hold(_ keys: [GlobalKey]) {
        wantedKeys = keys
        holdWantedKeys()
    }

    /// Whether a point on the screen lies on a part of Openspot that takes a drop: the cards of the panel, the menu bar
    /// item or a float.
    func takesDrop(at point: NSPoint) -> Bool {
        liesOnPanelDrop(point) || floats.values.contains { $0.isVisible && $0.frame.contains(point) }
    }

    var isPointerOverDrop: Bool {
        liesOnPanelDrop(NSEvent.mouseLocation)
    }

    /// Whether a point on the screen lies on the cards of the panel or on the menu bar item.
    private func liesOnPanelDrop(_ point: NSPoint) -> Bool {
        panel?.showsDrop(at: point) == true || statusItem?.button?.window?.frame.contains(point) == true
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

    func copy(_ file: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([file as NSURL])
    }

    func prepare(_ items: [SpotItem], glyphs: [String]) async {
        if !glyphs.isEmpty { SpotItemIcon.bind(glyphs: glyphs) }
        await SpotIconStore.shared.prepare(items)
    }

    func shippedSpots(folder: PluginFolder, config: ConfigFile, update: UpdateSpot?, offersLogin: Bool) -> [Spot] {
        ShippedSpot.commands(
            folder: folder.url,
            guide: Bundle.main.url(forResource: "GUIDE", withExtension: "md") ?? folder.url,
            app: Bundle.main.executablePath ?? "",
            config: config,
            update: update,
            core: folder.core,
            login: AppLogin.item,
            link: AppCommandLink.item,
            offersLogin: offersLogin,
            quit: QuitSpot { await NSApp.terminate(nil) }
        )
    }

    func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void) {
        var transaction = Transaction(animation: motion.map(SpotMotion.animation))
        transaction.disablesAnimations = motion == nil
        transaction.addAnimationCompletion(criteria: .removed) { MainActor.assumeIsolated { completion() } }
        withTransaction(transaction, body)
    }
}
