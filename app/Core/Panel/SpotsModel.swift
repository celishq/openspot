import Foundation
import Observation

@MainActor
@Observable
public final class SpotsModel {
    /// One card: a script, a widget, or a row that the main search found. It holds which card it is and the person's
    /// choices. Its state, its size and its place on the grid come live from its run, so two equal entries can show different
    /// things, and the model lays out the grid again on each change that a run reports.
    public struct Entry: Identifiable, Equatable {
        public let id: String
        public let item: SpotItem?
        private let sizeChoice: SpotSize?
        private let run: SpotRun?
        private let fixedCommand: Spot
        private let fixedState: SpotState
        private let gridChoice: Bool?

        public init(command: Spot, run: SpotRun?, choice: SpotArrangement = SpotArrangement()) {
            id = command.id
            sizeChoice = choice.size(of: command.id)
            gridChoice = choice.isOnGrid(of: command.id)
            item = nil
            self.run = run
            fixedCommand = command
            fixedState = command.headerState
        }

        /// A card of a full row for an item that the main search found in a list.
        public init(command: Spot, item: SpotItem) {
            id = "\(command.id)\n\(item.run)"
            sizeChoice = .strip
            gridChoice = nil
            self.item = item
            run = nil
            fixedCommand = command
            fixedState = SpotState(title: item.title, subtitle: item.path(in: command))
        }

        @MainActor public var command: Spot {
            run?.command ?? fixedCommand
        }

        /// The size of its card: the person's choice, or else what its last read says, or else its header (F9). A card of a
        /// fault is never small, so that its words show.
        @MainActor public var size: SpotSize {
            let size = sizeChoice ?? state.size ?? command.size
            return command.fault != nil && size == .small ? .wide : size
        }

        /// The words of its last failed call, until a call ends well.
        @MainActor public var failure: String? {
            run?.failure
        }

        /// Whether the grid shows it: the person's choice, or else what the spot says.
        @MainActor public var isOnGrid: Bool {
            gridChoice ?? state.isOnGrid
        }

        @MainActor public var kind: SpotKind {
            item == nil ? command.kind : .launch
        }

        @MainActor public var symbol: String {
            item?.symbol ?? command.symbol
        }

        /// Whether the card draws the image, the file icon or the glyph that its header names, in place of a symbol.
        @MainActor public var showsHeaderPicture: Bool {
            item?.symbol == nil && (command.icon != nil || command.glyph != nil)
        }

        @MainActor public var state: SpotState {
            run?.state ?? fixedState
        }

        /// Whether its card is on. A view that reads only this hears of no other change of its state.
        @MainActor public var isOn: Bool {
            run?.isOn ?? (fixedState.on == true)
        }

        /// What the card shows: its own state, with the words of its running work over it.
        @MainActor public var shownState: SpotState {
            run?.shownState ?? fixedState
        }

        /// The running work that its glyph shows.
        @MainActor public var work: ScriptCall? {
            run?.work.first
        }

        /// Whether a press of the card stops its running work.
        @MainActor public var stopsOnPress: Bool {
            run?.cardWork != nil
        }

        /// Whether two entries are one card: the same spot or row, the same choices and the same run.
        public static func == (lhs: Entry, rhs: Entry) -> Bool {
            lhs.id == rhs.id && lhs.item == rhs.item && lhs.sizeChoice == rhs.sizeChoice && lhs.gridChoice == rhs.gridChoice
                && lhs.run === rhs.run && lhs.fixedCommand == rhs.fixedCommand && lhs.fixedState == rhs.fixedState
        }
    }

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

    private static let searchLimit = 8
    public static let dragWatchPause: Duration = .milliseconds(16)
    private static let chainPause: Duration = .milliseconds(200)
    private static let loadLimit: Duration = .seconds(2)
    private static let loadPause: Duration = .milliseconds(20)
    public static let dropPause: Duration = .milliseconds(300)

    public var entries: [Entry] = [] {
        didSet { updateVisible() }
    }
    public var query = "" {
        didSet {
            if query != oldValue { selected = 0 }
            updateVisible()
        }
    }
    /// The cards that show, in their order. Each change of a card or of the search sets it again, and an equal list tells no
    /// view.
    public private(set) var visible: [Entry] = []
    /// The sizes that `placements` were laid out from.
    @ObservationIgnored private var laidOutSizes: [SpotSize] = []
    /// The cards as the items that the main search finds. It folds them again only when they change.
    @ObservationIgnored private var spotList = ItemList()
    /// Where each visible spot lies on the grid, in the order of `visible`.
    public private(set) var placements: [SpotPlacement] = []
    public var selected = 0
    /// The sheet that shows: the transition's sheet, from its first frame on its card until its close starts. It follows the
    /// open run: a run's first answer shows its sheet, and a close or a hidden panel takes it away. It changes only with the
    /// sheet, not with each phase of its motion.
    public private(set) var openList: String?
    /// Where the open sheet is in its motion between its card and its open place.
    public private(set) var transition = SheetTransition() {
        didSet {
            let shown = transition.shown
            if shown != openList { openList = shown }
            let opening = transition.phase == .opening ? transition.id : nil
            if opening != (oldValue.phase == .opening ? oldValue.id : nil) { runs.opening.moving = opening }
        }
    }
    public var closingPick: (item: SpotItem, entry: Entry)?
    public let runs: SpotRuns
    public var dragWatch: Task<Void, Never>?
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
    public var spotsChanged = false
    public var isShown = false
    /// Whether the app is opening the panel unseen as it starts, which a press of the key ends.
    public var isWarming = false
    /// Whether a drag holds the panel open: one over the menu bar item, or one that a press in another app started (D7). The
    /// panel is not key then, and its field takes no focus.
    public var isOpenForDrag = false
    /// Whether a drop just opened a sheet, which holds the focus while the app that the drag came from lets go of it (D8).
    public var isSettlingDrop = false
    public var updateSpot: UpdateSpot?

    public var entryKey = Shortcut.standard
    private var isChainHeld = false
    private var chainWatch: Task<Void, Never>?
    public var recording: String?
    private var problems: [String] = []
    public var menu: ActionMenu?
    public var menuTarget: Target?
    public var form: FormSession?
    /// The ask for a form that waits for its script. A newer ask, a cancel, a close or a hidden panel replaces it.
    @ObservationIgnored var formAsk: UUID?
    /// Whether the grid is in Edit Spots, where it also shows the spots that are off the grid, and a press only selects.
    public var isEditing = false
    public var arrangement = SpotArrangement()
    /// The symbol of the command whose key a person pressed last, which the Openspot item shows for `flashPause`.
    public private(set) var flashSymbol: String?
    @ObservationIgnored public var flashPause: Duration = .milliseconds(1500)
    @ObservationIgnored private var flashWatch: Task<Void, Never>?
    private var scanned: [Spot] = []
    private var pluginScan = PluginScan()
    private var lastScan = ScanResult(plugins: [], refused: [])
    /// The stamp of the folder and the config that the cards were last built from.
    @ObservationIgnored private var loadedStamp: PluginFolder.Stamp?
    @ObservationIgnored private var loadedConfig: Config?
    /// The files of the last spot that Delete moved to the Trash, which `⌘Z` puts back.
    @ObservationIgnored var removal: Removal?
    /// The stamp of each script file at the last scan, which says which scripts a change of the folder touched.
    @ObservationIgnored private var fileStamps: [String: String] = [:]

    /// The app around the panel, which shows it, tells the person and moves each change.
    @ObservationIgnored public unowned let host: SpotsHost
    /// Where the plugins, the config and the recent rows live.
    @ObservationIgnored public let files: SpotFiles

    public init(host: SpotsHost, files: SpotFiles = .standard, runs: SpotRuns? = nil) {
        self.host = host
        self.files = files
        self.runs = runs ?? SpotRuns(
            recent: { files.recent(of: $0) },
            prepare: { [unowned host] in await host.prepare($0, glyphs: $1) },
            log: files.log
        )
        self.runs.onReport = { [weak self] id, report in self?.take(report, of: id) }
        self.runs.partsArrival = { [weak self] id, bring in
            guard let self else { return bring() }
            bringParts(of: id, bring)
        }
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
        try? files.config.begin(enabling: files.folder.startingSpots())
        reload()
        host.present()
    }

    /// Reads the config file again, and the plugin folder when a file that its scan reads has changed. No script runs for
    /// this, and each card shows its header until its answer arrives. A file that gives no spot shows a card of its faults,
    /// and any other fault shows in a toast. With no file changed and the same config as the last time, it only holds the
    /// keys again.
    public func reload() {
        host.applyConfig()
        let config = files.config.read()
        let folder = files.folder(config)
        let shipped = host.shippedSpots(folder: folder, config: files.config, update: updateSpot, offersLogin: isFirstLaunch)
            + (reviewed.map { [ShippedSpot.command(reviewing: $0)] } ?? [])
        var scan = pluginScan.look(at: folder, shipped: shipped)
        let new = shipped.lazy.compactMap { if case .new(let new)? = $0.shipped { new } else { nil } }.first
        let faults = new.map { folder.faultSpots(of: scan, new: $0) } ?? []
        if !faults.isEmpty { scan.plugins.append(Plugin(id: ShippedSpot.faultsID, commands: faults)) }
        guard pluginScan.stamp != loadedStamp || config != loadedConfig else { return holdAssignedKeys(config) }
        let carded = Set(faults.map(\.id))
        let problems = scan.refused.filter { !carded.contains($0.file) }.map { "\($0.file) was not loaded: \($0.reason)" }
        runs.take(scan)
        lastScan = scan
        loadedStamp = pluginScan.stamp
        loadedConfig = config
        fileStamps = Self.stamps(of: scan)
        holdAssignedKeys(config)
        arrangement = config.arrangement
        scanned = scan.commands
        rebuildEntries()
        if problems != self.problems, !problems.isEmpty {
            host.notify(problems.joined(separator: " "))
        }
        self.problems = problems
    }

    /// Takes a change of the plugins folder, such as an agent that writes a spot: the cards change at once, with no motion,
    /// the selected card stays selected, and a changed script that the open panel reads at `panel` reads again.
    public func folderChanged() {
        let stamps = fileStamps
        let id = selectedEntry?.id
        reload()
        if let position = visible.firstIndex(where: { $0.id == id }) { selected = position }
        guard isShown else { return }
        for entry in entries where entry.command.read?.has(.panel) == true && fileStamps[entry.id] != stamps[entry.id] {
            sheets[entry.id]?.read(need: .change)
        }
    }

    /// The stamp of each script file of the last scan: its date of change and its file number, which a rewrite changes.
    private static func stamps(of scan: ScanResult) -> [String: String] {
        var stamps: [String: String] = [:]
        for script in scan.scripts where script.shipped == nil {
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

    /// Brings the grid up to date while a sheet covers it, so that the sheet closes onto the card's real place. The selected
    /// card stays selected.
    private func reloadUnderSheet() {
        spotsChanged = false
        let id = selectedEntry?.id
        reload()
        if let position = visible.firstIndex(where: { $0.id == id }) { selected = position }
    }

    public func rebuildEntries() {
        entries = ordered().map { Entry(command: $0, run: runs.sheets[$0.id], choice: arrangement) }
    }

    /// The scanned spots in their grid order, and the person's order in the config over it.
    private func ordered() -> [Spot] {
        let sorted = scanned.enumerated().sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }.map(\.element)
        return arrangement.ordered(sorted)
    }

    /// The panel starts to show: a pick that its fade left finishes, the first card is selected, the held keys count, the
    /// plugin folder is read again if it changed, and each script that the panel shows reads. The panel says it shows on the
    /// next turn, so that its fade starts from hidden.
    public func panelWillShow(holding modifiers: Shortcut.Modifiers) {
        finishPick()
        selected = 0
        takeHeld(modifiers)
        reload()
        runs.panelOpened()
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

    /// A moment of the Mac arrived, such as a wake.
    public func arrive(_ moment: SpotRead.Moment) {
        runs.arrive(moment)
    }

    /// A downloaded update waits, so the Updates spot reads now and is on the grid before the panel next opens.
    public func updateIsReady() {
        sheets.values.first { if case .updates? = $0.command.shipped { true } else { false } }?.read(need: .change)
    }

    /// Stops each call as the app quits.
    public func quit() {
        runs.quit()
    }

    private func holdAssignedKeys(_ config: Config) {
        host.hold(lastScan.offered(config.keys))
    }

    /// A person pressed a key that they assigned to a command.
    public func press(_ key: GlobalKey) {
        guard case .command(let command) = key.act else { return float(key.spot) }
        guard let sheet = sheets[key.spot] else { return }
        sheet.pressKey(command)
        flashSymbol = sheet.command.symbol(of: command)
        flashWatch?.cancel()
        flashWatch = Task { [weak self, flashPause] in
            try? await Task.sleep(for: flashPause)
            if !Task.isCancelled { self?.flashSymbol = nil }
        }
    }

    private func take(_ report: SpotRun.Report, of id: String) {
        switch report {
        case .toast(let text): host.confirm(text)
        case .failure(let text): host.notify(text)
        case .failureWithFix(let text, let fix): host.notify(text, fix: fix)
        case .listChange:
            updateVisible()
        case .frame:
            if sheets[id]?.command.setsKeys == true {
                host.applyConfig()
                holdAssignedKeys(files.config.read())
            }
            if spotsChanged, id == ShippedSpot.spotsID { reloadUnderSheet() }
        case .landed:
            host.land(id)
        case .closed:
            if let shown = openList, runs.sheets[shown]?.isOpen != true { showSheet(nil, moving: false) }
        case .chooseFiles:
            if let sheet = sheets[id] { host.chooseFiles(for: sheet.command) { sheet.drop($0) } }
        }
    }

    public static func reason(_ error: Error) -> String {
        (error as? PluginError)?.reason ?? error.localizedDescription
    }

    /// The entries that have a card. The install screen has none.
    public var cards: [Entry] {
        entries.filter { $0.id != ShippedSpot.installID }
    }

    /// The most rows that the main search shows from a list that the person never picked from.
    private static let unpickedRows = 3

    /// Shows the spots that the search finds and the items it finds in the lists that offer them, in one ranking.
    public func updateVisible() {
        let next = found()
        if next != visible { visible = next }
        let sizes = visible.map(\.size)
        if sizes != laidOutSizes {
            laidOutSizes = sizes
            placements = SpotGrid().place(sizes)
        }
        if transition.phase == .closing, !hasPlace(transition.id) { cutSheet(to: nil) }
    }

    /// The cards that the search finds, or each card on the grid when there is no search.
    private func found() -> [Entry] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            return cards.filter(\.isOnGrid) + (isEditing ? cards.filter { !$0.isOnGrid } : [])
        }
        let spots = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        spotList.replace(cards.filter(\.command.isFound).map { SpotItem(title: $0.state.title, subtitle: [$0.state.subtitle, $0.command.name].compactMap { $0 }.joined(separator: " "), run: $0.id) })
        let sources = entries.filter { $0.command.isGlobal && arrangement.isGlobal(of: $0.id) != false }
        let found = SearchQuery(text: text).matching(in: [spotList] + sources.map { sheets[$0.id]?.list ?? ItemList() }, unpickedLimit: Self.unpickedRows, limit: Self.searchLimit)
        return found.compactMap { match in
            match.list == 0 ? spots[match.item.run] : Entry(command: sources[match.list - 1].command, item: match.item)
        }
    }

    public func moveSelection(dx: Int, dy: Int) {
        if let next = SpotGrid().neighbour(of: selected, in: placements, dx: dx, dy: dy) {
            selected = next
        }
    }

    public var selectedIsSlider: Bool {
        selectedEntry?.kind == .slider
    }

    public func adjustSelected(by delta: Double) {
        guard let entry = selectedEntry, entry.kind == .slider else { return }
        sheets[entry.id]?.setLevel((entry.state.level ?? 0) + delta)
    }

    public func tap(_ id: String) {
        guard let position = visible.firstIndex(where: { $0.id == id }) else { return }
        selected = position
        runSelected()
    }

    public func setLevel(_ id: String, to value: Double) {
        sheets[id]?.setLevel(value)
    }

    /// Sends a change or a press of a component that a card draws (U5).
    public func setCardPart(_ id: String, _ part: String, to value: String?) {
        sheets[id]?.setCardPart(part, to: value)
    }

    public func runSelected() {
        guard !isEditing else { return }
        if openList != nil {
            runSelectedItem()
            return
        }
        guard let entry = selectedEntry else { return }
        run(entry)
    }

    /// Runs a command by its key, with the panel open only when its spot needs it.
    public func press(_ id: String) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        if let sheet = sheets[id], sheet.awaitsAnswer {
            sheet.afterAnswer { [weak self] in self?.press(id) }
            return
        }
        guard entry.kind.opensSheet else {
            run(entry)
            return
        }
        let moving = isShown
        host.show()
        open(id, moving: moving)
    }

    /// Notes which modifiers the person holds. The letters show once they have matched the entry key for a moment, so that
    /// a quick press shows nothing.
    public func takeHeld(_ modifiers: Shortcut.Modifiers) {
        chainWatch?.cancel()
        guard modifiers == entryKey.modifiers else {
            isChainHeld = false
            return
        }
        chainWatch = Task { [weak self] in
            try? await Task.sleep(for: Self.chainPause)
            if !Task.isCancelled { self?.isChainHeld = true }
        }
    }

    /// Whether the spots show their letters.
    public var showsChain: Bool {
        isChainHeld && isOnGrid
    }

    /// The letter of a spot that has a key.
    public func chainLetter(of entry: Entry) -> String? {
        entry.item == nil ? entry.command.key?.name.uppercased() : nil
    }

    private var isOnGrid: Bool {
        menu == nil && form == nil && openList == nil && !isEditing
    }

    /// Runs the spot whose letter this press holds, whatever the search shows. A spot with no sheet closes the panel.
    public func handleChain(code: UInt32, modifiers: Shortcut.Modifiers) -> Bool {
        guard isOnGrid, let entry = entries.first(where: { entry in
            entry.command.key.map { entryKey.chains(to: $0, code: code, modifiers: modifiers) } ?? false
        }) else { return false }
        press(entry.id)
        if entry.kind == .toggle { host.dismiss() }
        return true
    }

    public func run(_ entry: Entry) {
        if let item = entry.item, let list = entries.first(where: { $0.id == entry.command.id }) {
            if item.shortcut != nil, openList != list.id {
                open(list.id, moving: true)
            }
            pick(item, of: list)
            return
        }
        if let sheet = sheets[entry.id], sheet.awaitsAnswer {
            sheet.afterAnswer { [weak self] in self?.run(entry) }
            return
        }
        switch entry.kind {
        case .toggle:
            sheets[entry.id]?.pressCard()
        case .launch:
            if isShown, sheets[entry.id]?.isCardRunning != true, !entry.command.takesDrops { host.dismiss() }
            sheets[entry.id]?.pressCard()
        case .list:
            if openList == entry.id {
                closeList(moving: true)
            } else {
                open(entry.id, moving: true)
            }
        case .slider:
            break
        case .widget:
            if let opens = entry.command.opens { press(opens) }
        }
    }

    /// The marks of the scripts that show in the menu bar, by script.
    public var trayMarks: [(id: String, mark: TrayMark)] {
        runs.trayMarks
    }

    /// What the Openspot item shows for running work.
    public var workMark: TrayMark? {
        runs.workMark
    }

    /// Opens the panel with the spot of the oldest running work selected, or closes it when it already shows that. A search
    /// stays, so a spot that it hides is not selected. Returns false when no work shows.
    public func openWork() -> Bool {
        guard let id = runs.workSpot else { return false }
        let spot = { self.visible.firstIndex { $0.id == id || $0.command.places.contains(id) } }
        if isShown, openList == nil, spot() == selected {
            host.dismiss()
            return true
        }
        closeList(moving: isShown)
        host.show()
        if let spot = spot() { selected = spot }
        return true
    }

    /// The running call of a part of the open sheet.
    public func work(of part: SpotPart) -> ScriptCall? {
        openSheet?.work(of: part)
    }

    /// The running call that a press of this row of the open menu stops.
    public func work(of row: ActionMenu.Row) -> ScriptCall? {
        if row.opensEdit { return nil }
        return menuTarget.flatMap { sheets[$0.entry.id]?.work(of: row, item: $0.item) }
    }

    /// Opens the list of a metric that is also a list, or else selects the widget that places it. Closes the panel
    /// when it already shows that.
    public func openFromTray(_ id: String) {
        let opens = entries.first { $0.id == id && $0.kind.opensSheet }?.id
        if isShown, opens == nil || openList == opens {
            host.dismiss()
        } else if let opens {
            press(opens)
        } else {
            closeList(moving: isShown)
            host.show()
            selected = visible.firstIndex { $0.command.places.contains(id) } ?? 0
        }
    }

    public func openBigView() {
        guard let entry = selectedEntry else { return }
        host.notify("\(entry.state.title) has no big view yet.")
    }

    public var selectedEntry: Entry? {
        let list = visible
        guard list.indices.contains(selected) else { return nil }
        return list[selected]
    }

    /// Whether the search field keeps the keys: no form, no Edit Spots and no shown sheet of parts with no rows takes them.
    /// It follows the parts that show, so that the focus stays put while a sheet moves. A form of one choice keeps it, to
    /// search the rows of its options.
    public var showsSearch: Bool {
        if let form { return form.draft.choices != nil && !isEditing }
        return !isEditing && openPanel?.kind.takesKeys != false
    }

    public var openPanel: SheetParts? {
        shownParts(of: openList)
    }

    /// The parts that the sheet of a spot shows: none while a form of that spot takes their place.
    public func shownParts(of id: String?) -> SheetParts? {
        guard let id, form?.entry.id != id else { return nil }
        return sheets[id]?.panel
    }

    public var openSheet: SpotRun? {
        openList.flatMap { sheets[$0] }
    }

    public var openEntry: Entry? {
        entries.first { $0.id == openList }
    }

    public var openItems: ItemList? {
        openSheet?.list
    }

    /// The text of the field: the search of the open list, or else the search of the spots.
    public var searchText: String {
        get { form?.draft.choices?.query ?? openItems?.query ?? query }
        set {
            if form?.draft.choices != nil {
                form?.draft.search(newValue)
            } else if let file = SharedSpot.file(in: newValue) {
                query = ""
                openSheet?.search("")
                DispatchQueue.main.async { self.review([file]) }
            } else if let openSheet {
                openSheet.search(newValue)
            } else {
                query = newValue
            }
        }
    }

    /// Clears the search, or else closes the open list. Returns false when there is nothing to step back from.
    public func stepBack() -> Bool {
        if !searchText.isEmpty {
            searchText = ""
        } else if openList != nil {
            closeList(moving: isShown)
        } else {
            return false
        }
        return true
    }

    public func openSettings() {
        open(ShippedSpot.settingsID, moving: true)
    }

    /// Opens a sheet, which closes the run of the sheet before and stops a recording in it, and shows it once it is ready: at
    /// once, or with its first answer. It takes the place of a sheet that shows, grows out of its card when it moves, and
    /// shows in place when it does not move or has no card.
    public func open(_ id: String, moving: Bool) {
        if let shown = openList, shown != id { stopRecording() }
        sheets[id]?.open(waits: moving) { [weak self] in self?.showSheet(id, moving: moving) }
    }

    /// Closes the open sheet: back into its card when it moves, or at once.
    public func closeList(moving: Bool) {
        formAsk = nil
        stopRecording()
        showSheet(nil, moving: moving)
        runs.closeOpen()
    }

    /// Closes each sheet of parts when the panel has faded, and stops the reads that nothing wants now. A sheet of rows stays
    /// open.
    public func panelDidHide() {
        finishPick()
        runs.panelClosed()
        if isFirstLaunch, !isWarming {
            isFirstLaunch = false
            host.confirm(entryKey.openHint)
        }
        endReview()
    }

    /// Starts the motion of the sheet to `list`. A sheet that opens while another shows takes its place, on the sheet's
    /// spring when it moves. Else a sheet grows out of its card and collapses back into it, and one that does not move or has
    /// no card shows and hides at once. A new sheet is built on its card first, and its grow starts on the next turn, so
    /// that the grow has a start.
    private func showSheet(_ list: String?, moving: Bool) {
        guard list != openList else { return }
        if let list, openList != nil, transition.isOpen {
            change(moving ? .sheet(isOpen: true) : nil, { transition.show(list, moves: true) }) { [weak self] in
                self?.change(nil) { self?.transition.settle(list) }
            }
            return
        }
        guard moving, hasPlace(list ?? transition.id) else { return cutSheet(to: list) }
        guard let list else {
            animate(isOpen: false) {
                transition.hide(moves: true)
                holdFieldDrop()
            }
            return
        }
        change(nil) {
            transition.show(list, moves: true)
            holdFieldDrop()
        }
        DispatchQueue.main.async { [weak self] in
            self?.animate(isOpen: true) { self?.transition.start() }
        }
    }

    /// Shows or hides the sheet at once, with no motion.
    private func cutSheet(to list: String?) {
        change(nil) {
            if let list { transition.show(list, moves: false) } else { transition.hide(moves: false) }
            fieldDrop = nil
            showsFieldDrop = false
        }
        if list == nil { endReview() }
    }

    /// Whether the built sheet has a place to close into: its card on the grid, or the field for the install screen.
    private func hasPlace(_ id: String?) -> Bool {
        guard let id else { return false }
        return id == ShippedSpot.installID || SpotSheetCard.of(id, in: self) != nil
    }

    /// Moves the sheet on its spring, in one transaction, and ends the motion when it is done. The words of a review leave
    /// the field at once when its sheet is open, and fade when it has closed into the field.
    private func animate(isOpen: Bool, _ body: () -> Void) {
        var motion = 0
        change(.sheet(isOpen: isOpen), {
            body()
            motion = transition.motion
        }) { [weak self] in
            guard let self else { return }
            let isInstall = transition.id == ShippedSpot.installID
            change(nil) {
                self.transition.finish(motion)
                if isInstall, self.transition.phase == .open {
                    self.fieldDrop = nil
                    self.showsFieldDrop = false
                }
            }
            if isInstall, transition.phase == .closed { hideFieldDrop() }
            if transition.phase == .closed { endReview() }
        }
    }

    /// Keeps the words of a review in the field, where they lie under the sheet's header as the sheet grows out of the field or
    /// collapses back into it.
    private func holdFieldDrop() {
        guard let drop = reviewDrop else { return }
        fieldDrop = drop
        showsFieldDrop = true
    }

    /// Shows the words of a dragged `.spot` file in the field on the sheet's spring, and gives the field back its search when
    /// the drag leaves, unless a review holds them.
    private func followSpotDrop(from old: SpotDrop?) {
        guard spotDrop != old else { return }
        if let drop = spotDrop {
            change(.sheet(isOpen: true)) {
                fieldDrop = drop
                showsFieldDrop = true
            }
        } else if !isReviewing {
            hideFieldDrop()
        }
    }

    /// Gives the field back its search on the sheet's closing spring, and lets the words go when they have faded.
    private func hideFieldDrop() {
        change(.sheet(isOpen: false), { showsFieldDrop = false }) { [weak self] in
            guard let self, !showsFieldDrop else { return }
            fieldDrop = nil
        }
    }

    /// Brings a sheet its first parts: on the sheet's spring when the sheet shows, so that it grows to its new size, and at
    /// once when it does not.
    private func bringParts(of id: String, _ bring: () -> Void) {
        change(transition.id == id && transition.isOpen ? PanelMotion.sheet(isOpen: true) : nil, bring)
    }

    /// Makes a change on an animation, or with none at all, and calls `completion` when its motion has ended.
    public func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void = {}) {
        host.change(motion, body, completion: completion)
    }

    public func moveItem(by step: Int) {
        openSheet?.list.move(by: step)
    }

    public func moveItemLine(by lines: Int) {
        openSheet?.list.moveLine(by: lines)
    }

    public func runSelectedItem() {
        guard let item = openItems?.selectedItem else {
            createFromSearch()
            return
        }
        runItem(item)
    }

    /// The action that makes a new item from what the search did not find.
    public var createAction: CommandAction? {
        guard let list = openItems, !list.query.isEmpty, list.shown.isEmpty, list.search == .local else { return nil }
        return openEntry?.command.actions.first { $0.scope == .command && $0.isForm }
    }

    public func createFromSearch() {
        guard let action = createAction, let entry = openEntry else { return }
        openForm(action, on: (entry, nil), prefill: openItems?.query ?? "")
    }

    /// Sends a change of a slot of a row of a spot, or a press of one when it has no value (U9).
    public func slot(_ slot: String, of item: SpotItem, in id: String, to value: String?) {
        if let value { sheets[id]?.set(slot: slot, of: item, to: value) } else { sheets[id]?.press(slot: slot, of: item) }
    }

    public func runItem(_ item: SpotItem) {
        guard let entry = openEntry else { return }
        pick(item, of: entry)
    }

    /// Records a pick and clears what it left open, once the panel has faded, so nothing moves during the fade.
    public func finishPick() {
        guard let pick = closingPick else { return }
        closingPick = nil
        remember(pick.item, of: pick.entry)
        closeList(moving: false)
    }

    /// Records a pick as recent, for a spot that keeps its recent picks.
    private func remember(_ item: SpotItem, of entry: Entry) {
        guard entry.command.keepsRecent, let sheet = sheets[entry.id] else { return }
        sheet.list.remember(item)
        files.remember(sheet.list.recent, of: entry.id)
    }

    /// Runs a pick of a row, or an action on it. In the panel, a pick that closes it closes the panel. A float stays open
    /// with the picked row selected, and a pick that asks with a form or records a key opens the spot in the panel (W8).
    public func pick(_ item: SpotItem, of entry: Entry, action: CommandAction? = nil, in place: SheetPlace = .panel) {
        if place == .float {
            if action == nil, entry.command.pickForm != nil || item.shortcut != nil { return press(entry.id) }
            remember(item, of: entry)
            sheets[entry.id]?.list.select(run: item.run)
        } else {
            if action == nil, item.run == CatalogSpot.buildRun {
                open(ShippedSpot.newID, moving: true)
                return
            }
            if entry.id == ShippedSpot.spotsID, action == nil { spotsChanged = true }
            if action == nil, item.shortcut != nil {
                toggleRecording(id: item.run)
                return
            }
            if action == nil, case .settings? = entry.command.shipped, let change = SettingsSpot.change(of: item.run) {
                changeSetting(of: change.spot, with: change.action)
                return
            }
            if action == nil, let form = entry.command.pickForm {
                openForm(form, on: (entry, item))
                return
            }
            if action != nil || entry.command.pick == .close {
                closingPick = (item, entry)
                if isShown {
                    host.dismiss()
                } else {
                    finishPick()
                }
            }
        }
        if let action {
            sheets[entry.id]?.run(action, item: item)
        } else {
            sheets[entry.id]?.pick(item)
        }
    }
}
