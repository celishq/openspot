import AppKit
import OpenspotCore
import os

@main
@MainActor
final class OpenspotApp: NSObject, NSApplicationDelegate {
    static func main() {
        #if OPENSPOT_TOOLS
        let launch = LaunchSettings(arguments: Array(CommandLine.arguments.dropFirst()), valued: LaunchSettings.valued.merging(SpotMotionProbe.valued) { $1 }, switches: LaunchSettings.switches.merging(SpotMotionProbe.switches) { $1 })
        #else
        let launch = LaunchSettings(arguments: Array(CommandLine.arguments.dropFirst()))
        #endif
        launch.apply(keepsCallData: true)
        let environment = ProcessInfo.processInfo.environment
        if let call = CommandLineCall(arguments: launch.words, spot: environment[CallWords.spotVariable]) {
            SpotCommandLine.run(call, words: launch.words)
        }
        launch.apply(keepsCallData: false)
        let app = NSApplication.shared
        #if OPENSPOT_TOOLS
        SpotMotionProbe.takeAppearance()
        #endif
        let delegate = OpenspotApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    private static let dragSourceFocusDelay: TimeInterval = 0.2
    static var unlocks = UnlockPass()

    private(set) var item: OpenspotItem?
    private(set) lazy var model = SpotsModel(host: self)
    private(set) var panel: SpotsPanel?
    let frame = NextFrame()
    private(set) var toast: ToastPanel?
    private(set) var previous = PreviousApp<NSRunningApplication>()
    private(set) lazy var keys = GlobalKeys(
        model: model, toggle: { [weak self] in self?.togglePanel() },
        fault: { [weak self] in self?.notifyKeyFault($0) }, fix: { [weak self] in self?.notify($0, fix: $1) }
    )
    private(set) lazy var windows = DetachedWindows(model: model)
    private var menuBar: SpotMenuBar?
    private var fileChooser: SpotFileChooser?
    private var submenu: SpotSubmenuWindow?
    #if OPENSPOT_TOOLS
    private var motionProbe: SpotMotionProbe?
    #endif
    private var update: AppUpdate?
    private var spotsWatch: SpotsWatch?
    private var showListener: NSObjectProtocol?
    private var appearanceWatch: NSKeyValueObservation?
    private var commandSocket: CommandSocket?
    private let mac = SpotMac()
    private var isLaunched = false
    private var showsAtLaunch = false
    private var openedAtLaunch: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        toast = ToastPanel.make()
        let theme = ThemeFolder.standard(environment: model.files.environment, builtIn: mac.mac.theme).read()
        model.take(theme)
        appearanceWatch = NSApp.observe(\.effectiveAppearance, options: [.initial, .new]) { [weak self] app, _ in
            let appearance: Style.Variant = SpotTheme.isDark(app.effectiveAppearance) ? .dark : .light
            MainActor.assumeIsolated { self?.model.runs.take(appearance: appearance) }
        }
        if !theme.faults.isEmpty { notify(theme.faults.joined(separator: "\n")) }
        let item = OpenspotItem(
            model: model, toast: toast?.toast, target: self, action: #selector(pressItem),
            onDragEnter: { [weak self] in self?.showPanelForDrag() }, onDrop: { [weak self] in self?.model.review($0) }
        )
        self.item = item
        toast?.item = item
        toast?.front = { [weak self] in
            guard let self else { return nil }
            let app = NSWorkspace.shared.frontmostApplication
            return ScreenPlace.toastWindow(
                panel: model.isWarming ? nil : panel?.frame,
                isPanelShown: model.isShown,
                isAppInFront: app == .current,
                front: { SpotFrontWindow.frame(of: app) }
            )
        }
        EditMenu.install()
        SpotKeyLayouts.start()
        panel = SpotsPanel.make(model: model)
        menuBar = SpotMenuBar(model: model, openspotItem: item)
        #if OPENSPOT_TOOLS
        if let panel, let probe = SpotMotionProbe(model: model, panel: panel) {
            motionProbe = probe
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { probe.run(show: panel.show) }
        }
        #endif
        let update = AppUpdate { [model] in model.updateIsReady($0) }
        self.update = update
        let api = CommandAPI(mac: mac.mac, places: model.files, raise: { [model] event in
            await MainActor.run { model.runs.raise(event) }
        }, app: SpotRunningApp(model: model, update: update), runs: model.runs)
        model.runs.api = api
        model.runs.cache.listenForMemoryPressure()
        Task { await launch(update: update, api: api) }
    }

    private func launch(update: AppUpdate?, api: CommandAPI) async {
        await model.reload()
        let oldRates = model.files.home.appendingPathComponent("Library/Caches/openspot/calc-rates.json")
        Task.detached(priority: .utility) { try? FileManager.default.removeItem(at: oldRates) }
        let config = ConfigFile.standard().url.deletingLastPathComponent()
        commandSocket = CommandSocket(folder: config, api: api)
        if commandSocket == nil {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "openspot", category: "api")
                .error("Openspot cannot listen for openspot calls for \(config.path, privacy: .public), so spots that ask the app fail.")
        }
        let spots = model.folder.url
        spotsWatch = SpotsWatch(folder: spots, config: model.files.config.url) { [weak self] in
            Task { await self?.model.spotsChanged() }
        }
        try? AgentNote(command: Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/openspot").path).write(in: spots)
        showListener = SpotShowLink.listen { [weak self] id in await self?.model.reveal(id) ?? false }
        let isFirstLaunch = await Self.isFirstLaunch(model.folder, config: model.files.config)
        model.runs.launched()
        panel?.warm { [weak self] in
            guard let self else { return }
            SpotSheetWarmth.draw()
            update?.start()
            if isFirstLaunch {
                Task { await self.model.beginFirstLaunch() }
            } else {
                confirm(model.entryKey.openHint)
            }
        }
        isLaunched = true
        if showsAtLaunch { showPanel() }
        if !openedAtLaunch.isEmpty { model.review(openedAtLaunch) }
        model.runs.listen(to: mac)
    }

    @concurrent
    private nonisolated static func isFirstLaunch(_ folder: SpotsFolder, config: ConfigFile) async -> Bool {
        folder.isFirstLaunch(config: config)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if isLaunched {
            model.review(urls)
        } else {
            openedAtLaunch = urls
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        spotsWatch?.stop()
        commandSocket?.close()
        model.quit()
    }

    @objc private func pressItem() {
        if !model.openAct() { togglePanel() }
    }

    @objc func togglePanel() {
        guard isLaunched else {
            showsAtLaunch.toggle()
            return
        }
        if model.isShown, !model.isWarming {
            panel?.hide()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        guard isLaunched else {
            showsAtLaunch = true
            return
        }
        guard let panel else { return }
        let front = recordFront()
        panel.place(over: front)
        panel.show()
    }

    func openSettings() {
        show()
        model.openSettings()
    }

    @discardableResult
    func recordFront() -> NSRunningApplication? {
        let front = NSWorkspace.shared.frontmostApplication
        previous.show(over: front, own: .current)
        return front
    }

    func present() {
        showPanel()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.dragSourceFocusDelay) { [weak self] in
            guard self?.model.holdsFocus == true else { return }
            self?.panel?.makeKeyAndOrderFront(nil)
            self?.model.isSettlingDrop = false
        }
    }

    func showPanelForDrag() {
        guard !model.isShown || model.isWarming else { return model.followDrag() }
        previous.show(over: nil, own: .current)
        panel?.place(over: nil)
        panel?.showForDrag()
    }

    func showSubmenu(beside row: CGRect, of menu: CGRect) {
        guard let panel, let rows = model.menu?.submenu?.rows.count else { return }
        let window = submenu ?? SpotSubmenuWindow.make(model: model)
        submenu = window
        window.show(rows: rows, beside: row, of: menu, in: panel)
    }

    func hideSubmenu() {
        submenu?.hide()
    }

    func chooseFiles(for spot: Spot, then take: @escaping ([String]) -> Void) {
        guard fileChooser == nil else { return }
        let back = model.isShown && !model.isWarming ? previous.app : NSWorkspace.shared.frontmostApplication
        if model.isShown { panel?.hide() }
        NSApp.activate(ignoringOtherApps: true)
        let chooser = SpotFileChooser(spot: spot)
        fileChooser = chooser
        chooser.show { [weak self] paths in
            self?.fileChooser = nil
            back?.activate()
            take(paths)
        }
    }
}
