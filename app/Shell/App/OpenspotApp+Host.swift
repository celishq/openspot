import AppKit
import OpenspotCore
import SwiftUI

/// The app as the host of the panel's model: its windows, its toasts, its keys, the clipboard, the drag and the springs.
extension OpenspotApp: SpotsHost {
    func dismiss() {
        panel?.hide()
        previousApp?.activate()
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

    func hold(_ keys: [GlobalKey]) {
        wantedKeys = keys
        holdWantedKeys()
    }

    var isPointerOverDrop: Bool {
        let point = NSEvent.mouseLocation
        return panel?.showsDrop(at: point) == true || statusItem?.button?.window?.frame.contains(point) == true
    }

    var draggedPaths: [String] {
        SpotCardDrop.paths
    }

    var isMouseDown: Bool {
        NSEvent.pressedMouseButtons != 0
    }

    var pastedPaths: [String] {
        SpotCardDrop.paths(on: .general)
    }

    func copy(_ file: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([file as NSURL])
    }

    func prepare(_ items: [SpotItem]) async {
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
