import AppKit
import Carbon.HIToolbox
import OpenspotCore

@main
@MainActor
final class OpenspotApp: NSObject, NSApplicationDelegate {
    static func main() {
        if let call = CommandLineCall(arguments: Array(CommandLine.arguments.dropFirst())) {
            SpotCommandLine.run(call)
        }
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
    private var trayBar: SpotTrayBar?
    private var menuBarDrag: SpotMenuBarDrag?
    private var fileChooser: SpotFileChooser?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "⌘"
        item.button?.target = self
        item.button?.action = #selector(pressItem)
        statusItem = item
        menuBarDrag = item.button.map { SpotMenuBarDrag(button: $0) { [weak self] in self?.showPanelForDrag() } }
        model.chooseFiles = { [weak self] in self?.chooseFiles(for: $0, then: $1) }
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
        model.confirm = { toast.show($0, symbol: ToastPanel.confirmSymbol) }
        let trigger = CommandTrigger(model: model, toast: toast)
        self.trigger = trigger
        trayBar = SpotTrayBar(model: model, openspotItem: item)
        model.reload()
        model.arrive(.launch)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        let panelKey = HotKey.register(code: UInt32(kVK_Space), modifiers: UInt32(controlKey)) { [weak self] in
            Task { @MainActor in self?.togglePanel() }
        }
        let triggerKey = HotKey.register(code: UInt32(kVK_Space), modifiers: UInt32(optionKey)) {
            Task { @MainActor in trigger.press() }
        }
        hotKeys = [panelKey, triggerKey].compactMap { $0 }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.quit()
    }

    @objc private func didWake() {
        model.arrive(.wake)
    }

    /// A click on the Openspot item goes to running work, if any shows (G3).
    @objc private func pressItem() {
        if !model.openWork() { togglePanel() }
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

    /// Opens the panel for a drag. The front app stays in front, so that closing the panel activates nothing.
    private func showPanelForDrag() {
        guard !model.isShown else { return model.followDrag() }
        previousApp = nil
        panel?.showForDrag()
    }

    /// Closes the panel and asks the person for files. Afterwards the app that was in front comes back.
    private func chooseFiles(for command: PluginCommand, then take: @escaping ([String]) -> Void) {
        guard fileChooser == nil else { return }
        let previous = model.isShown ? previousApp : NSWorkspace.shared.frontmostApplication
        if model.isShown { panel?.hide() }
        NSApp.activate(ignoringOtherApps: true)
        let chooser = SpotFileChooser(command: command)
        fileChooser = chooser
        chooser.show { [weak self] paths in
            self?.fileChooser = nil
            previous?.activate()
            take(paths)
        }
    }
}
