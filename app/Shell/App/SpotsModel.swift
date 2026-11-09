import AppKit
import OpenspotCore
import SwiftUI

@MainActor
@Observable
final class SpotsModel {
    /// One card: a script, which reads from its sheet, or a widget, or a row that the main search found.
    struct Entry: Identifiable {
        let id: String
        let item: SpotItem?
        private let sizeChoice: SpotSize?
        private let sheet: SpotRun?
        private let fixedCommand: Spot
        private let fixedState: SpotState
        private let gridChoice: Bool?

        init(command: Spot, sheet: SpotRun?, choice: SpotArrangement = SpotArrangement()) {
            id = command.id
            sizeChoice = choice.size(of: command.id)
            gridChoice = choice.isOnGrid(of: command.id)
            item = nil
            self.sheet = sheet
            fixedCommand = command
            fixedState = command.headerState
        }

        /// A card of a full row for an item that the main search found in a list.
        init(command: Spot, item: SpotItem) {
            id = "\(command.id)\n\(item.run)"
            sizeChoice = .strip
            gridChoice = nil
            self.item = item
            sheet = nil
            fixedCommand = command
            fixedState = SpotState(title: item.title, subtitle: item.path(in: command))
        }

        @MainActor var command: Spot {
            sheet?.command ?? fixedCommand
        }

        /// The size of its card: the person's choice, or else what its last read says, or else its header (F9).
        @MainActor var size: SpotSize {
            sizeChoice ?? state.size ?? command.size
        }

        /// Whether the grid shows it: the person's choice, or else what the spot says.
        @MainActor var isOnGrid: Bool {
            gridChoice ?? state.isOnGrid
        }

        @MainActor var kind: SpotKind {
            item == nil ? command.kind : .launch
        }

        @MainActor var symbol: String {
            item?.symbol ?? command.symbol
        }

        /// Whether the card draws the image, the file icon or the glyph that its header names, in place of a symbol.
        @MainActor var showsHeaderPicture: Bool {
            item?.symbol == nil && (command.icon != nil || command.glyph != nil)
        }

        @MainActor var state: SpotState {
            sheet?.state ?? fixedState
        }

        /// What the card shows: its own state, with the words of its running work over it.
        @MainActor var shownState: SpotState {
            sheet?.shownState ?? fixedState
        }

        /// The running work that its glyph shows.
        @MainActor var work: ScriptCall? {
            sheet?.work.first
        }

        /// Whether a press of the card stops its running work.
        @MainActor var stopsOnPress: Bool {
            sheet?.cardWork != nil
        }
    }

    /// A form open in a sheet, with the action that asked for it. Its text stays when the panel closes.
    struct FormSession {
        var draft: FormDraft
        let entry: Entry
        let action: CommandAction
        let item: SpotItem?
        let openedSheet: Bool
    }

    typealias Target = (entry: Entry, item: SpotItem?)

    private static let searchLimit = 8
    static let pluginFolder = PluginFolder.standard()
    static let dragWatchPause: Duration = .milliseconds(16)
    private static let chainPause: Duration = .milliseconds(200)
    private static let loadLimit: Duration = .seconds(2)
    private static let loadPause: Duration = .milliseconds(20)
    static let dropPause: Duration = .milliseconds(300)

    var entries: [Entry] = [] {
        didSet { updateVisible() }
    }
    var query = "" {
        didSet {
            if query != oldValue { selected = 0 }
            updateVisible()
        }
    }
    private(set) var visible: [Entry] = [] {
        didSet {
            let sizes = visible.map(\.size)
            if sizes != placements.map(\.size) { placements = SpotGrid().place(sizes) }
            if transition.phase == .closing, !sheetHasClosedPlace { cutSheet(to: nil) }
        }
    }
    /// The cards as the items that the main search finds. It folds them again only when they change.
    @ObservationIgnored private var spotList = ItemList()
    /// Where each visible spot lies on the grid, in the order of `visible`.
    private(set) var placements: [SpotPlacement] = []
    var selected = 0
    /// The sheet that is open. A change of it starts the sheet's motion in the same transaction.
    var openList: String? {
        get { shownList }
        set {
            if newValue != shownList { moveSheet(to: newValue) }
        }
    }
    private var shownList: String?
    var sheetMoves = true
    /// Where the open sheet is in its motion between its card and its open place.
    private(set) var transition = SheetTransition()
    var closingPick: (item: SpotItem, entry: Entry)?
    let runs: SpotRuns
    /// The plugins' own views that cards draw.
    let views = SpotViews()
    var dragWatch: Task<Void, Never>?
    var dragPaths: [String] = []
    var draggedSpot: SpotDrop? {
        didSet { followSpotDrop(from: isPointerOverDrop ? oldValue : nil) }
    }
    var isPointerOverDrop = false {
        didSet { followSpotDrop(from: oldValue ? draggedSpot : nil) }
    }
    /// The file whose words the field shows in place of its search: a dragged `.spot` file, or the file of a review while its
    /// sheet grows out of the field or collapses back into it. It stays while its words fade out.
    var fieldDrop: SpotDrop?
    /// Whether the field shows the words of `fieldDrop`.
    var showsFieldDrop = false
    /// Whether the pointer lies on the panel or the menu bar item.
    var pointerIsOverDrop: () -> Bool = { false }
    /// The shared spot that the open review shows, which exists only as long as that sheet.
    var reviewed: ReviewSpot?
    var isFirstLaunch = false
    var spotsChanged = false
    var isShown = false
    /// Whether the app is opening the panel unseen as it starts, which a press of the key ends.
    var isWarming = false
    /// Whether a drag over the menu bar item opened the panel, so that it is not key and its field takes no focus.
    var isOpenForDrag = false
    var updateSpot: UpdateSpot?

    var chooseFiles: (Spot, @escaping ([String]) -> Void) -> Void = { _, _ in }
    var entryKey = Shortcut.standard
    private var isChainHeld = false
    private var chainWatch: Task<Void, Never>?
    var recording: String?
    var setEntryKeyOn: (Bool) -> Void = { _ in }
    var holdKeys: ([GlobalKey]) -> Void = { _ in }
    var dismiss: () -> Void = {}
    var show: () -> Void = {}
    var present: () -> Void = {}
    var notify: (String) -> Void = { _ in }
    var notifyFix: (String, URL) -> Void = { _, _ in }
    var notifyKeyFault: (String) -> Void = { _ in }
    var applyConfig: () -> Void = {}
    var confirm: (String) -> Void = { _ in }
    private var problems: [String] = []
    var menu: ActionMenu?
    var menuTarget: Target?
    var form: FormSession?
    /// Whether the grid is in Edit Spots, where it also shows the spots that are off the grid, and a press only selects.
    var isEditing = false
    var arrangement = SpotArrangement()
    private var scanned: [Spot] = []
    private var lastScan = ScanResult(plugins: [], refused: [])

    init() {
        runs = SpotRuns(
            recent: { UserDefaults.standard.stringArray(forKey: Self.recentKey($0)) ?? [] },
            prepare: { await SpotIconStore.shared.prepare($0) }
        )
        runs.onReport = { [weak self] id, report in self?.take(report, of: id) }
        runs.partsArrival = { [weak self] id, bring in
            guard let self else { return bring() }
            bringParts(of: id, bring)
        }
    }

    var sheets: [String: SpotRun] {
        runs.sheets
    }

    /// What each script last gave a widget to draw.
    var readings: [String: MetricReading] {
        runs.readings
    }

    /// The number of calls that a restart would stop.
    var workCount: Int {
        runs.work.count
    }

    /// Opens the panel on the grid, once, for a person who has no spots yet. The toast with the key waits for the panel to
    /// close.
    func beginFirstLaunch() {
        isFirstLaunch = true
        try? ConfigFile.standard().begin(enabling: Self.pluginFolder.startingSpots())
        reload()
        present()
    }

    /// Reads the config file and the plugin folder again. No script runs for this, and each card shows its header until its
    /// answer arrives.
    func reload() {
        applyConfig()
        let folder = PluginFolder.standard()
        let shipped = ShippedSpot.commands(
            folder: folder.url,
            guide: Bundle.main.url(forResource: "GUIDE", withExtension: "md") ?? folder.url,
            app: Bundle.main.executablePath ?? "",
            update: updateSpot,
            core: folder.core,
            login: AppLogin.item,
            link: AppCommandLink.item,
            offersLogin: isFirstLaunch,
            quit: QuitSpot { await NSApp.terminate(nil) }
        ) + (reviewed.map { [ShippedSpot.command(reviewing: $0)] } ?? [])
        let scan = (try? folder.scan(shipped: shipped)) ?? ScanResult(plugins: [Plugin(id: "openspot", commands: shipped)], refused: [])
        let problems = scan.refused.map { "\($0.file) was not loaded: \($0.reason)" }
        runs.take(scan)
        lastScan = scan
        holdAssignedKeys()
        arrangement = ConfigFile.standard().read().arrangement
        scanned = scan.commands
        rebuildEntries()
        if problems != self.problems, !problems.isEmpty {
            notify(problems.joined(separator: " "))
        }
        self.problems = problems
    }

    /// Brings the grid up to date while a sheet covers it, so that the sheet closes onto the card's real place. The selected
    /// card stays selected.
    private func reloadUnderSheet() {
        spotsChanged = false
        let id = selectedEntry?.id
        reload()
        if let position = visible.firstIndex(where: { $0.id == id }) { selected = position }
    }

    func rebuildEntries() {
        entries = ordered().map { Entry(command: $0, sheet: runs.sheets[$0.id], choice: arrangement) }
    }

    /// The scanned spots in their grid order, and the person's order in the config over it.
    private func ordered() -> [Spot] {
        let sorted = scanned.enumerated().sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }.map(\.element)
        return arrangement.ordered(sorted)
    }

    /// Looks at the plugin folder and asks each script that the panel shows, at the same time.
    func panelWillShow() {
        reload()
        runs.panelOpened()
    }

    /// Waits for the reads of the open panel, up to the limit of a load at launch.
    func waitForReads() async {
        let end = ContinuousClock.now + Self.loadLimit
        while runs.isReading, ContinuousClock.now < end {
            try? await Task.sleep(for: Self.loadPause)
        }
    }

    /// A moment of the Mac arrived, such as a wake.
    func arrive(_ moment: SpotRead.Moment) {
        runs.arrive(moment)
    }

    /// A downloaded update waits, so the Updates spot reads now and is on the grid before the panel next opens.
    func updateIsReady() {
        sheets.values.first { if case .updates? = $0.command.shipped { true } else { false } }?.read(need: .change)
    }

    /// Stops each call as the app quits.
    func quit() {
        runs.quit()
    }

    private func holdAssignedKeys() {
        holdKeys(lastScan.offered(ConfigFile.standard().read().keys))
    }

    /// A person pressed a key that they assigned to a command.
    func press(_ key: GlobalKey) {
        sheets[key.spot]?.pressKey(key.command)
    }

    private func take(_ report: SpotRun.Report, of id: String) {
        switch report {
        case .toast(let text): confirm(text)
        case .failure(let text): notify(text)
        case .failureWithFix(let text, let fix): notifyFix(text, fix)
        case .listChange:
            if visible.map(\.size) != placements.map(\.size) || !query.isEmpty || isEditing || cards.first(where: { $0.id == id }).map({ $0.isOnGrid != visible.contains { $0.id == id } }) == true { updateVisible() }
        case .frame:
            if sheets[id]?.command.setsKeys == true {
                applyConfig()
                holdAssignedKeys()
            }
            if spotsChanged, id == ShippedSpot.spotsID { reloadUnderSheet() }
        case .chooseFiles:
            if let sheet = sheets[id] { chooseFiles(sheet.command) { sheet.drop($0) } }
        }
    }

    private static func recentKey(_ id: String) -> String {
        "recent.\(id)"
    }

    static func reason(_ error: Error) -> String {
        (error as? PluginError)?.reason ?? error.localizedDescription
    }

    /// The entries that have a card. The install screen has none.
    var cards: [Entry] {
        entries.filter { $0.id != ShippedSpot.installID }
    }

    /// The most rows that the main search shows from a list that the person never picked from.
    private static let unpickedRows = 3

    /// Shows the spots that the search finds and the items it finds in the lists that offer them, in one ranking.
    func updateVisible() {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            visible = cards.filter(\.isOnGrid) + (isEditing ? cards.filter { !$0.isOnGrid } : [])
            return
        }
        let spots = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        spotList.replace(cards.filter(\.command.isFound).map { SpotItem(title: $0.state.title, subtitle: [$0.state.subtitle, $0.command.name].compactMap { $0 }.joined(separator: " "), run: $0.id) })
        let sources = entries.filter { $0.command.isGlobal && arrangement.isGlobal(of: $0.id) != false }
        let found = SearchQuery(text: text).matching(in: [spotList] + sources.map { sheets[$0.id]?.list ?? ItemList() }, unpickedLimit: Self.unpickedRows)
        visible = found.prefix(Self.searchLimit).compactMap { match in
            match.list == 0 ? spots[match.item.run] : Entry(command: sources[match.list - 1].command, item: match.item)
        }
    }

    func moveSelection(dx: Int, dy: Int) {
        if let next = SpotGrid().neighbour(of: selected, in: placements, dx: dx, dy: dy) {
            selected = next
        }
    }

    var selectedIsSlider: Bool {
        selectedEntry?.kind == .slider
    }

    func adjustSelected(by delta: Double) {
        guard let entry = selectedEntry, entry.kind == .slider else { return }
        sheets[entry.id]?.setLevel((entry.state.level ?? 0) + delta)
    }

    func tap(_ id: String) {
        guard let position = visible.firstIndex(where: { $0.id == id }) else { return }
        selected = position
        runSelected()
    }

    func setLevel(_ id: String, to value: Double) {
        sheets[id]?.setLevel(value)
    }

    /// Sends a change or a press of a component that a card draws (U5).
    func setCardPart(_ id: String, _ part: String, to value: String?) {
        sheets[id]?.setCardPart(part, to: value)
    }

    func runSelected() {
        guard !isEditing else { return }
        if openList != nil {
            runSelectedItem()
            return
        }
        guard let entry = selectedEntry else { return }
        run(entry)
    }

    /// Runs a command by its key, with the panel open only when its spot needs it.
    func press(_ id: String) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        if let sheet = sheets[id], sheet.awaitsAnswer {
            sheet.afterAnswer { [weak self] in self?.press(id) }
            return
        }
        guard entry.kind.opensSheet else {
            run(entry)
            return
        }
        sheetMoves = isShown
        show()
        open(id)
    }

    /// Notes which modifiers the person holds. The letters show once they have matched the entry key for a moment, so that
    /// a quick press shows nothing.
    func takeHeld(_ modifiers: Shortcut.Modifiers) {
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
    var showsChain: Bool {
        isChainHeld && isOnGrid
    }

    /// The letter of a spot that has a key.
    func chainLetter(of entry: Entry) -> String? {
        entry.item == nil ? entry.command.key?.name.uppercased() : nil
    }

    private var isOnGrid: Bool {
        menu == nil && form == nil && openList == nil && !isEditing
    }

    /// Runs the spot whose letter this press holds, whatever the search shows. A spot with no sheet closes the panel.
    func handleChain(code: UInt32, modifiers: Shortcut.Modifiers) -> Bool {
        guard isOnGrid, let entry = entries.first(where: { entry in
            entry.command.key.map { entryKey.chains(to: $0, code: code, modifiers: modifiers) } ?? false
        }) else { return false }
        press(entry.id)
        if entry.kind == .toggle { dismiss() }
        return true
    }

    func run(_ entry: Entry) {
        if let item = entry.item, let list = entries.first(where: { $0.id == entry.command.id }) {
            if item.shortcut != nil, openList != list.id {
                sheetMoves = true
                open(list.id)
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
            if isShown, sheets[entry.id]?.isCardRunning != true, !entry.command.takesDrops { dismiss() }
            sheets[entry.id]?.pressCard()
        case .list:
            sheetMoves = true
            if openList == entry.id {
                closeList()
            } else {
                open(entry.id)
            }
        case .slider:
            break
        case .widget:
            if let opens = entry.command.opens { press(opens) }
        }
    }

    /// The marks of the scripts that show in the menu bar, by script.
    var trayMarks: [(id: String, mark: TrayMark)] {
        runs.trayMarks
    }

    /// What the Openspot item shows for running work.
    var workMark: TrayMark? {
        runs.workMark
    }

    /// Opens the panel with the spot of the oldest running work selected, or closes it when it already shows that. A search
    /// stays, so a spot that it hides is not selected. Returns false when no work shows.
    func openWork() -> Bool {
        guard let id = runs.workSpot else { return false }
        let spot = { self.visible.firstIndex { $0.id == id || $0.command.places.contains(id) } }
        if isShown, openList == nil, spot() == selected {
            dismiss()
            return true
        }
        closeList()
        show()
        if let spot = spot() { selected = spot }
        return true
    }

    /// The running call of a part of the open sheet.
    func work(of part: SpotPart) -> ScriptCall? {
        openSheet?.work(of: part)
    }

    /// The running call that a press of this row of the open menu stops.
    func work(of row: ActionMenu.Row) -> ScriptCall? {
        if row.opensEdit { return nil }
        return menuTarget.flatMap { sheets[$0.entry.id]?.work(of: row, item: $0.item) }
    }

    /// Opens the list of a metric that is also a list, or else selects the widget that places it. Closes the panel
    /// when it already shows that.
    func openFromTray(_ id: String) {
        let opens = entries.first { $0.id == id && $0.kind.opensSheet }?.id
        if isShown, opens == nil || openList == opens {
            dismiss()
        } else if let opens {
            press(opens)
        } else {
            closeList()
            show()
            selected = visible.firstIndex { $0.command.places.contains(id) } ?? 0
        }
    }

    func openBigView() {
        guard let entry = selectedEntry else { return }
        notify("\(entry.state.title) has no big view yet.")
    }

    var selectedEntry: Entry? {
        let list = visible
        guard list.indices.contains(selected) else { return nil }
        return list[selected]
    }

    /// Whether the panel shows its search field, which a form or a sheet of parts with no rows replaces.
    var showsSearch: Bool {
        form == nil && !isEditing && openPanel?.showsRows != false
    }

    var openPanel: SheetParts? {
        openSheet?.panel
    }

    var openSheet: SpotRun? {
        openList.flatMap { sheets[$0] }
    }

    var openEntry: Entry? {
        entries.first { $0.id == openList }
    }

    var openItems: ItemList? {
        openSheet?.list
    }

    /// The text of the field: the search of the open list, or else the search of the spots.
    var searchText: String {
        get { openItems?.query ?? query }
        set {
            if let file = SharedSpot.file(in: newValue) {
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
    func stepBack() -> Bool {
        if !searchText.isEmpty {
            searchText = ""
        } else if openList != nil {
            closeList()
        } else {
            return false
        }
        return true
    }

    func openSettings() {
        open(ShippedSpot.settingsID)
    }

    /// Opens a sheet and ends what another left running. The sheet of a staying script opens with its first frame.
    func open(_ id: String) {
        guard let sheet = sheets[id] else { return }
        sheets.values.filter { $0 !== sheet }.forEach { $0.close() }
        sheet.open(waits: sheetMoves) { [weak self] in self?.openList = id }
    }

    func closeList() {
        stopRecording()
        openList = nil
        sheets.values.forEach { $0.close() }
    }

    /// Closes each sheet of parts when the panel has faded, and stops the reads that nothing wants now. A sheet of rows stays
    /// open.
    func panelDidHide() {
        runs.panelClosed()
        if isFirstLaunch, !isWarming {
            isFirstLaunch = false
            confirm(entryKey.openHint)
        }
        if let openSheet, !openSheet.isOpen {
            sheetMoves = false
            openList = nil
        }
        endReview()
    }

    /// Starts the motion of the sheet to `list`: a grow out of its card, a collapse back into it, or a cut when the sheet does
    /// not move or has no place to close into. A new sheet is built on its card first, and its grow starts on the next turn,
    /// so that the grow has a start.
    private func moveSheet(to list: String?) {
        guard sheetMoves, list != nil || sheetHasClosedPlace else { return cutSheet(to: list) }
        guard let list else {
            animate(isOpen: false) {
                shownList = nil
                transition.hide(moves: true)
                holdFieldDrop()
            }
            return
        }
        change(nil) {
            shownList = list
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
            shownList = list
            if let list { transition.show(list, moves: false) } else { transition.hide(moves: false) }
            fieldDrop = nil
            showsFieldDrop = false
        }
        allowSheetMotion()
        if list == nil { endReview() }
    }

    /// Whether the built sheet has a place to close into: its card on the grid, or the field for the install screen.
    private var sheetHasClosedPlace: Bool {
        guard let id = transition.id else { return false }
        return id == ShippedSpot.installID || SpotSheetCard.of(id, in: self) != nil
    }

    /// Moves the sheet on its spring, in one transaction, and ends the motion when it is done. The words of a review leave
    /// the field at once when its sheet is open, and fade when it has closed into the field.
    private func animate(isOpen: Bool, _ body: () -> Void) {
        change(SpotMotion.sheet(isOpen: isOpen), body) { [weak self] in
            guard let self else { return }
            let isInstall = transition.id == ShippedSpot.installID
            change(nil) {
                self.transition.finish(isOpen ? .opening : .closing)
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
            change(SpotMotion.sheet(isOpen: true)) {
                fieldDrop = drop
                showsFieldDrop = true
            }
        } else if !isReviewing {
            hideFieldDrop()
        }
    }

    /// Gives the field back its search on the sheet's closing spring, and lets the words go when they have faded.
    private func hideFieldDrop() {
        change(SpotMotion.sheet(isOpen: false), { showsFieldDrop = false }) { [weak self] in
            guard let self, !showsFieldDrop else { return }
            fieldDrop = nil
        }
    }

    /// Brings a sheet its first parts: on the sheet's spring when the sheet shows, so that it grows to its new size, and at
    /// once when it does not.
    private func bringParts(of id: String, _ bring: () -> Void) {
        change(transition.id == id && transition.isOpen ? SpotMotion.sheet(isOpen: true) : nil, bring)
    }

    /// Makes a change on an animation, or with none at all, and calls `completion` when its motion has ended.
    private func change(_ animation: Animation?, _ body: () -> Void, completion: @escaping @MainActor () -> Void = {}) {
        var transaction = Transaction(animation: animation)
        transaction.disablesAnimations = animation == nil
        transaction.addAnimationCompletion(criteria: .removed) { MainActor.assumeIsolated { completion() } }
        withTransaction(transaction, body)
    }

    /// Lets the next open or close of a sheet move, as it does when the person asks for it in the open panel.
    func allowSheetMotion() {
        sheetMoves = true
    }

    func moveItem(by step: Int) {
        openSheet?.list.move(by: step)
    }

    func moveItemLine(by lines: Int) {
        openSheet?.list.moveLine(by: lines)
    }

    func runSelectedItem() {
        guard let item = openItems?.selectedItem else {
            createFromSearch()
            return
        }
        runItem(item)
    }

    /// The action that makes a new item from what the search did not find.
    var createAction: CommandAction? {
        guard let list = openItems, !list.query.isEmpty, list.shown.isEmpty, list.search == .local else { return nil }
        return openEntry?.command.actions.first { $0.scope == .command && $0.isForm }
    }

    func createFromSearch() {
        guard let action = createAction, let entry = openEntry else { return }
        openForm(action, on: (entry, nil), prefill: openItems?.query ?? "")
    }

    /// Sends a change of a slot of a row, or a press of one when it has no value (U9).
    func slot(_ slot: String, of item: SpotItem, to value: String?) {
        if let value { openSheet?.set(slot: slot, of: item, to: value) } else { openSheet?.press(slot: slot, of: item) }
    }

    func runItem(_ item: SpotItem) {
        guard let entry = openEntry else { return }
        pick(item, of: entry)
    }

    /// Records a pick and clears what it left open, once the panel has faded, so nothing moves during the fade.
    func finishPick() {
        guard let pick = closingPick else { return }
        closingPick = nil
        if pick.entry.command.keepsRecent {
            sheets[pick.entry.id]?.list.remember(pick.item)
            UserDefaults.standard.set(sheets[pick.entry.id]?.list.recent, forKey: Self.recentKey(pick.entry.id))
        }
        sheetMoves = false
        closeList()
    }

    func pick(_ item: SpotItem, of entry: Entry, action: CommandAction? = nil) {
        if action == nil, item.run == CatalogSpot.buildRun {
            closeList()
            sheetMoves = true
            open(ShippedSpot.buildID)
            return
        }
        if entry.id == ShippedSpot.spotsID, action == nil { spotsChanged = true }
        if action == nil, item.shortcut != nil {
            toggleRecording(id: item.run)
            return
        }
        if action != nil || entry.command.pick == .close {
            closingPick = (item, entry)
            if isShown {
                dismiss()
            } else {
                finishPick()
            }
        }
        if let action {
            sheets[entry.id]?.run(action, item: item)
        } else {
            sheets[entry.id]?.pick(item)
        }
    }
}
