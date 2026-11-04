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
    private let model = SpotsModel()
    private var panel: SpotsPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "⌘"
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        statusItem = item
        EditMenu.install()
        panel = SpotsPanel.make(model: model)
        HotKey.registerControlSpace { [weak self] in
            Task { @MainActor in self?.togglePanel() }
        }
    }

    @objc func togglePanel() {
        guard let panel else { return }
        if model.isShown {
            panel.hide()
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.show()
    }
}
