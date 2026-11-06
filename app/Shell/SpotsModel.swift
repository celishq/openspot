import AppKit
import OpenspotCore

@MainActor
@Observable
final class SpotsModel {
    /// One card: a script, which reads from its sheet, or a widget, or a row that the main search found.
    struct Entry: Identifiable {
        let id: String
        let size: SpotSize
        let item: SpotItem?
        private let sheet: SpotSheet?
        private let fixedCommand: PluginCommand
        private let fixedState: SpotState

        init(command: PluginCommand, sheet: SpotSheet?) {
            id = command.id
            size = command.size
            item = nil
            self.sheet = sheet
            fixedCommand = command
            fixedState = command.headerState
        }

        /// A wide card for an item that the main search found in a list.
        init(command: PluginCommand, item: SpotItem) {
            id = "\(command.id)\n\(item.run)"
            size = .wide
            self.item = item
            sheet = nil
            fixedCommand = command
            fixedState = SpotState(title: item.title, subtitle: item.subtitle ?? command.name)
        }

        @MainActor var command: PluginCommand {
            sheet?.command ?? fixedCommand
        }

        @MainActor var kind: SpotKind {
            item == nil ? command.kind : .launch
        }

        @MainActor var symbol: String {
            item?.symbol ?? command.symbol
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

    private typealias Target = (entry: Entry, item: SpotItem?)

    private static let globalItemLimit = 6
    private static let dragWatchPause: Duration = .milliseconds(100)
    private static let dropPause: Duration = .milliseconds(300)

    var entries: [Entry] = [] {
        didSet { updateVisible() }
    }
    var query = "" {
        didSet {
            if query != oldValue { selected = 0 }
            updateVisible()
        }
    }
    private(set) var visible: [Entry] = []
    var selected = 0
    var openList: String?
    private(set) var sheetMoves = true
    private var closingPick: (item: SpotItem, entry: Entry)?
    private let runs: SpotRuns
    private var dragWatch: Task<Void, Never>?
    private var dragPaths: [String] = []
    /// The shared spot that the open review shows, which exists only as long as that sheet.
    private var reviewed: SpotReview?
    var isShown = false
    /// Whether a drag over the menu bar item opened the panel, so that it is not key and its field takes no focus.
    var isOpenForDrag = false
    var updateSpot: UpdateSpot?

    var chooseFiles: (PluginCommand, @escaping ([String]) -> Void) -> Void = { _, _ in }
    var entryKey = Shortcut.standard
    private var isChainHeld = false
    private(set) var recordingPart: String?
    var setEntryKeyOn: (Bool) -> Void = { _ in }
    var dismiss: () -> Void = {}
    var show: () -> Void = {}
    var present: () -> Void = {}
    var notify: (String) -> Void = { _ in }
    var applyConfig: () -> Void = {}
    var confirm: (String) -> Void = { _ in }
    private var problems: [String] = []
    private(set) var menu: ActionMenu?
    private var menuTarget: Target?
    private(set) var form: FormSession?

    init() {
        runs = SpotRuns(
            recent: { UserDefaults.standard.stringArray(forKey: Self.recentKey($0)) ?? [] },
            prepare: { await SpotIconStore.shared.prepare($0) }
        )
        runs.onReport = { [weak self] id, report in self?.take(report, of: id) }
    }

    var sheets: [String: SpotSheet] {
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

    /// Reads the config file and the plugin folder again. No script runs for this, and each card shows its header until its
    /// answer arrives.
    func reload() {
        applyConfig()
        let folder = PluginFolder.standard()
        let shipped = ShippedSpot.commands(
            folder: folder.url,
            guide: Bundle.main.url(forResource: "GUIDE", withExtension: "md") ?? folder.url,
            app: Bundle.main.executablePath ?? "",
            update: updateSpot
        ) + (reviewed.map { [ShippedSpot.command(reviewing: $0)] } ?? [])
        let scan = (try? folder.scan(shipped: shipped)) ?? ScanResult(plugins: [Plugin(id: "openspot", commands: shipped)], refused: [])
        var problems = scan.refused.map { "\($0.file) was not loaded: \($0.reason)" }
        if scan.commands.allSatisfy({ $0.shipped != nil }) {
            problems.append("No plugins in \(folder.url.path)")
        }
        runs.take(scan)
        entries = scan.commands.map { Entry(command: $0, sheet: runs.sheets[$0.id]) }
        if problems != self.problems, !problems.isEmpty {
            notify(problems.joined(separator: " "))
        }
        self.problems = problems
    }

    /// Looks at the plugin folder and asks each script that the panel shows, at the same time.
    func panelWillShow() {
        reload()
        runs.panelOpened()
    }

    /// A moment of the Mac arrived, such as a wake.
    func arrive(_ moment: SpotRead.Moment) {
        runs.arrive(moment)
    }

    /// Stops each call as the app quits.
    func quit() {
        runs.quit()
    }

    private func take(_ report: SpotSheet.Report, of id: String) {
        switch report {
        case .toast(let text): confirm(text)
        case .failure(let text): notify(text)
        case .listChange: if !query.isEmpty { updateVisible() }
        case .frame:
            if case .settings? = sheets[id]?.command.shipped { applyConfig() }
        case .chooseFiles:
            if let sheet = sheets[id] { chooseFiles(sheet.command) { sheet.drop($0) } }
        }
    }

    /// Whether a card takes these dragged files. A card under an open sheet takes none.
    func acceptsDrop(_ paths: [String], on id: String) -> Bool {
        openList == nil && !SharedSpot.isFile(paths) && sheets[id]?.command.accepts(paths) == true
    }

    /// Whether a card shows that it takes the drag in progress.
    func takesDrag(_ id: String) -> Bool {
        openList == nil && runs.takesDrag(id)
    }

    /// Takes the files of a drag that reached the menu bar item or a card. When no mouse button is down, the cards stop
    /// showing them, and a panel that the drag opened closes.
    func followDrag() {
        let paths = SpotCardDrop.paths
        guard paths != dragPaths else { return }
        dragPaths = paths
        runs.draggedPaths = SharedSpot.isFile(paths) ? [] : paths
        dragWatch?.cancel()
        dragWatch = Task { [weak self] in
            while NSEvent.pressedMouseButtons != 0 {
                try? await Task.sleep(for: Self.dragWatchPause)
                if Task.isCancelled { return }
            }
            try? await Task.sleep(for: Self.dropPause)
            guard !Task.isCancelled, let self else { return }
            dragPaths = []
            runs.draggedPaths = []
            if isOpenForDrag, isShown { dismiss() }
        }
    }

    /// Takes a drop on a card and closes the panel. Returns false when the card does not take these files.
    func drop(_ paths: [String], on id: String) -> Bool {
        guard openList == nil, sheets[id]?.drop(paths) == true else { return false }
        dragPaths = []
        runs.draggedPaths = []
        if isShown { dismiss() }
        return true
    }

    /// Shows the grid and not a sheet, so that a drag can reach the cards.
    func prepareForDrag() {
        isOpenForDrag = true
        followDrag()
        guard openList != nil else { return }
        sheetMoves = false
        closeList()
    }

    /// Opens the sheet that shows a `.spot` file before a person adds it. One file shows at a time, and a file it cannot read
    /// only says why.
    func review(_ urls: [URL]) {
        guard let url = urls.first else { return }
        finishPick()
        closeMenu()
        form = nil
        closeList()
        do {
            let review = try SpotReview(
                spot: SharedSpot(contentsOf: url),
                name: url.deletingPathExtension().lastPathComponent,
                folder: PluginFolder.standard().url
            )
            reviewed = review
            dragWatch?.cancel()
            dragPaths = []
            runs.draggedPaths = []
            present()
            sheetMoves = false
            open(ShippedSpot.command(reviewing: review).id)
            if urls.count > 1 { notify("Openspot adds one spot at a time.") }
        } catch {
            notify(Self.reason(error))
        }
    }

    /// Whether a review shows, which stays open when the panel loses the focus.
    var isReviewing: Bool {
        reviewed != nil
    }

    /// Opens the review of a `.spot` file on the clipboard. Returns false when the clipboard holds other things, or a form is open.
    func pasteSpot(from pasteboard: NSPasteboard = .general) -> Bool {
        let paths = SpotCardDrop.paths(on: pasteboard)
        guard form == nil, SharedSpot.isFile(paths) else { return false }
        review(paths.map { URL(fileURLWithPath: $0) })
        return true
    }

    /// Ends the review, so that its card leaves the grid.
    private func endReview() {
        guard reviewed != nil else { return }
        reviewed = nil
        reload()
    }

    /// Puts the file of a spot on the clipboard, ready to paste into a chat, and warns the sender about secrets.
    private func share(_ entry: Entry) {
        if isShown { dismiss() }
        do {
            let folder = PluginFolder.standard()
            let spot = try SharedSpot(sharing: entry.command, from: folder.scan(), in: folder)
            let place = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-shared/\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
            let file = place.appendingPathComponent(SharedSpot.fileName(for: entry.command.name))
            try spot.data.write(to: file)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([file as NSURL])
            confirm(spot.notice(name: entry.command.name))
        } catch {
            notify("\(entry.command.name) was not copied. \(Self.reason(error))")
        }
    }

    /// Moves the file of a spot to the Trash. What it keeps in `$OPENSPOT_DATA` stays.
    private func remove(_ entry: Entry) {
        closeList()
        if isShown { dismiss() }
        do {
            try PluginFolder.standard().remove(entry.command)
            confirm("\(entry.command.name) moved to the Trash")
            reload()
        } catch {
            notify("\(entry.command.name) was not removed. \(Self.reason(error))")
        }
    }

    private static func recentKey(_ id: String) -> String {
        "recent.\(id)"
    }

    private static func reason(_ error: Error) -> String {
        (error as? PluginError)?.reason ?? error.localizedDescription
    }

    /// Shows each spot the search finds, then the items it finds in the lists that offer them.
    private func updateVisible() {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            visible = entries
            return
        }
        let spots = entries.filter { $0.state.title.localizedCaseInsensitiveContains(text) }
        let sources = entries.filter(\.command.isGlobal).sorted { $0.command.rank < $1.command.rank }
        let found = SearchQuery(text: text).matching(in: sources.map { sheets[$0.id]?.list ?? ItemList() })
        visible = spots + found.prefix(Self.globalItemLimit).map { Entry(command: sources[$0.list].command, item: $0.item) }
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

    func runSelected() {
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

    /// Notes which modifiers the person holds, so that each spot can show its letter while they match the entry key.
    func takeHeld(_ modifiers: Shortcut.Modifiers) {
        isChainHeld = modifiers == entryKey.modifiers
    }

    /// The letter that a spot shows while the person holds the modifiers of the entry key on the grid.
    func chainLetter(of entry: Entry) -> String? {
        guard isChainHeld, entry.item == nil, isOnGrid else { return nil }
        return entry.command.key?.name.uppercased()
    }

    private var isOnGrid: Bool {
        menu == nil && form == nil && openList == nil
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

    private func run(_ entry: Entry) {
        if let item = entry.item, let list = entries.first(where: { $0.id == entry.command.id }) {
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
        menuTarget.flatMap { sheets[$0.entry.id]?.work(of: row, item: $0.item) }
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

    private var selectedEntry: Entry? {
        let list = visible
        guard list.indices.contains(selected) else { return nil }
        return list[selected]
    }

    var placements: [SpotPlacement] {
        SpotGrid().place(visible.map(\.size))
    }

    /// Whether the panel shows its search field, which a form or a sheet of parts replaces.
    var showsSearch: Bool {
        form == nil && openPanel == nil
    }

    var openPanel: SpotPanel? {
        openSheet?.panel
    }

    private var openSheet: SpotSheet? {
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
            if let openSheet {
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

    /// Opens a sheet and ends what another left running. The sheet of a staying script opens with its first frame.
    private func open(_ id: String) {
        guard let sheet = sheets[id] else { return }
        sheets.values.filter { $0 !== sheet }.forEach { $0.close() }
        sheet.open { [weak self] in self?.openList = id }
    }

    func closeList() {
        stopRecording()
        openList = nil
        sheets.values.forEach { $0.close() }
        endReview()
    }

    /// Closes each sheet of parts when the panel has faded, and stops the reads that nothing wants now. A sheet of rows stays
    /// open.
    func panelDidHide() {
        runs.panelClosed()
        if let openSheet, !openSheet.isOpen {
            sheetMoves = false
            openList = nil
        }
        endReview()
    }

    /// Lets the next open or close of a sheet move, as it does when the person asks for it in the open panel.
    func allowSheetMotion() {
        sheetMoves = true
    }

    func moveItem(by step: Int) {
        openSheet?.list.move(by: step)
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

    private func pick(_ item: SpotItem, of entry: Entry, action: CommandAction? = nil) {
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

    /// What the actions menu and the action keys work on: the selected row, or else the selected card.
    private var target: Target? {
        if let entry = openEntry { return (entry, openItems?.selectedItem) }
        guard let entry = selectedEntry else { return nil }
        if let item = entry.item, let list = entries.first(where: { $0.id == entry.command.id }) { return (list, item) }
        return (entry, nil)
    }

    /// Takes a key before the focused field does. Returns false when the key is not for an action, a menu or a form.
    func handleKey(_ key: ActionKey) -> Bool {
        if menu != nil {
            handleMenuKey(key)
            return true
        }
        if form != nil {
            switch key {
            case ActionKey(name: "return", isCommand: true): submitForm()
            case ActionKey(name: "escape"): cancelForm()
            default: return false
            }
            return true
        }
        if let panel = openPanel { return handlePanelKey(key, panel) }
        if key == ActionKey(name: "escape") {
            allowSheetMotion()
            if !stepBack() { dismiss() }
            return true
        }
        guard let target else { return false }
        if key == ActionKey(name: "k", isCommand: true) {
            openMenu(on: target)
            return menu != nil
        }
        guard let action = target.entry.command.actions(for: target.item).first(where: { $0.key == key }) else { return false }
        if action.confirm != nil {
            openMenu(on: target)
            menu?.select(action)
            pressMenu()
        } else {
            run(action, on: target)
        }
        return true
    }

    /// Takes Esc, the arrows, return and the keys of the parts, and leaves all others to the text areas.
    private func handlePanelKey(_ key: ActionKey, _ panel: SpotPanel) -> Bool {
        if key == ActionKey(name: "escape") {
            allowSheetMotion()
            closeList()
            return true
        }
        if panel.takesArrows, key == ActionKey(name: "up") || key == ActionKey(name: "down") {
            openSheet?.movePart(by: key.name == "up" ? -1 : 1)
            return true
        }
        if let part = panel.parts.first(where: { $0.key == key }) {
            pressPart(part)
            return true
        }
        guard key == ActionKey(name: "return"), let part = panel.selectedPart else { return false }
        useSelected(part)
        return true
    }

    /// Does what a click on the control of this part does.
    private func useSelected(_ part: SpotPart) {
        switch part.control {
        case .shortcut: toggleRecording(part)
        case .toggle(let on): setPart(part, to: on ? "false" : "true")
        default: pressPart(part)
        }
    }

    func setPart(_ part: SpotPart, to value: String) {
        openSheet?.set(part, to: value)
    }

    func pressPart(_ part: SpotPart) {
        openSheet?.press(part)
        if part.closes, isShown { dismiss() }
    }

    /// Starts to record the next key for a part, with the entry key off so that it can be recorded too, or stops.
    func toggleRecording(_ part: SpotPart) {
        if recordingPart == part.id {
            stopRecording()
        } else {
            recordingPart = part.id
            setEntryKeyOn(false)
        }
    }

    func stopRecording() {
        guard recordingPart != nil else { return }
        recordingPart = nil
        setEntryKeyOn(true)
    }

    /// Takes the key for the part that records. A key it cannot use leaves it recording, and says why.
    func record(code: UInt32, modifiers: Shortcut.Modifiers) {
        guard let shortcut = Shortcut(code: code, modifiers: modifiers) else {
            notify("Hold cmd, ctrl or option with a letter, a digit, space, return or tab.")
            return
        }
        let part = openPanel?.parts.first { $0.id == recordingPart }
        stopRecording()
        if let part { setPart(part, to: shortcut.text) }
    }

    private func handleMenuKey(_ key: ActionKey) {
        switch key {
        case ActionKey(name: "k", isCommand: true), ActionKey(name: "escape"): closeMenu()
        case ActionKey(name: "up"): menu?.move(by: -1)
        case ActionKey(name: "down"): menu?.move(by: 1)
        case ActionKey(name: "return"): pressMenu()
        default:
            if let action = menu?.rows.compactMap(\.action).first(where: { $0.key == key }) {
                menu?.select(action)
                pressMenu()
            }
        }
    }

    private func openMenu(on target: Target) {
        menu = actionMenu(on: target)
        menuTarget = target
    }

    private func actionMenu(on target: Target) -> ActionMenu? {
        let isOpenList = openList == target.entry.id
        return ActionMenu(
            command: target.entry.command,
            item: target.item,
            showsPrimary: !isOpenList || target.item != nil,
            extras: target.item == nil && target.entry.command.shipped == nil ? [.share, .remove(widgets: widgets(sharingFileWith: target.entry))] : []
        )
    }

    /// How many widgets the file of a widget holds, which go together when it is removed.
    private func widgets(sharingFileWith entry: Entry) -> Int {
        entry.kind == .widget ? entries.filter { $0.command.url == entry.command.url }.count : 1
    }

    /// The keys that work on the selected row or card, in words for the bottom of the panel.
    var hint: String {
        if SharedSpot.isFile(dragPaths) { return "Drop to review this spot" }
        if let panel = openPanel { return panel.hint { work(of: $0) != nil } }
        let keys = target.flatMap { target in
            actionMenu(on: target)?.hint { sheets[target.entry.id]?.work(of: $0, item: target.item) != nil }
        } ?? "Esc Close"
        return selectedGlyphTitle.map { "\($0)  \(keys)" } ?? keys
    }

    /// The name of the selected spot when it shows only a glyph.
    private var selectedGlyphTitle: String? {
        guard openList == nil, let entry = selectedEntry, entry.kind != .widget,
              placements.first(where: { $0.index == selected })?.size == .small
        else { return nil }
        return entry.state.title
    }

    func closeMenu() {
        menu = nil
        menuTarget = nil
    }

    func pressMenu(row: Int) {
        guard let menu else { return }
        self.menu?.move(by: row - menu.selected)
        pressMenu()
    }

    private func pressMenu() {
        let isRunning = menu.map { work(of: $0.rows[$0.selected]) != nil } ?? false
        guard let row = menu?.press(isRunning: isRunning), let target = menuTarget else { return }
        closeMenu()
        if row.action == .share {
            share(target.entry)
        } else if row.action?.id == CommandAction.removeID {
            remove(target.entry)
        } else if let action = row.action {
            run(action, on: target)
        } else if let item = target.item {
            pick(item, of: target.entry)
        } else {
            run(target.entry)
        }
    }

    private func run(_ action: CommandAction, on target: Target) {
        if action.isForm {
            openForm(action, on: target)
        } else if action.after == .stay {
            sheets[target.entry.id]?.run(action, item: target.item)
        } else if let item = target.item {
            pick(item, of: target.entry, action: action)
        } else {
            if isShown { dismiss() }
            sheets[target.entry.id]?.run(action, item: nil)
        }
    }

    private func openForm(_ action: CommandAction, on target: Target, prefill: String = "") {
        Task {
            do {
                guard let form = try await sheets[target.entry.id]?.form(action, item: target.item) else { return }
                let opensSheet = openList != target.entry.id
                if opensSheet {
                    sheetMoves = isShown
                    open(target.entry.id)
                }
                self.form = FormSession(
                    draft: FormDraft(form: form, prefill: prefill),
                    entry: target.entry,
                    action: action,
                    item: target.item,
                    openedSheet: opensSheet
                )
            } catch {
                notify("\(action.title) failed. \(Self.reason(error))")
            }
        }
    }

    func setFormValue(_ text: String, for name: String) {
        form?.draft.set(text, for: name)
    }

    func cancelForm() {
        guard let form else { return }
        self.form = nil
        if form.openedSheet {
            allowSheetMotion()
            closeList()
        }
    }

    /// Saves the form. It stays open with its text when the command refuses the values.
    func submitForm() {
        guard let form else { return }
        if let missing = form.draft.missing {
            notify("Enter a value for \(missing.label).")
            return
        }
        Task {
            do {
                if try await sheets[form.entry.id]?.submit(form.action, item: form.item, draft: form.draft) == true { self.form = nil }
            } catch {
                notify("\(form.action.title) failed. \(Self.reason(error))")
            }
        }
    }
}
