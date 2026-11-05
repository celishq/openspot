import AppKit
import Carbon.HIToolbox
import OpenspotCore

@main
@MainActor
final class OpenspotApp: NSObject, NSApplicationDelegate {
    static func main() {
        if let flag = CommandLine.arguments.firstIndex(of: "--check") {
            runCheck(path: CommandLine.arguments.dropFirst(flag + 1).first)
        }
        let app = NSApplication.shared
        let delegate = OpenspotApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    /// Reports the faults of a plugins folder, or of the standard one, and exits with 1 when there are any.
    private static func runCheck(path: String?) -> Never {
        let folder = path.map { PluginFolder(url: URL(fileURLWithPath: $0, isDirectory: true)) } ?? .standard()
        Task {
            let faults = await PluginCheck(folder: folder).faults()
            faults.forEach { print($0) }
            print(faults.isEmpty ? "No faults in \(folder.url.path)." : "\(faults.count) faults in \(folder.url.path).")
            exit(faults.isEmpty ? 0 : 1)
        }
        dispatchMain()
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
