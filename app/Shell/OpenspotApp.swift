import AppKit
import Carbon.HIToolbox
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
    private var previousApp: NSRunningApplication?
    private var trigger: CommandTrigger?
    private var hotKeys: [HotKey.Registration] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "⌘"
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        statusItem = item
        EditMenu.install()
        panel = SpotsPanel.make(model: model)
        model.dismiss = { [weak self] in
            self?.panel?.hide()
            self?.previousApp?.activate()
        }
        model.show = { [weak self] in
            if self?.model.isShown == false { self?.showPanel() }
        }
        let toast = ToastPanel.make()
        model.notify = { toast.show($0, symbol: ToastPanel.failureSymbol) }
        let trigger = CommandTrigger(model: model, toast: toast)
        self.trigger = trigger
        Task { await model.reload() }
        let panelKey = HotKey.register(code: UInt32(kVK_Space), modifiers: UInt32(controlKey)) { [weak self] in
            Task { @MainActor in self?.togglePanel() }
        }
        let triggerKey = HotKey.register(code: UInt32(kVK_Space), modifiers: UInt32(optionKey)) {
            Task { @MainActor in trigger.press() }
        }
        hotKeys = [panelKey, triggerKey].compactMap { $0 }
    }

    @objc func togglePanel() {
        if model.isShown {
            panel?.hide()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let panel else { return }
        previousApp = NSWorkspace.shared.frontmostApplication
        NSApp.activate(ignoringOtherApps: true)
        panel.show()
    }
}
