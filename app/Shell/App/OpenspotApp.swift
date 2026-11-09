import AppKit
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

    /// The seconds after a drop until the app that the drag came from has let go of the focus.
    private static let dropSettle = 0.2

    private var statusItem: NSStatusItem?
    private let model = SpotsModel()
    private var panel: SpotsPanel?
    private var previousApp: NSRunningApplication?
    private var hotKey: HotKey.Registration?
    private var wantedKeys: [GlobalKey] = []
    private var heldKeys: [GlobalKey: HotKey.Registration] = [:]
    private var keyFaults: [String] = []
    private var trayBar: SpotTrayBar?
    private var configFaults: [String] = []
    private var menuBarDrag: SpotMenuBarDrag?
    private var fileChooser: SpotFileChooser?
    private var motionProbe: SpotMotionProbe?
    private var update: AppUpdate?
    private var isLaunched = false
    private var openedAtLaunch: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        #if DEBUG
        item.button?.image = NSImage(named: "TrayMarkNightly")
        #else
        item.button?.image = NSImage(named: "TrayMark")
        #endif
        item.button?.setAccessibilityLabel("Openspot")
        item.button?.target = self
        item.button?.action = #selector(pressItem)
        statusItem = item
        menuBarDrag = item.button.map { button in
            SpotMenuBarDrag(button: button, onEnter: { [weak self] in self?.showPanelForDrag() }, onDrop: { [weak self] in self?.model.review($0) })
        }
        model.chooseFiles = { [weak self] in self?.chooseFiles(for: $0, then: $1) }
        EditMenu.install()
        SpotKeyLayouts.start()
        panel = SpotsPanel.make(model: model)
        model.dismiss = { [weak self] in
            self?.panel?.hide()
            self?.previousApp?.activate()
        }
        model.show = { [weak self] in
            if self?.model.isShown == false || self?.model.isWarming == true { self?.showPanel() }
        }
        let toast = ToastPanel.make()
        model.notify = { toast.show($0, symbol: ToastPanel.failureSymbol) }
        model.notifyFix = { text, fix in
            toast.show(text, symbol: ToastPanel.failureSymbol, fix: { NSWorkspace.shared.open(fix) }, key: ConfigFile.standard().read().fixKey)
        }
        model.notifyKeyFault = { [weak self] text in
            toast.show(text, symbol: ToastPanel.failureSymbol, fix: { self?.openSettings() }, key: ConfigFile.standard().read().fixKey)
        }
        model.confirm = { toast.show($0, symbol: ToastPanel.confirmSymbol) }
        trayBar = SpotTrayBar(model: model, openspotItem: item)
        if let panel, let probe = SpotMotionProbe(model: model, panel: panel) {
            motionProbe = probe
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { probe.run(show: panel.show) }
        }
        let update = AppUpdate(runningWork: { [model] in model.workCount }, onReady: { [model] in model.updateIsReady() })
        self.update = update
        model.updateSpot = update?.spot
        model.applyConfig = { [weak self] in self?.applyConfig() }
        model.setEntryKeyOn = { [weak self] in self?.setEntryKey(on: $0) }
        model.holdKeys = { [weak self] in
            self?.wantedKeys = $0
            self?.holdWantedKeys()
        }
        model.present = { [weak self] in self?.presentPanel() }
        model.pointerIsOverDrop = { [weak self, weak item] in
            let point = NSEvent.mouseLocation
            return self?.panel?.showsDrop(at: point) == true || item?.button?.window?.frame.contains(point) == true
        }
        model.reload()
        model.arrive(.launch)
        let isFirstLaunch = PluginFolder.standard().isFirstLaunch(config: .standard())
        panel?.warm { [model] in
            if isFirstLaunch {
                model.beginFirstLaunch()
            } else {
                model.confirm(model.entryKey.openHint)
            }
        }
        isLaunched = true
        if !openedAtLaunch.isEmpty { model.review(openedAtLaunch) }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
    }

    /// Takes what the config file asks for. A key that macOS refuses leaves the current one in use, and the person sees why.
    private func applyConfig() {
        let config = ConfigFile.standard().read()
        var faults = config.faults
        let key = config.panelKey ?? model.entryKey
        if hotKey == nil || key != model.entryKey {
            if let registration = register(key) {
                hotKey.map(HotKey.unregister)
                hotKey = registration
                model.entryKey = key
            } else {
                faults.append("Openspot cannot use `\(key.label)` to open, because another app uses it. Choose another key.")
            }
        }
        if faults != configFaults, !faults.isEmpty { model.notifyKeyFault(faults.joined(separator: " ")) }
        configFaults = faults
    }

    private func setEntryKey(on isOn: Bool) {
        hotKey.map(HotKey.unregister)
        hotKey = isOn ? register(model.entryKey) : nil
        if isOn {
            holdWantedKeys()
        } else {
            heldKeys.values.forEach(HotKey.unregister)
            heldKeys = [:]
        }
    }

    /// Holds the keys that the person assigned and lets go of the rest, unless a key is being recorded. A refused key is tried again at
    /// the next scan, and the person sees why once.
    private func holdWantedKeys() {
        guard model.recording == nil else { return }
        for (key, registration) in heldKeys where !wantedKeys.contains(key) {
            HotKey.unregister(registration)
            heldKeys[key] = nil
        }
        var faults: [String] = []
        for key in wantedKeys where heldKeys[key] == nil {
            let registration = HotKey.register(key.shortcut) { [weak self] in
                Task { @MainActor in self?.model.press(key) }
            }
            if let registration {
                heldKeys[key] = registration
            } else {
                faults.append("\(key.spot) cannot use `\(key.shortcut.label)`, because another app uses it. Choose another key.")
            }
        }
        if faults != keyFaults, !faults.isEmpty { model.notifyKeyFault(faults.joined(separator: " ")) }
        keyFaults = faults
    }

    private func register(_ key: Shortcut) -> HotKey.Registration? {
        HotKey.register(key) { [weak self] in
            Task { @MainActor in self?.togglePanel() }
        }
    }

    /// A person opened `.spot` files, such as by a double-click. macOS can ask this before the app has finished its launch.
    func application(_ application: NSApplication, open urls: [URL]) {
        if isLaunched {
            model.review(urls)
        } else {
            openedAtLaunch = urls
        }
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
        if model.isShown, !model.isWarming {
            panel?.hide()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let panel else { return }
        previousApp = NSWorkspace.shared.frontmostApplication
        panel.place(over: previousApp)
        NSApp.activate(ignoringOtherApps: true)
        panel.show()
    }

    /// Shows the panel on the Settings sheet.
    private func openSettings() {
        if !model.isShown || model.isWarming { showPanel() }
        model.openSettings()
    }

    /// Brings the panel to the front with the focus, also when a drag opened it or it already shows.
    private func presentPanel() {
        if let front = NSWorkspace.shared.frontmostApplication, front != .current { previousApp = front }
        panel?.place(over: NSWorkspace.shared.frontmostApplication)
        NSApp.activate(ignoringOtherApps: true)
        panel?.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.dropSettle) { [weak self] in
            guard self?.model.holdsFocus == true else { return }
            NSApp.activate(ignoringOtherApps: true)
            self?.panel?.makeKeyAndOrderFront(nil)
        }
    }

    /// Opens the panel for a drag. The front app stays in front, so that closing the panel activates nothing.
    private func showPanelForDrag() {
        guard !model.isShown || model.isWarming else { return model.followDrag() }
        previousApp = nil
        panel?.place(over: nil)
        panel?.showForDrag()
    }

    /// Closes the panel and asks the person for files. Afterwards the app that was in front comes back.
    private func chooseFiles(for command: Spot, then take: @escaping ([String]) -> Void) {
        guard fileChooser == nil else { return }
        let previous = model.isShown && !model.isWarming ? previousApp : NSWorkspace.shared.frontmostApplication
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
