import AppKit
import OpenspotCore

@main
@MainActor
final class OpenspotApp: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = OpenspotApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    private var statusItem: NSStatusItem?
    private let model = ShelfModel()
    private var panel: ShelfPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "⌘"
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        statusItem = item
        EditMenu.install()
        panel = ShelfPanel.make(model: model)
        HotKey.registerControlSpace { [weak self] in
            Task { @MainActor in self?.togglePanel() }
        }
    }

    @objc func togglePanel() {
        guard let panel else { return }
        if panel.isVisible && panel.isKeyWindow {
            panel.orderOut(nil)
            return
        }
        Task { await model.reload() }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
}
