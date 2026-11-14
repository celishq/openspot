import Foundation
import Observation

@MainActor
@Observable
public final class SpotsModel {
    public struct FormSession {
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

    public private(set) var fieldSheet: String?
    @ObservationIgnored var storeCards: [String: (entry: Entry, item: SpotStore.Item)]?
    public var entries: [Entry] = [] {
        didSet {
            spotListIsStale = true
            storeCards = nil
            askAnswers()
            updateVisible()
            prepareCardGlyphs()
        }
    }
    public var query = "" {
        didSet {
            guard query != oldValue else { return }
            selected = 0
            showPanels()
            askAnswers()
            updateVisible()
        }
    }
    public internal(set) var visible: [Entry] = []
    @ObservationIgnored var laidOutSizes: [SpotSize] = []
    @ObservationIgnored private var cardGlyphs: [String] = []
    @ObservationIgnored var laidOutGrid = SpotGrid()
    @ObservationIgnored var spotList = ItemList()
    @ObservationIgnored var spotListIsStale = true
    @ObservationIgnored var keyFrames: [String: String] = [:]
    @ObservationIgnored var spotListBuilds = 0
    @ObservationIgnored var visibleUpdates = 0
    var answerMatches: AnswerMatches {
        runs.answerMatches
    }
    @ObservationIgnored var mainSearch = MainSearch()
    public internal(set) var placements: [SpotPlacement] = [] {
        didSet {
            let height = SpotTokens.backdropHeight(gridHeight: SpotGrid.height(of: placements))
            if height != gridHeight { gridHeight = height }
            let bands = SpotGroupBands(placements)
            if bands != groupBands { groupBands = bands }
        }
    }
    public internal(set) var groupBands: SpotGroupBands?
    public internal(set) var panels = GridPanels() {
        didSet { showPanels() }
    }
    public private(set) var shownPanels = GridPanels()
    @ObservationIgnored var panelLeaving: GridPanel?
    private func showPanels() {
        let shown = query.isEmpty ? panels : GridPanels()
        if shownPanels != shown { shownPanels = shown }
    }
    public private(set) var gridHeight = SpotTokens.backdropHeight(gridHeight: 0)
    public var selected = 0
    public private(set) var openList: String?
    public internal(set) var flow = Flow() {
        didSet {
            for gone in Set(oldValue.pages).subtracting(flow.pages) { sheets[gone.spot]?.forget(page: gone.page) }
            let titles = flow.pages.prefix(max(flow.index, 0)).reversed().map(title(of:))
            if titles != behindTitles { behindTitles = titles }
        }
    }
    public private(set) var behindTitles: [String] = []
    public internal(set) var pushOffset = 0.0
    @ObservationIgnored var waitingPush: Double?
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
    public var fieldDrop: SpotDrop?
    public var showsFieldDrop = false
    public var reviewed: ReviewSpot?
    public var isFirstLaunch = false
    public var isShown = false
    public var isWarming = false
    public var isOpenForDrag = false
    public var isSettlingDrop = false
    public var isAsking = false

    public var entryKey = Shortcut.standard
    var isChainHeld = false
    @ObservationIgnored var chainWatch: Task<Void, Never>?
    public var recording: String?
    @ObservationIgnored private var problems: [String] = []
    public internal(set) var menuSession: ActionMenuSession? {
        didSet {
            let isOpen = menuSession != nil && menuSession?.phase != .closing
            if isOpen != isMenuOpen { isMenuOpen = isOpen }
            guard menuSession == nil else { return }
            if menuFrame != nil { menuFrame = nil }
            if menuBackdropHeight != 0 { change(.sheet(isOpen: false), { menuBackdropHeight = 0 }) }
        }
    }
    public private(set) var isMenuOpen = false
    public internal(set) var menuFrame: ActionMenuFrame?
    public internal(set) var menuBackdropHeight: CGFloat = 0
    public internal(set) var gridHint = HintWords("")
    public internal(set) var sheetHint = HintWords("")
    @ObservationIgnored var hintIsForEdit = false
    @ObservationIgnored var followsHint = false
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
    public private(set) var formRect: CGRect?
    public private(set) var formHasChoices = false
    public private(set) var formIsMultiple = false
    @ObservationIgnored var formAsk: UUID?
    public var isEditing = false
    public var tip: SpotTip?
    public internal(set) var drag: SpotDrag?
    public let lift = SpotLift()
    public internal(set) var landing: String?
    public internal(set) var carry: SpotCarry?
    public internal(set) var resize: SpotResize?
    @ObservationIgnored public var dragRest: Duration = .milliseconds(100)
    @ObservationIgnored var dragTarget: SpotDrag.Target?
    @ObservationIgnored var dragWait: Task<Void, Never>?
    @ObservationIgnored public internal(set) var gridScroll: CGFloat = 0
    @ObservationIgnored var scrollAtPress: CGFloat = 0
    @ObservationIgnored var pointerMove: CGSize?
    @ObservationIgnored var resizeGrip = CGPoint(x: SpotTokens.resizeHandle, y: SpotTokens.resizeHandle)
    public var arrangement = SpotArrangement()
    @ObservationIgnored public private(set) var defaultArrangement = SpotArrangement()
    public internal(set) var flashSymbol: String?
    @ObservationIgnored public var flashPause: Duration = .milliseconds(1500)
    @ObservationIgnored var flashWatch: Task<Void, Never>?
    @ObservationIgnored private var scanned: [Spot] = []
    @ObservationIgnored private var spotScan = SpotScan()
    @ObservationIgnored private var lastScan = ScanResult(files: [], refused: [])
    @ObservationIgnored private var lastRead: (config: Config, folder: SpotsFolder)?
    @ObservationIgnored private var loadedStamp: SpotsFolder.Stamp?
    @ObservationIgnored private var loadedConfig: Config?
    @ObservationIgnored private(set) var gridBuilds = 0
    @ObservationIgnored var removal: Removal?
    @ObservationIgnored private var fileStamps: [String: String] = [:]

    @ObservationIgnored public unowned let host: SpotsHost
    @ObservationIgnored public let files: AppPlaces
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

    public var config: Config {
        lastRead?.config ?? files.config.read()
    }

    public var folder: SpotsFolder {
        lastRead?.folder ?? files.folder
    }

    public var sheets: [String: SpotRun] {
        runs.sheets
    }

    public func reading(of id: String) -> MetricReading? {
        runs.sheets[id]?.reading
    }

    public var workCount: Int {
        runs.work.count
    }

    public func beginFirstLaunch() {
        isFirstLaunch = true
        try? files.config.begin(enabling: folder.startingSpots())
        reload()
        host.present()
    }

    public func reload() {
        reload(patching: nil)
    }

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
        if panels != config.panels { panels = config.panels }
        scanned = scan.spots
        if let ids, isOnlyNamed { patchEntries(ids) } else { rebuildEntries() }
        readWindows()
        if problems != self.problems, !problems.isEmpty {
            host.notify(problems.joined(separator: " "))
        }
        self.problems = problems
    }

    public func spotsChanged() {
        let stamps = fileStamps
        let id = selectedEntry?.id
        reload()
        if let position = visible.firstIndex(where: { $0.id == id }) { selected = position }
        guard isShown else { return }
        for entry in entries where entry.spot.read?.has(.panel) == true && fileStamps[entry.id] != stamps[entry.id] {
            sheets[entry.id]?.read(need: .change)
        }
    }

    private static func stamps(of scan: ScanResult) -> [String: String] {
        var stamps: [String: String] = [:]
        for script in scan.scripts where script.host == nil {
            guard let values = try? FileManager.default.attributesOfItem(atPath: script.url.path) else { continue }
            let date = (values[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            stamps[script.id] = "\(date) \(values[.systemFileNumber] ?? "")"
        }
        return stamps
    }

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

    func tookOwnWrite() {
        let config = files.config.read()
        loadedConfig = config
        lastRead = (config, lastRead?.folder ?? files.folder(config))
    }

    private func patchEntries(_ ids: Set<String>) {
        let named: (Spot) -> Bool = { ids.contains($0.id) || ids.contains(SpotsFolder.coreID(of: $0)) }
        let letters = arrangement.letters(over: defaultArrangement)
        var next = entries.filter { !named($0.spot) }
        for (index, spot) in ordered().enumerated() where named(spot) {
            next.insert(Entry(spot: spot, run: runs.sheets[spot.id], choice: arrangement, defaults: defaultArrangement, letter: letters[spot.id]), at: min(index, next.count))
        }
        if next != entries { entries = next }
    }

    private func prepareCardGlyphs() {
        let glyphs = entries.compactMap(\.spot.glyph)
        guard glyphs != cardGlyphs else { return }
        cardGlyphs = glyphs
        host.prepareCards(glyphs: glyphs)
    }

    public func rebuildEntries() {
        gridBuilds += 1
        let letters = arrangement.letters(over: defaultArrangement)
        let next = ordered().map { Entry(spot: $0, run: runs.sheets[$0.id], choice: arrangement, defaults: defaultArrangement, letter: letters[$0.id]) }
        let field = next.first { $0.spot.growsFromField }?.id
        if field != fieldSheet { fieldSheet = field }
        if next != entries { entries = next }
    }

    private func ordered() -> [Spot] {
        let sorted = scanned.enumerated().sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }.map(\.element)
        return arrangement.ordered(defaultArrangement.ordered(sorted))
    }

    public func panelWillShow(holding modifiers: Shortcut.Modifiers) {
        finishPick()
        selected = 0
        takeHeld(modifiers)
        runs.panelOpened()
        askAnswers()
        DispatchQueue.main.async { [weak self] in self?.isShown = true }
    }

    public func panelWillHide() {
        formAsk = nil
        takeHeld([])
        stopRecording()
        closeMenu()
        endEditing(moving: false)
        isShown = false
    }

    public func waitForReads() async {
        let end = ContinuousClock.now + Self.loadLimit
        while runs.isReading, ContinuousClock.now < end {
            try? await Task.sleep(for: Self.loadPause)
        }
    }

    public func updateIsReady(_ version: String) {
        runs.raise(.named(SpotEvent.appUpdate, value: version, readsEachSpot: true))
    }

    public func allows(_ reason: String) async -> Bool {
        isAsking = true
        let allowed = await host.allows(reason)
        isAsking = false
        if isShown { host.takeFocus() }
        return allowed
    }

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
            markFound(id)
            if mayMove(id) { updateVisible() }
        case .frame(let frame):
            markFound(id)
            if sheets[id]?.spot.setsKeys == true, keyFrames.updateValue(frame, forKey: id) != frame {
                let config = files.config.read()
                host.applyConfig(config)
                holdAssignedKeys(config)
            }
        case .landed:
            host.land(id)
        case .closed:
            if let shown = openList, runs.sheets[shown]?.isOpen != true {
                showSheet(nil, moving: false)
                endFlow()
            }
        case .chooseFiles:
            _ = chooseFiles(for: id)
        case .move(let move):
            self.move(move, in: id)
        }
    }

    public func chooseFiles(for id: String) -> Bool {
        guard let sheet = sheets[id], sheet.spot.takesDrops else { return false }
        host.chooseFiles(for: sheet.spot) { sheet.drop($0) }
        return true
    }

    public static func reason(_ error: Error) -> String {
        (error as? SpotError)?.reason ?? error.localizedDescription
    }
}
