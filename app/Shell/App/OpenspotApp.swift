import AppKit
import OpenspotCore
import os

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
    /// The seconds that a passed Touch ID counts for, and when it last passed.
    static let touchIDReuse: TimeInterval = 300
    static var touchIDPassed: Date?

    private(set) var statusItem: NSStatusItem?
    private(set) lazy var model = SpotsModel(host: self)
    private(set) var panel: SpotsPanel?
    private(set) var toast: ToastPanel?
    var previousApp: NSRunningApplication?
    private var hotKey: HotKey.Registration?
    var wantedKeys: [GlobalKey] = []
    private var heldKeys: [GlobalKey: HotKey.Registration] = [:]
    private var keyFaults: [String] = []
    private var trayBar: SpotTrayBar?
    private var configFaults: [String] = []
    private var menuBarDrag: SpotMenuBarDrag?
    private var fileChooser: SpotFileChooser?
    private var motionProbe: SpotMotionProbe?
    private var update: AppUpdate?
    private var folderWatch: SpotsFolderWatch?
    private var showListener: NSObjectProtocol?
    private var commandSocket: CommandSocket?
    private let mac = SpotMac()
    private var isLaunched = false
    private var openedAtLaunch: [URL] = []
    /// The window of each float, by the ID of its spot.
    var floats: [String: SpotFloatPanel] = [:]
    /// The watch of the pointer, while a key holds the shake or a row of Settings records one.
    private var shakeWatch: SpotShakeWatch?
    private var tapWatch: SpotTapWatch?

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
        EditMenu.install()
        SpotKeyLayouts.start()
        panel = SpotsPanel.make(model: model)
        toast = ToastPanel.make()
        trayBar = SpotTrayBar(model: model, openspotItem: item)
        if let panel, let probe = SpotMotionProbe(model: model, panel: panel) {
            motionProbe = probe
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { probe.run(show: panel.show) }
        }
        let update = AppUpdate { [model] in model.updateIsReady($0) }
        self.update = update
        let api = CommandAPI(mac: mac, raise: { [model] event in
            await MainActor.run { model.runs.raise(event) }
        }, app: SpotRunningApp(model: model, update: update), runs: model.runs)
        model.runs.api = api
        let config = ConfigFile.standard().url.deletingLastPathComponent()
        commandSocket = CommandSocket(folder: config, api: api)
        if commandSocket == nil {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "openspot", category: "api")
                .error("Openspot cannot listen for openspot calls for \(config.path, privacy: .public), so spots that ask the app fail.")
        }
        model.reload()
        folderWatch = SpotsFolderWatch(folder: model.files.folder.url, config: model.files.config.url) { [weak self] in self?.model.folderChanged() }
        try? AgentNote(command: Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/openspot").path).write(in: model.files.folder.url)
        showListener = SpotShowLink.listen { [weak self] id in self?.model.reveal(id) ?? false }
        let isFirstLaunch = SpotsFolder.standard().isFirstLaunch(config: .standard())
        panel?.warm { [weak self] in
            guard let self else { return }
            SpotSheetWarmth.draw()
            SpotSoftBlur.warm(SpotsView.blurHeights(of: model))
            update?.start()
            if isFirstLaunch {
                model.beginFirstLaunch()
            } else {
                confirm(model.entryKey.openHint)
            }
        }
        isLaunched = true
        if !openedAtLaunch.isEmpty { model.review(openedAtLaunch) }
        model.runs.listen(to: mac)
    }

    /// Takes what the config file asks for. A key that macOS refuses leaves the current one in use, and the person sees why.
    func applyConfig(_ config: Config) {
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
        if faults != configFaults, !faults.isEmpty { notifyKeyFault(faults.joined(separator: " ")) }
        configFaults = faults
    }

    func setEntryKey(on isOn: Bool) {
        hotKey.map(HotKey.unregister)
        hotKey = isOn ? register(model.entryKey) : nil
        if isOn {
            holdWantedKeys()
        } else {
            heldKeys.values.forEach(HotKey.unregister)
            heldKeys = [:]
        }
        watchShake()
    }

    /// Watches the pointer while a key holds the shake or a row of Settings records, and stops otherwise (W2).
    private func watchShake() {
        let wanted = wantedKeys.contains { $0.trigger == .shake } || model.recording != nil
        if wanted, shakeWatch == nil {
            shakeWatch = SpotShakeWatch { [weak self] in self?.takeShake() }
        } else if !wanted {
            shakeWatch?.stop()
            shakeWatch = nil
        }
    }

    /// Watches the keys for a tap of a lone modifier while a key holds one, and stops otherwise. With no Accessibility the
    /// watch hears nothing, so the person sees the fix once.
    private func watchTap() {
        let wanted = wantedKeys.contains { if case .tap = $0.trigger { true } else { false } }
        if wanted, tapWatch == nil {
            tapWatch = SpotTapWatch { [weak self] modifier in self?.takeTap(modifier) }
            if !AXIsProcessTrusted() {
                notify("Openspot cannot hear a tap of one key. Allow Openspot in Accessibility.", fix: URL(string: SpotClipboard.accessibility)!)
            }
        } else if !wanted {
            tapWatch?.stop()
            tapWatch = nil
        }
    }

    /// Gives a tap of a lone modifier to the key that holds it, unless a row of Settings records, which takes it itself.
    private func takeTap(_ modifier: Shortcut.Modifiers) {
        guard model.recording == nil, let key = wantedKeys.first(where: { $0.trigger == .tap(modifier) }) else { return }
        model.press(key)
    }

    /// Gives a shake to the row of Settings that records, or else to the key that holds it.
    private func takeShake() {
        if model.recording != nil {
            model.recordShake()
        } else if let key = wantedKeys.first(where: { $0.trigger == .shake }) {
            model.press(key)
        }
    }

    /// Holds the keys that the person assigned and lets go of the rest, unless a key is being recorded. A refused key is tried again at
    /// the next scan, and the person sees why once.
    func holdWantedKeys() {
        watchShake()
        watchTap()
        guard model.recording == nil else { return }
        for (key, registration) in heldKeys where !wantedKeys.contains(key) {
            HotKey.unregister(registration)
            heldKeys[key] = nil
        }
        var faults: [String] = []
        for key in wantedKeys where heldKeys[key] == nil {
            guard case .key(let shortcut) = key.trigger else { continue }
            let registration = HotKey.register(shortcut) { [weak self] in
                Task { @MainActor in self?.model.press(key) }
            }
            if let registration {
                heldKeys[key] = registration
            } else {
                faults.append("\(key.spot) cannot use `\(shortcut.label)`, because another app uses it. Choose another key.")
            }
        }
        if faults != keyFaults, !faults.isEmpty { notifyKeyFault(faults.joined(separator: " ")) }
        keyFaults = faults
    }

    private func register(_ key: Shortcut) -> HotKey.Registration? {
        HotKey.register(key) { [weak self] in
            MainActor.assumeIsolated { self?.togglePanel() }
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
        folderWatch?.stop()
        commandSocket?.close()
        model.quit()
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

    func showPanel() {
        guard let panel else { return }
        previousApp = NSWorkspace.shared.frontmostApplication
        panel.place(over: previousApp)
        NSApp.activate(ignoringOtherApps: true)
        panel.show()
    }

    /// Shows the panel on the Settings sheet.
    func openSettings() {
        show()
        model.openSettings()
    }

    /// Brings the panel to the front with the focus, also when a drag opened it or it already shows.
    func present() {
        if let front = NSWorkspace.shared.frontmostApplication, front != .current { previousApp = front }
        panel?.place(over: NSWorkspace.shared.frontmostApplication)
        NSApp.activate(ignoringOtherApps: true)
        panel?.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.dropSettle) { [weak self] in
            guard self?.model.holdsFocus == true else { return }
            NSApp.activate(ignoringOtherApps: true)
            self?.panel?.makeKeyAndOrderFront(nil)
            self?.model.isSettlingDrop = false
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
    func chooseFiles(for spot: Spot, then take: @escaping ([String]) -> Void) {
        guard fileChooser == nil else { return }
        let previous = model.isShown && !model.isWarming ? previousApp : NSWorkspace.shared.frontmostApplication
        if model.isShown { panel?.hide() }
        NSApp.activate(ignoringOtherApps: true)
        let chooser = SpotFileChooser(spot: spot)
        fileChooser = chooser
        chooser.show { [weak self] paths in
            self?.fileChooser = nil
            previous?.activate()
            take(paths)
        }
    }
}
