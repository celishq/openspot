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
    private static let loadLimit: Duration = .seconds(2)
    private static let loadPause: Duration = .milliseconds(20)
    public static let dropPause: Duration = .milliseconds(300)

    public private(set) var fieldSheet: String? {
        didSet { takeCards() }
    }

    public func entry(_ id: String) -> Entry? {
        let entries = entries
        return entryPlaces[id].map { entries[$0] }
    }

    private func takeCards() {
        let next = entries.filter { $0.id != fieldSheet }
        if next != cards { cards = next }
    }
    @ObservationIgnored private var entryPlaces: [String: Int] = [:]
    public private(set) var cards: [Entry] = []
    public var entries: [Entry] = [] {
        didSet {
            entryPlaces = Dictionary(entries.enumerated().map { ($0.element.id, $0.offset) }, uniquingKeysWith: { first, _ in first })
            takeCards()
            spotListIsStale = true
            askAnswers()
            takeDetails()
            showVisible()
            prepareCardGlyphs()
        }
    }
    public var query = "" {
        didSet {
            guard query != oldValue else { return }
            takeDetails()
            if query.trimmingCharacters(in: .whitespaces).isEmpty { noteMiss() }
            selected = 0
            askAnswers()
            showVisible()
        }
    }
    public internal(set) var visible: [Entry] = []
    @ObservationIgnored private var cardGlyphs: [String] = []
    @ObservationIgnored var laidOutTop: CGFloat = 0
    @ObservationIgnored var spotList = ItemList()
    @ObservationIgnored var spotListIsStale = true
    @ObservationIgnored var holdsRows = false
    @ObservationIgnored var commands = CommandIndex()
    public internal(set) var slash: SlashCommand?
    @ObservationIgnored var content = GridContent.cards
    public internal(set) var attachments = AttachmentStack() {
        didSet {
            let covered = attachments.layout.spreadCount > AttachmentStack.pile
            if isFieldCovered != covered { isFieldCovered = covered }
            let word = attachments.isOn ? SearchPrompt.actions : SearchPrompt.grid
            if promptWord != word { promptWord = word }
        }
    }
    public internal(set) var isAttachmentHidden = false
    @ObservationIgnored var isAttachmentOpen = false
    public private(set) var isFieldCovered = false
    public private(set) var promptWord = SearchPrompt.grid
    public internal(set) var details: AttachmentDetails? {
        didSet {
            let room = Self.room(of: details)
            if detailsRoom != room { detailsRoom = room }
            if let details, heldDetails != details { heldDetails = details }
        }
    }
    public private(set) var heldDetails: AttachmentDetails?
    public internal(set) var peek: Peek?
    public internal(set) var peekRect: CGRect?
    public internal(set) var peekSource: CGRect?
    public internal(set) var isPeekOpen = false
    @ObservationIgnored var isPeekGrowing = false
    var isPeeking = false
    public internal(set) var isPeekGrown = false
    public internal(set) var isPeekPaused = false
    @ObservationIgnored var peekRead: [Peek.Look] = []
    public private(set) var detailsRoom: CGFloat = 0
    @ObservationIgnored var attachmentWatch: Task<Void, Never>?
    @ObservationIgnored var spotListBuilds = 0
    @ObservationIgnored var visibleUpdates = 0
    @ObservationIgnored var missedSearch = MissedSearch()
    var answerMatches: AnswerMatches {
        runs.answerMatches
    }
    @ObservationIgnored var panelSearch = PanelSearch()
    @ObservationIgnored var foundSpots: [Entry] = []
    public internal(set) var placements: [SpotPlacement] = [] {
        didSet { takePlacements() }
    }
    @ObservationIgnored var isPanelHidden = true
    @ObservationIgnored var heldLayout: Theme.Layout?
    @ObservationIgnored var laidOut = Theme.Layout()
    @ObservationIgnored var takenTheme = Theme()
    public internal(set) var grid = GridLayout() {
        didSet {
            guard grid != oldValue else { return }
            widen()
        }
    }
    public internal(set) var backdropSheet: SpotRun?
    public private(set) var gridHeight = SpotTokens.contentHeight(gridHeight: 0)

    func takePlacements() {
        let free = grid.freeCells(around: placements)
        if free != freeCells { freeCells = free }
        let shown = content.isFixed && isEditing ? grid.height + laidOutTop : SpotPlacement.height(of: placements)
        let height = SpotTokens.contentHeight(gridHeight: max(shown, laidOutTop))
        if height != gridHeight { gridHeight = height }
        takeShade()
    }
    public var selected = 0 {
        didSet {
            if confirming != nil, selected != oldValue { confirming = nil }
            takeShade()
        }
    }
    public internal(set) var confirming: GlobalKey?
    public private(set) var openSheetID: String?
    public internal(set) var waiting: Set<String> = []
    @ObservationIgnored public internal(set) var grant: AccessGrant?
    @ObservationIgnored var grantWatch: Task<Void, Never>?
    @ObservationIgnored var waitingRead: Task<Void, Never>?
    public internal(set) var flow = Flow() {
        didSet {
            for gone in Set(oldValue.pages).subtracting(flow.pages) { sheets[gone.spot]?.forget(route: gone.route) }
        }
    }
    @ObservationIgnored var session = PanelSession()
    public internal(set) var textSelections = 0
    public internal(set) var flowEdges = FlowEdges()
    public internal(set) var closingSheet: ClosingSheet?
    @ObservationIgnored var edgeStep = 0
    @ObservationIgnored var landedStep = -1
    @ObservationIgnored var waitingPush = false
    public internal(set) var transition = SheetTransition() {
        didSet {
            if transition.id != nil, transition.id != oldValue.id || (transition.phase == .closing && oldValue.phase != .closing), cardScroll != gridScroll { cardScroll = gridScroll }
            holdBackdropSheet()
            if transition.phase != .closing, closingSheet != nil { closingSheet = nil }
            let shown = transition.shown
            if shown != openSheetID {
                openSheetID = shown
                recordAskedField()
                takeMode()
            }
            let moving = transition.isMoving ? transition.id : nil
            if moving != (oldValue.isMoving ? oldValue.id : nil) {
                runs.opening.moving = moving
            } else if moving != nil, transition.phase != oldValue.phase {
                runs.opening.restart()
            }
        }
    }
    @ObservationIgnored public var closingPick: (item: SpotItem, entry: Entry)?
    public let runs: SpotRuns
    public let toasts: Toasts
    @ObservationIgnored public var dragWatch: Task<Void, Never>?
    public var dragPaths: [String] = []
    @ObservationIgnored var dragRead: Task<Void, Never>?
    @ObservationIgnored var readPaths: [String] = []
    public var draggedSpot: SpotDrop?
    public var isPointerOverDrop = false
    public var fieldDrop: SpotDrop?
    public var showsFieldDrop = false
    public var reviewed: ReviewSpot?
    public var isFirstLaunch = false
    public var isShown = false {
        didSet {
            takeCardsPlay()
            if isShown, !oldValue { startShowMotion() }
        }
    }
    @ObservationIgnored var showMotion: Task<Void, Never>?
    @ObservationIgnored var showLength: TimeInterval?
    @ObservationIgnored var heldArrivals: [(value: AttachmentValue, id: String)] = []
    public var isWarming = false
    public var isOpenForDrag = false
    public var isSettlingDrop = false
    public var isAsking = false

    public var entryKey = Shortcut.standard
    public var recording: String? {
        didSet {
            keys.clear()
            takeMode()
        }
    }
    public let keys = KeyRecording()
    @ObservationIgnored var entryKeyIsOff = false
    @ObservationIgnored var askedAnswer: String?

    public func hold(_ modifiers: Shortcut.Modifiers) {
        holdCommand(modifiers.contains(.command))
        guard recording != nil, let code = keys.hold(modifiers) else { return }
        record(code: code, modifiers: modifiers)
    }

    public func releaseKey() {
        keys.release()
    }

    public func appCameToFront(_ name: String) {
        guard recordsField else { return }
        keys.appCameToFront(name)
    }

    public func inputSourceChanged() {
        guard recordsField else { return }
        keys.inputSourceChanged()
    }
    public internal(set) var mode = PanelMode.grid {
        didSet { takeCardsPlay() }
    }
    public private(set) var cardsPlay = false

    private func takeCardsPlay() {
        let next = isShown && mode == .grid
        if next != cardsPlay { cardsPlay = next }
    }
    @ObservationIgnored private var problems: [String] = []
    public internal(set) var menuSession: ActionMenuSession? {
        didSet {
            let isOpen = menuSession != nil && menuSession?.phase != .closing
            if isOpen != isMenuOpen {
                isMenuOpen = isOpen
                takeMode()
            }
            let isGrown = menuSession?.isGrown == true
            if isGrown != isMenuGrown { isMenuGrown = isGrown }
            takeShade()
            guard menuSession == nil else { return }
            if menuFrame != nil { menuFrame = nil }
        }
    }
    public private(set) var isMenuOpen = false
    public private(set) var isMenuGrown = false
    public private(set) var gridShade = GridShade()

    private func takeShade() {
        var next = GridShade()
        if let menuSession, openSheetID == nil { next = GridShade(over: placements, leaving: selected, isOn: menuSession.isGrown) }
        if next != gridShade { gridShade = next }
    }
    public internal(set) var menuFrame: ActionMenuFrame?
    public internal(set) var menuContentHeight: CGFloat = 0
    public internal(set) var gridHint = HintWords("")
    public internal(set) var sheetHint = HintWords("")
    @ObservationIgnored var hintIsForEdit = false
    @ObservationIgnored var followsHint = false
    @ObservationIgnored public internal(set) var hintTakes = 0
    @ObservationIgnored var hintIsStale = false
    @ObservationIgnored var pressDepth = 0
    public var form: FormSession? {
        didSet {
            let rect = form.map { SpotTokens.formRect($0.draft.form) }
            if rect != formRect { formRect = rect }
            let hasChoices = form?.draft.choices != nil
            if hasChoices != formHasChoices { formHasChoices = hasChoices }
            let isMultiple = form?.draft.isMultiple == true
            if isMultiple != formIsMultiple { formIsMultiple = isMultiple }
            let hint = HintWords(KeyRow.hint(of: formRows))
            if hint != formHint { formHint = hint }
            takeMode()
        }
    }
    public private(set) var formRect: CGRect?
    public private(set) var formHasChoices = false
    public private(set) var formIsMultiple = false
    public private(set) var formHint = HintWords("")
    @ObservationIgnored var pendingAsk: UUID?
    @ObservationIgnored var askedWindows: Set<String> = []
    public internal(set) var editing: EditSession? {
        didSet {
            guard isEditing != (oldValue != nil) else { return }
            takeMode()
            takePlacements()
        }
    }
    public var isEditing: Bool { editing != nil }
    public var isArranging: Bool { editing == .arrange }
    public let shelf = Shelf()
    @ObservationIgnored var command = CommandHold.up
    @ObservationIgnored var leftOut: Set<String> = []
    public internal(set) var freeCells: [GridCell] = []
    public internal(set) var isGridFixed = true
    public var tip: SpotTip?
    public internal(set) var pointedCard: String?
    var shakes: [String: Int] = [:]
    public internal(set) var gesture: SpotGesture?
    public var drag: SpotDrag? { gesture?.drag }
    public var resize: SpotResize? { gesture?.resize }
    public var pin: SpotPin? { gesture?.pin }
    public let lift = SpotLift()
    public internal(set) var landing: String?
    public internal(set) var carry: SpotCarry?
    @ObservationIgnored public var dragRest: Duration = .milliseconds(100)
    @ObservationIgnored var dragTarget: GridCell?
    @ObservationIgnored public internal(set) var gridScroll: CGFloat = 0
    public internal(set) var cardScroll: CGFloat = 0
    @ObservationIgnored var dragWait: Task<Void, Never>?
    @ObservationIgnored var pointerMove: CGSize?
    @ObservationIgnored var resizeGrip = CGPoint(x: SpotTokens.resizeHandle, y: SpotTokens.resizeHandle)
    @ObservationIgnored public private(set) var defaultArrangement = SpotChoices()
    public internal(set) var flashSymbol: String?
    @ObservationIgnored public var flashPause: Duration = .milliseconds(1500)
    @ObservationIgnored var flashWatch: Task<Void, Never>?
    @ObservationIgnored private var scanned: [Spot] = []
    @ObservationIgnored public weak var store: Store?
    @ObservationIgnored private var load = SpotLoad.empty
    @ObservationIgnored private var loading: Task<Void, Never>?
    @ObservationIgnored private var lastScan = ScanResult(files: [], refused: [])
    @ObservationIgnored private var allowed: [SpotLock.Entry] = []
    @ObservationIgnored private var loaded: (stamp: [String: [Int]], hosted: [Spot], allowed: [SpotLock.Entry])?
    @ObservationIgnored private(set) var kept = KeptConfig() {
        didSet {
            if kept.config.settings != oldValue.config.settings { runs.take(settings: kept.config.settings) }
        }
    }
    @ObservationIgnored private(set) var gridBuilds = 0
    @ObservationIgnored private var fileStamps: [String: [Int]] = [:]

    @ObservationIgnored public unowned let host: SpotsHost
    @ObservationIgnored public let files: AppPlaces
    @ObservationIgnored public let settingsBook = SettingsBook()
    @ObservationIgnored private(set) var assignedKeys: [GlobalKey] = []

    public init(host: SpotsHost, files: AppPlaces = .standard, runs: SpotRuns? = nil) {
        self.host = host
        self.files = files
        defaultArrangement = files.readDefaultArrangement()
        let runs = runs ?? SpotRuns(
            recent: { files.recent(of: $0) },
            prepare: { [unowned host] in await host.prepare($0, glyphs: $1) },
            log: files.log,
            stats: files.stats,
            timers: files.timers,
            schedule: files.schedule,
            timeline: files.timeline
        )
        self.runs = runs
        toasts = Toasts(clock: runs.clock)
        self.runs.secrets = files.secrets
        self.runs.onReport = { [weak self] id, report in self?.take(report, of: id) }
        self.runs.onScheduleAsk = { [weak self] id in self?.askSchedule(of: id) }
        self.runs.partsArrival = { [weak self] id, bring in
            guard let self else { return bring() }
            bringParts(of: id, bring)
        }
        settingsBook.model = self
    }

    public var config: Config {
        kept.config
    }

    public var arrangement: SpotChoices {
        kept.config.arrangement
    }

    public var folder: SpotsFolder {
        files.spots
    }

    public var sheets: [String: SpotRun] {
        runs.sheets
    }

    public var actCount: Int {
        runs.acts.count
    }

    public func beginFirstLaunch() async {
        isFirstLaunch = true
        do {
            try files.config.begin(naming: folder.startingSpots())
        } catch {
            toast(.failure("Openspot could not save the spots. \(Self.reason(error))"))
        }
        await reload()
        if let first = runs.firstLaunchSheet { push(FlowSheet(spot: first)) }
        host.present()
    }

    public func reload() async {
        let previous = loading
        let config = files.config
        let folder = folder
        let secrets = files.secrets
        let lock = files.lock
        let task = Task {
            await previous?.value
            let start = kept
            let (next, load, allowed) = await Self.read(config, folder, secrets, lock)
            self.load = load
            self.allowed = allowed
            let id = selectedEntry?.id
            reload(patching: nil, to: kept == start ? next : kept)
            if let position = visible.firstIndex(where: { $0.id == id }) { selected = position }
        }
        loading = task
        await task.value
        readWaiting()
    }

    @concurrent
    private nonisolated static func read(_ config: ConfigFile, _ folder: SpotsFolder, _ secrets: SecretStore, _ lock: SpotLock) async -> (KeptConfig, SpotLoad, [SpotLock.Entry]) {
        _ = try? secrets.read()
        return (config.readKept(), KeptScan.shared.load(folder), (try? lock.entries()) ?? [])
    }

    func reload(patching ids: Set<String>?, to next: KeptConfig) {
        let config = next.config
        let isSameConfig = config == kept.config
        host.applyConfig(config)
        kept = next
        let folder = files.spots
        let hosted = reviewed.map { [$0.spot] } ?? []
        guard loaded.map({ $0.stamp != load.stamp || $0.hosted != hosted || $0.allowed != allowed }) ?? true || !isSameConfig else { return holdAssignedKeys(config) }
        var scan = ((try? load.result(hosted: hosted)) ?? ScanResult(files: [SpotFile(id: "openspot", spots: hosted)], refused: [])).allowing(allowed)
        let faults = load.faultSpots(of: scan, prompt: SpotPrompt(places: files))
        if !faults.isEmpty { scan.files.append(SpotFile(id: FaultSpot.fileID, spots: faults)) }
        scan.addSettings(in: files.config, read: config, defaults: defaultArrangement)
        let carded = Set(faults.map(\.id))
        let problems = scan.refused.filter { !carded.contains($0.file) }.map { "\($0.file) was not loaded: \($0.reason)" }
        var stamps: [String: [Int]] = [:]
        for script in scan.scripts where script.host == nil { stamps[script.id] = load.stamp(of: script) }
        let unreviewed = scan.spots.filter { spot in
            !spot.triggers.schedule.isEmpty && spot.host == nil && !spot.isBuiltIn && !folder.isCore(spot) && !allowed.contains { $0.holds(spot.id) }
        }
        runs.take(scan, menuBar: config.arrangement.menuBar, stamps: stamps, unreviewed: Set(unreviewed.map(\.id)))
        lastScan = scan
        loaded = (load.stamp, hosted, allowed)
        let others = ids.map { ids in { (stamps: [String: [Int]]) in stamps.filter { !ids.contains($0.key) } } }
        let isOnlyNamed = others.map { $0(stamps) == $0(fileStamps) } ?? false
        fileStamps = stamps
        holdAssignedKeys(config)
        if grid != config.grid { grid = config.grid }
        if let store, Set(scan.spots.map(\.url)) != Set(scanned.map(\.url)) { Task { await store.read() } }
        scanned = scan.spots
        if let ids, isOnlyNamed { patchEntries(ids) } else { rebuildEntries() }
        readWindows()
        if problems != self.problems, !problems.isEmpty {
            toast(.failure(problems.joined(separator: " ")))
        }
        self.problems = problems
        settingsBook.refresh()
    }

    public func spotsChanged() async {
        let stamps = fileStamps
        await reload()
        guard isShown else { return }
        for entry in entries where entry.spot.triggers.showsOnPanel && fileStamps[entry.id] != stamps[entry.id] {
            sheets[entry.id]?.show(need: .change)
        }
    }

    public func reveal(_ id: String) async -> Bool {
        await reload()
        return showCard(id)
    }

    func showCard(_ id: String) -> Bool {
        guard let entry = card(id: id) else { return false }
        closeMenu()
        form = nil
        endEditing(moving: false)
        if openSheetID != nil { closeSheet(moving: false) }
        host.show()
        takeQuery(visible.contains { $0.id == id } ? "" : entry.state.title)
        selected = visible.firstIndex { $0.id == id } ?? 0
        return true
    }

    public func configChanged(_ change: ConfigChange, to sent: KeptConfig) {
        let next = files.config.readKept(unlessCurrent: sent)
        if case .spots(let ids) = change {
            let id = selectedEntry?.id
            reload(patching: Set(ids), to: next)
            if let position = visible.firstIndex(where: { $0.id == id }) { selected = position }
            return
        }
        if take(next, changing: change.sections) {
            switch change {
            case .keys:
                host.applyConfig(config)
                holdAssignedKeys(config)
            case .spots, .value:
                break
            }
        }
        if case .value(let spot, let caller) = change {
            if caller != spot, let sheet = sheets[spot], sheet.isWanted { sheet.show(need: .change) }
        }
        runs.showOfferedItems()
    }

    func write(_ section: Config.Section, _ work: (inout Config) throws -> Void) throws {
        take(try files.config.change(from: kept, work), changing: [section])
    }

    @discardableResult
    private func take(_ next: KeptConfig, changing sections: Set<Config.Section>) -> Bool {
        guard next.config.sections(differingFrom: config).isSubset(of: sections) else {
            reload(patching: nil, to: next)
            return false
        }
        kept = next
        return true
    }

    private func patchEntries(_ ids: Set<String>) {
        let named: (Spot) -> Bool = { ids.contains($0.id) || ids.contains(SpotsFolder.coreID(of: $0)) }
        var next = entries.filter { !named($0.spot) }
        for (index, spot) in ordered().enumerated() where named(spot) {
            next.insert(Entry(spot: spot, run: runs.sheets[spot.id], choice: arrangement, defaults: defaultArrangement, isCore: folder.isCore(spot)), at: min(index, next.count))
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
        let folder = folder
        let next = ordered().map { Entry(spot: $0, run: runs.sheets[$0.id], choice: arrangement, defaults: defaultArrangement, isCore: folder.isCore($0)) }
        let field = next.first { $0.spot.growsFromField }?.id
        if field != fieldSheet { fieldSheet = field }
        if next != entries { entries = next }
    }

    private func ordered() -> [Spot] {
        let sorted = scanned.enumerated().sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }.map(\.element)
        return arrangement.ordered(defaultArrangement.ordered(sorted))
    }

    public func panelWillShow() {
        asOnePress {
            isPanelHidden = false
            readWaiting()
            settingsBook.readRows()
            finishPick()
            resumeSession()
            selected = 0
            openAttachment()
            askAnswers()
            host.nextFrame { [weak self] in
                self?.isShown = true
                self?.recordAskedField()
            }
        }
    }

    public func panelWillHide() {
        asOnePress {
            parkSession()
            dropPeekNow()
            holdCommand(false)
            endSpread()
            if attachments.spreads { attachments.fold() }
            hideAttachments()
            pendingAsk = nil
            if confirming != nil { confirming = nil }
            stopRecording()
            closeMenu()
            endEditing(moving: false)
            isShown = false
            takeEntryKey()
        }
    }

    public func waitForShows() async {
        let end = ContinuousClock.now + Self.loadLimit
        while runs.isShowing, ContinuousClock.now < end {
            try? await Task.sleep(for: Self.loadPause)
        }
    }

    public func updateIsReady(_ version: String) {
        runs.raise(.named(EventName.appUpdate, value: version, showsEachSpot: true))
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
        case .toast(let note): toast(note, of: note.kind == .failure ? "" : id)
        case .dropToast(let toast): toasts.drop(toast, of: id)
        case .listChange:
            asOnePress {
                markFound(id)
                if mayMove(id) { updateVisible() }
            }
        case .answered:
            if holdsRows { asOnePress { updateVisible() } }
        case .parts:
            if id == openSheetID { recordAskedField() }
        case .frame(let frame):
            markFound(id)
            if id == openSheetID { takeKeyField() }
        case .landed:
            host.land(id)
        case .closed:
            if let shown = openSheetID, runs.sheets[shown]?.isOpen != true {
                showSheet(nil, moving: false)
                endFlow()
            }
        case .move(let move):
            self.move(move, in: id)
        case .refused(let item):
            shakes[Self.shakeKey(of: item, in: id), default: 0] += 1
        case .done:
            if isShown { host.dismiss() }
        case .attachment(let value):
            takeAttachment(value, of: id)
        case .attachmentFailed(let text):
            failAttachment(text, of: id)
        }
    }

    public func chooseFiles(for id: String) -> Bool {
        guard let sheet = sheets[id], sheet.spot.takesDrops else { return false }
        host.chooseFiles(for: sheet.spot) { sheet.drop(AttachmentValue(files: FileKinds.Disk().read($0))) }
        return true
    }

    public nonisolated static func reason(_ error: Error) -> String {
        (error as? SpotError)?.reason ?? error.localizedDescription
    }
}
