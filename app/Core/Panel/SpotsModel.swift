import Foundation
import Observation

@MainActor
@Observable
public final class SpotsModel {
    /// A form open in a sheet, with the action that asked for it. Its text stays when the panel closes.
    public struct FormSession {
        /// Which form this is, so that a call that ends after the person moved on changes only its own form.
        public let id = UUID()
        public var draft: FormDraft
        public let entry: Entry
        public let action: CommandAction
        public let item: SpotItem?
        public let openedSheet: Bool
    }

    public typealias Target = (entry: Entry, item: SpotItem?)

    static let searchLimit = 8
    public static let dragWatchPause: Duration = .milliseconds(16)
    static let chainPause: Duration = .milliseconds(200)
    private static let loadLimit: Duration = .seconds(2)
    private static let loadPause: Duration = .milliseconds(20)
    public static let dropPause: Duration = .milliseconds(300)

    /// The sheet that grows out of the search field in place of a card, such as the install screen, while it is loaded.
    public private(set) var fieldSheet: String?
    public var entries: [Entry] = [] {
        didSet {
            spotListIsStale = true
            askAnswers()
            updateVisible()
        }
    }
    public var query = "" {
        didSet {
            guard query != oldValue else { return }
            selected = 0
            askAnswers()
            updateVisible()
        }
    }
    /// The cards that show, in their order. Each change of a card or of the search sets it again, and an equal list tells no
    /// view.
    public internal(set) var visible: [Entry] = []
    /// The sizes that `placements` were laid out from.
    @ObservationIgnored var laidOutSizes: [SpotSize] = []
    @ObservationIgnored var laidOutGrid = SpotGrid()
    /// The cards as the items that the main search finds. It folds them again only when they change.
    @ObservationIgnored var spotList = ItemList()
    /// Whether a card changed since `spotList` was built: its entry, or the state or the command that its run reports.
    @ObservationIgnored var spotListIsStale = true
    /// The number of times that the cards were made into the items of `spotList`.
    @ObservationIgnored var spotListBuilds = 0
    /// The number of times that the search found the cards that show.
    @ObservationIgnored var visibleUpdates = 0
    /// Which `answers` patterns match the text of the main search.
    var answerMatches: AnswerMatches {
        runs.answerMatches
    }
    /// The search of the cards and the lists that offer their rows, which keeps the matches of the last text.
    @ObservationIgnored var mainSearch = MainSearch()
    /// Where each visible spot lies on the grid, in the order of `visible`.
    public internal(set) var placements: [SpotPlacement] = [] {
        didSet {
            let height = SpotTokens.backdropHeight(gridHeight: SpotGrid.height(of: placements))
            if height != gridHeight { gridHeight = height }
        }
    }
    /// The height of the backdrop of the grid's cards, which changes only when the placements change it.
    public private(set) var gridHeight = SpotTokens.backdropHeight(gridHeight: 0)
    public var selected = 0
    /// The sheet that shows: the transition's sheet, from its first frame on its card until its close starts. It follows the
    /// open run: a run's first answer shows its sheet, and a close or a hidden panel takes it away. It changes only with the
    /// sheet, not with each phase of its motion.
    public private(set) var openList: String?
    /// Where the open sheet is in its motion between its card and its open place.
    public internal(set) var transition = SheetTransition() {
        didSet {
            let shown = transition.shown
            if shown != openList {
                openList = shown
                if shown != nil, followsHint { takeSheetHint(HintWords(hint)) }
            }
            let opening = transition.phase == .opening ? transition.id : nil
            if opening != (oldValue.phase == .opening ? oldValue.id : nil) { runs.opening.moving = opening }
        }
    }
    @ObservationIgnored public var closingPick: (item: SpotItem, entry: Entry)?
    public let runs: SpotRuns
    @ObservationIgnored public var dragWatch: Task<Void, Never>?
    public var dragPaths: [String] = []
    public var draggedSpot: SpotDrop? {
        didSet { followSpotDrop(from: isPointerOverDrop ? oldValue : nil) }
    }
    public var isPointerOverDrop = false {
        didSet { followSpotDrop(from: oldValue ? draggedSpot : nil) }
    }
    /// The file whose words the field shows in place of its search: a dragged `.spot` file, or the file of a review while its
    /// sheet grows out of the field or collapses back into it. It stays while its words fade out.
    public var fieldDrop: SpotDrop?
    /// Whether the field shows the words of `fieldDrop`.
    public var showsFieldDrop = false
    /// The shared spot that the open review shows, which exists only as long as that sheet.
    public var reviewed: ReviewSpot?
    public var isFirstLaunch = false
    public var isShown = false
    /// Whether the app is opening the panel unseen as it starts, which a press of the key ends.
    public var isWarming = false
    /// Whether a drag holds the panel open: one over the menu bar item, or one that a press in another app started (D7). The
    /// panel is not key then, and its field takes no focus.
    public var isOpenForDrag = false
    /// Whether a drop just opened a sheet, which holds the focus while the app that the drag came from lets go of it (D8).
    public var isSettlingDrop = false
    /// Whether Touch ID or the Mac password is being asked for.
    public var isAsking = false

    public var entryKey = Shortcut.standard
    var isChainHeld = false
    @ObservationIgnored var chainWatch: Task<Void, Never>?
    public var recording: String?
    @ObservationIgnored private var problems: [String] = []
    /// The actions menu from its open to the end of its close.
    public internal(set) var menuSession: ActionMenuSession? {
        didSet {
            let isOpen = menuSession != nil && menuSession?.phase != .closing
            if isOpen != isMenuOpen { isMenuOpen = isOpen }
            guard menuSession == nil else { return }
            if menuFrame != nil { menuFrame = nil }
            if menuBackdropHeight != 0 { change(.sheet(isOpen: false), { menuBackdropHeight = 0 }) }
        }
    }
    /// Whether the actions menu is open and not closing. A search or a move in the menu tells no reader of it.
    public private(set) var isMenuOpen = false
    /// Where the menu lies, once its view has placed it, until its close ends. A search or a move in the menu tells no
    /// reader of it.
    public internal(set) var menuFrame: ActionMenuFrame?
    /// How tall the backdrop under the menu is, from the panel's top: 0 with no menu. It grows on the open motion of the menu
    /// and shrinks when the menu is gone, and a later place of the menu moves it with no motion.
    public internal(set) var menuBackdropHeight: CGFloat = 0
    /// The words of the hint under the grid and of the hint under a sheet, each kept from `hint` while it is followed. Each
    /// keeps the words it last showed, and changes only when its words do.
    public internal(set) var gridHint = HintWords("")
    public internal(set) var sheetHint = HintWords("")
    /// Whether the hint under the grid last showed the keys of Edit Spots, so that its next words fade in as well.
    @ObservationIgnored var hintIsForEdit = false
    @ObservationIgnored var followsHint = false
    /// The number of times that the followed hint was read again after a change of what it reads.
    @ObservationIgnored var hintTakes = 0
    public var form: FormSession? {
        didSet {
            let rect = form.map { SpotTokens.formRect($0.draft.form) }
            if rect != formRect { formRect = rect }
            let hasChoices = form?.draft.choices != nil
            if hasChoices != formHasChoices { formHasChoices = hasChoices }
            let isMultiple = form?.draft.isMultiple == true
            if isMultiple != formIsMultiple { formIsMultiple = isMultiple }
        }
    }
    /// Where the open form lies, whether it is a form of one choice whose options the field searches, and whether that
    /// choice takes many options. A key in the form tells no reader of them.
    public private(set) var formRect: CGRect?
    public private(set) var formHasChoices = false
    public private(set) var formIsMultiple = false
    /// The ask for a form that waits for its script. A newer ask, a cancel, a close or a hidden panel replaces it.
    @ObservationIgnored var formAsk: UUID?
    /// Whether the grid is in Edit Spots, where it also shows the spots that are off the grid, and a press only selects.
    public var isEditing = false
    /// The tip of the corner control that the pointer lies over in Edit Spots.
    public var tip: SpotTip?
    /// The card that the person drags in Edit Spots, and where a release puts it.
    public internal(set) var drag: SpotDrag?
    public let lift = SpotLift()
    /// The card that a release or a cancel of a drag puts in place, until its motion ends.
    public internal(set) var landing: String?
    /// The card that the window draws over the panel and the dock while the person carries it, until it lands.
    public internal(set) var carry: SpotCarry?
    /// Where the dock lies in the panel's space while Edit Spots shows it, and how far it has scrolled.
    @ObservationIgnored public var dockFrame: CGRect?
    @ObservationIgnored public internal(set) var dockScroll: CGFloat = 0
    /// The layouts of the grid for each place that a carried spot of the dock can take. Its card is on the grid while the
    /// drag holds it there.
    @ObservationIgnored var arrival: SpotDrag?
    /// The card that the person resizes by its corner in Edit Spots, and the size that a release keeps.
    public internal(set) var resize: SpotResize?
    /// How long the pointer stays near a new place before the other cards make room there.
    @ObservationIgnored public var dragRest: Duration = .milliseconds(100)
    /// The place that the cards make room at when the pointer has rested near it for `dragRest`.
    @ObservationIgnored var dragTarget: SpotDrag.Target?
    @ObservationIgnored var dragWait: Task<Void, Never>?
    /// How far the grid has scrolled, how far it had when the pointer pressed a card to drag or resize it, and the
    /// pointer's last move since, so that a scroll with no move of the pointer moves the card with the grid.
    @ObservationIgnored public internal(set) var gridScroll: CGFloat = 0
    @ObservationIgnored var scrollAtPress: CGFloat = 0
    @ObservationIgnored var pointerMove: CGSize?
    /// The spots of Edit Spots' store.
    public internal(set) var dock = SpotDock(items: [])
    /// The listing of the spot that the store opened.
    public internal(set) var dockListing: SpotListing?
    /// The spots that are off, and the packages of the spots of the spots folder, as the last read of the folder found them.
    @ObservationIgnored var dockOff: [SpotDock.Item] = []
    @ObservationIgnored var dockPublications: [String: SpotDock.Publication] = [:]
    /// The stamp of the folder that `dockOff` and `dockPublications` were read from, and the read that runs in the background.
    /// A publish changes no stamp, so it reads the store again itself.
    @ObservationIgnored var dockStamp: SpotsFolder.Stamp?
    @ObservationIgnored var dockRead: Task<Void, Never>?
    /// Whether the person types in the dock's search, which then takes each key but Esc.
    public internal(set) var isSearchingDock = false
    /// Where the person pressed a card's resize handle, in the handle's square.
    @ObservationIgnored var resizeGrip = CGPoint(x: SpotTokens.resizeHandle, y: SpotTokens.resizeHandle)
    public var arrangement = SpotArrangement()
    /// The choices of the config that ships with the app, which count where the person's config makes none.
    @ObservationIgnored public private(set) var defaultArrangement = SpotArrangement()
    /// The symbol of the command whose key a person pressed last, which the Openspot item shows for `flashPause`.
    public internal(set) var flashSymbol: String?
    @ObservationIgnored public var flashPause: Duration = .milliseconds(1500)
    @ObservationIgnored var flashWatch: Task<Void, Never>?
    @ObservationIgnored private var scanned: [Spot] = []
    @ObservationIgnored private var spotScan = SpotScan()
    @ObservationIgnored private var lastScan = ScanResult(files: [], refused: [])
    /// The config that the app read last, and the spots folder that it turns on, which `config` and `folder` give.
    @ObservationIgnored private var lastRead: (config: Config, folder: SpotsFolder)?
    /// The stamp of the folder and the config that the cards were last built from.
    @ObservationIgnored private var loadedStamp: SpotsFolder.Stamp?
    @ObservationIgnored private var loadedConfig: Config?
    /// How many times the grid built all its cards again, which a change of the config through the API does not do (A25).
    @ObservationIgnored private(set) var gridBuilds = 0
    /// The files of the last spot that Delete moved to the Trash, which `⌘Z` puts back.
    @ObservationIgnored var removal: Removal?
    /// The stamp of each script file at the last scan, which says which scripts a change of the folder touched.
    @ObservationIgnored private var fileStamps: [String: String] = [:]

    /// The app around the panel, which shows it, tells the person and moves each change.
    @ObservationIgnored public unowned let host: SpotsHost
    /// Where the spots, the config and the recent rows live.
    @ObservationIgnored public let files: AppPlaces
    /// The global keys that the person gave and that a spot still offers, as the app holds them.
    @ObservationIgnored private(set) var assignedKeys: [GlobalKey] = []

    public init(host: SpotsHost, files: AppPlaces = .standard, runs: SpotRuns? = nil) {
        self.host = host
        self.files = files
        defaultArrangement = files.defaultArrangement
        self.runs = runs ?? SpotRuns(
            recent: { files.recent(of: $0) },
            prepare: { [unowned host] in await host.prepare($0, glyphs: $1) },
            log: files.log,
            stats: files.stats
        )
        self.runs.onReport = { [weak self] id, report in self?.take(report, of: id) }
        self.runs.partsArrival = { [weak self] id, bring in
            guard let self else { return bring() }
            bringParts(of: id, bring)
        }
    }

    /// The config as the last reload or change through the API read it, so that a press reads no disk.
    public var config: Config {
        lastRead?.config ?? files.config.read()
    }

    /// The spots folder with the core spots that `config` turns on.
    public var folder: SpotsFolder {
        lastRead?.folder ?? files.folder
    }

    public var sheets: [String: SpotRun] {
        runs.sheets
    }

    /// What a script last gave a widget to draw. A view that calls it hears only of that script's reading.
    public func reading(of id: String) -> MetricReading? {
        runs.sheets[id]?.reading
    }

    /// The number of calls that a restart would stop.
    public var workCount: Int {
        runs.work.count
    }

    /// Opens the panel on the grid, once, for a person who has no spots yet. The toast with the key waits for the panel to
    /// close.
    public func beginFirstLaunch() {
        isFirstLaunch = true
        try? files.config.begin(enabling: folder.startingSpots())
        reload()
        host.present()
    }

    /// Reads the config file again, and the spots folder when a file that its scan reads has changed. No script runs for
    /// this, and each card shows its header until its answer arrives. A file that gives no spot shows a card of its faults,
    /// and any other fault shows in a toast. With no file changed and the same config as the last time, it only holds the
    /// keys again.
    public func reload() {
        reload(patching: nil)
    }

    /// Reloads as `reload` does. With `ids`, only the cards of those spots change, and each other card stays as it is.
    private func reload(patching ids: Set<String>?) {
        let config = files.config.read()
        host.applyConfig(config)
        let folder = files.folder(config)
        lastRead = (config, folder)
        var scan = spotScan.look(at: folder, hosted: reviewed.map { [$0.spot] } ?? [])
        let faults = folder.faultSpots(of: scan, prompt: host.agentPrompt(for: folder.url))
        if !faults.isEmpty { scan.files.append(SpotFile(id: FaultSpot.fileID, spots: faults)) }
        guard spotScan.stamp != loadedStamp || config != loadedConfig else { return holdAssignedKeys(config) }
        scan.listKeys(in: files.config)
        let carded = Set(faults.map(\.id))
        let problems = scan.refused.filter { !carded.contains($0.file) }.map { "\($0.file) was not loaded: \($0.reason)" }
        runs.isCareful = config.isCareful
        runs.take(scan, menuBar: config.arrangement.menuBar)
        lastScan = scan
        loadedStamp = spotScan.stamp
        loadedConfig = config
        let stamps = Self.stamps(of: scan)
        let others = ids.map { ids in { (stamps: [String: String]) in stamps.filter { !ids.contains($0.key) } } }
        let isOnlyNamed = others.map { $0(stamps) == $0(fileStamps) } ?? false
        fileStamps = stamps
        holdAssignedKeys(config)
        arrangement = config.arrangement
        scanned = scan.spots
        if let ids, isOnlyNamed { patchEntries(ids) } else { rebuildEntries() }
        if isEditing { refreshDock(in: folder) } else { readDockLater(in: folder) }
        if problems != self.problems, !problems.isEmpty {
            host.notify(problems.joined(separator: " "))
        }
        self.problems = problems
    }

    /// Takes a change of the spots folder or the config file, such as an agent that writes a spot: the cards change at once,
    /// with no motion, the selected card stays selected, and a changed script that the open panel reads at `panel` reads again.
    public func folderChanged() {
        let stamps = fileStamps
        let id = selectedEntry?.id
        reload()
        if let position = visible.firstIndex(where: { $0.id == id }) { selected = position }
        guard isShown else { return }
        for entry in entries where entry.spot.read?.has(.panel) == true && fileStamps[entry.id] != stamps[entry.id] {
            sheets[entry.id]?.read(need: .change)
        }
    }

    /// The stamp of each script file of the last scan: its date of change and its file number, which a rewrite changes.
    private static func stamps(of scan: ScanResult) -> [String: String] {
        var stamps: [String: String] = [:]
        for script in scan.scripts where script.host == nil {
            guard let values = try? FileManager.default.attributesOfItem(atPath: script.url.path) else { continue }
            let date = (values[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            stamps[script.id] = "\(date) \(values[.systemFileNumber] ?? "")"
        }
        return stamps
    }

    /// Opens the panel with the card of a spot selected, as `openspot spot show` asks. A spot that the grid does not show is
    /// found by a search for its name. Returns false when no card has that ID.
    public func reveal(_ id: String) -> Bool {
        reload()
        guard let entry = cards.first(where: { $0.id == id }) else { return false }
        closeMenu()
        form = nil
        endEditing(moving: false)
        if openList != nil { closeList(moving: false) }
        host.show()
        query = visible.contains { $0.id == id } || cards.filter(\.isOnGrid).contains { $0.id == id } ? "" : entry.state.title
        selected = visible.firstIndex { $0.id == id } ?? 0
        return true
    }

    /// Takes a change that the API wrote to the config, and applies only what changed (A25): a key holds the keys again, a
    /// spot that turns on or off or goes into the menu bar changes its own card under a sheet that shows, and a value reads
    /// its spot again when something wants it and another caller set it.
    public func configChanged(_ change: ConfigChange) {
        let config = files.config.read()
        let arrangement = lastRead?.config.arrangement
        let isSameFolder = arrangement?.enabled == config.arrangement.enabled && arrangement?.disabled == config.arrangement.disabled
        lastRead = (config, lastRead.flatMap { isSameFolder ? $0.folder : nil } ?? files.folder(config))
        switch change {
        case .keys:
            host.applyConfig(config)
            holdAssignedKeys(config)
            if let loaded = loadedConfig, loaded.arrangement == config.arrangement, loaded.settings == config.settings { loadedConfig = config }
        case .spots(let ids):
            let id = selectedEntry?.id
            reload(patching: Set(ids))
            if let position = visible.firstIndex(where: { $0.id == id }) { selected = position }
        case .careful:
            runs.isCareful = config.isCareful
            if let loaded = loadedConfig, loaded.arrangement == config.arrangement, loaded.keys == config.keys, loaded.settings == config.settings { loadedConfig = config }
        case .value(let spot, let caller):
            if let loaded = loadedConfig, loaded.arrangement == config.arrangement, loaded.keys == config.keys, loaded.panelKey == config.panelKey, loaded.fixKey == config.fixKey {
                loadedConfig = config
            }
            if caller != spot, let sheet = sheets[spot], sheet.isWanted { sheet.read(need: .change) }
        }
        if case .spots = change { return }
        runs.readOfferedRows()
    }

    /// Takes the config that the app itself just wrote as the one the cards come from, so that the watch's report of the
    /// write reloads nothing.
    func tookOwnWrite() {
        let config = files.config.read()
        loadedConfig = config
        lastRead = (config, lastRead?.folder ?? files.folder(config))
    }

    /// Builds the card of each spot that these IDs name again, by its ID or its core ID, and keeps each other card (A25).
    private func patchEntries(_ ids: Set<String>) {
        let named: (Spot) -> Bool = { ids.contains($0.id) || ids.contains(SpotsFolder.coreID(of: $0)) }
        let letters = arrangement.letters(over: defaultArrangement)
        var next = entries.filter { !named($0.spot) }
        for (index, spot) in ordered().enumerated() where named(spot) {
            next.insert(Entry(spot: spot, run: runs.sheets[spot.id], choice: arrangement, defaults: defaultArrangement, letter: letters[spot.id]), at: min(index, next.count))
        }
        if next != entries { entries = next }
    }

    public func rebuildEntries() {
        gridBuilds += 1
        let letters = arrangement.letters(over: defaultArrangement)
        let next = ordered().map { Entry(spot: $0, run: runs.sheets[$0.id], choice: arrangement, defaults: defaultArrangement, letter: letters[$0.id]) }
        let field = next.first { $0.spot.growsFromField }?.id
        if field != fieldSheet { fieldSheet = field }
        entries = next
    }

    /// The scanned spots in their grid order, the order of the default config over it, and the person's order over both.
    private func ordered() -> [Spot] {
        let sorted = scanned.enumerated().sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }.map(\.element)
        return arrangement.ordered(defaultArrangement.ordered(sorted))
    }

    /// The panel starts to show: a pick that its fade left finishes, the first card is selected, the held keys count, and
    /// each script that the panel shows reads. It reads no disk: the watch of the folder and the config reloads them. The
    /// panel says it shows on the next turn, so that its fade starts from hidden.
    public func panelWillShow(holding modifiers: Shortcut.Modifiers) {
        finishPick()
        selected = 0
        takeHeld(modifiers)
        runs.panelOpened()
        askAnswers()
        DispatchQueue.main.async { [weak self] in self?.isShown = true }
    }

    /// The panel starts to hide: no key stays held or recorded, the menu and Edit Spots close, a form that has not come yet
    /// will not open, and nothing moves in its fade.
    public func panelWillHide() {
        formAsk = nil
        takeHeld([])
        stopRecording()
        closeMenu()
        endEditing(moving: false)
        isShown = false
    }

    /// Waits for the reads of the open panel, up to the limit of a load at launch.
    public func waitForReads() async {
        let end = ContinuousClock.now + Self.loadLimit
        while runs.isReading, ContinuousClock.now < end {
            try? await Task.sleep(for: Self.loadPause)
        }
    }

    /// A downloaded update waits, so the app raises `app.update` for each spot that lists it, wanted or not, which is then on
    /// the grid before the panel next opens.
    public func updateIsReady(_ version: String) {
        runs.raise(.named(SpotEvent.appUpdate, value: version, readsEachSpot: true))
    }

    /// Asks for Touch ID or the Mac password, and returns whether the person passed. The prompt takes the focus, so the
    /// panel stays open while it asks, and takes the focus back after.
    public func allows(_ reason: String) async -> Bool {
        isAsking = true
        let allowed = await host.allows(reason)
        isAsking = false
        if isShown { host.takeFocus() }
        return allowed
    }

    /// Stops each call as the app quits.
    public func quit() {
        runs.quit()
    }

    private func holdAssignedKeys(_ config: Config) {
        assignedKeys = lastScan.offered(config.keys)
        host.hold(assignedKeys)
    }

    private func take(_ report: SpotRun.Report, of id: String) {
        switch report {
        case .toast(let text): host.confirm(text)
        case .failure(let text): host.notify(text)
        case .failureWithFix(let text, let fix): host.notify(text, fix: fix)
        case .listChange:
            spotListIsStale = true
            if mayMove(id) { updateVisible() }
        case .frame:
            spotListIsStale = true
            if sheets[id]?.spot.setsKeys == true {
                let config = files.config.read()
                host.applyConfig(config)
                holdAssignedKeys(config)
            }
        case .landed:
            host.land(id)
        case .closed:
            if let shown = openList, runs.sheets[shown]?.isOpen != true { showSheet(nil, moving: false) }
        case .chooseFiles:
            if let sheet = sheets[id] { host.chooseFiles(for: sheet.spot) { sheet.drop($0) } }
        }
    }

    public static func reason(_ error: Error) -> String {
        (error as? SpotError)?.reason ?? error.localizedDescription
    }
}
