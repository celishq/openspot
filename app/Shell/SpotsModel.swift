import AppKit
import OpenspotCore

@MainActor
@Observable
final class SpotsModel {
    struct Entry: Identifiable {
        let id: String
        let kind: SpotKind
        let size: SpotSize
        let symbol: String
        var command: PluginCommand
        let item: SpotItem?
        var state: SpotState

        init(command: PluginCommand, state: SpotState) {
            id = command.id
            kind = command.kind
            size = command.size
            symbol = command.symbol
            self.command = command
            item = nil
            self.state = state
        }

        /// A wide card for an item that the main search found in a list.
        init(command: PluginCommand, item: SpotItem) {
            id = "\(command.id)\n\(item.run)"
            kind = .launch
            size = .wide
            symbol = item.symbol ?? command.symbol
            self.command = command
            self.item = item
            state = SpotState(title: item.title, subtitle: item.subtitle ?? command.name)
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

    private static let stateTimeout: TimeInterval = 2
    private static let actionTimeout: TimeInterval = 30
    private static let itemsTimeout: TimeInterval = 10
    private static let globalItemLimit = 6
    private static let metricTick: UInt64 = 1_000_000_000

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
    private(set) var sheets: [String: SpotSheet] = [:]
    var isShown = false {
        didSet {
            if isShown != oldValue { updateMetricLoop() }
        }
    }
    var entryKey = Shortcut.standard
    private var isChainHeld = false
    private(set) var recordingPart: String?
    var setEntryKeyOn: (Bool) -> Void = { _ in }
    var dismiss: () -> Void = {}
    var show: () -> Void = {}
    var notify: (String) -> Void = { _ in }
    var applyConfig: () -> Void = {}
    var confirm: (String) -> Void = { _ in }
    private var problems: [String] = []
    private(set) var menu: ActionMenu?
    private var menuTarget: Target?
    private(set) var form: FormSession?
    private(set) var readings: [String: MetricReading] = [:]
    private var metrics: [PluginMetric] = []
    private var metricSchedule = MetricSchedule()
    private var metricLoop: Task<Void, Never>?
    private var outputs: [String: PluginOutput] = [:]

    /// Reads the config file and the plugin folder again, and asks each plugin for its state.
    func reload() async {
        applyConfig()
        let folder = PluginFolder.standard()
        let shipped = ShippedSpot.commands(
            folder: folder.url,
            guide: Bundle.main.url(forResource: "GUIDE", withExtension: "md") ?? folder.url,
            app: Bundle.main.executablePath ?? ""
        )
        let scan = (try? folder.scan(shipped: shipped)) ?? ScanResult(plugins: [Plugin(id: "openspot", commands: shipped)], refused: [])
        var entries: [Entry] = []
        var problems = scan.refused.map { "\($0.file) was not loaded: \($0.reason)" }
        scan.commands.filter { $0.kind == .list }.forEach { _ = sheet(for: $0) }
        scan.commands.filter { $0.kind == .list && $0.read?.has(.panel) == true }.forEach { sheets[$0.id]?.read() }
        if scan.commands.allSatisfy({ $0.shipped != nil }) {
            problems.append("No plugins in \(folder.url.path)")
        }
        for command in scan.commands {
            do {
                let opened = try await command.opened(timeout: Self.stateTimeout)
                if command.readsState, opened.command.kind == .list {
                    sheet(for: opened.command).read()
                }
                entries.append(Entry(command: opened.command, state: opened.state))
            } catch {
                entries.append(Entry(command: command, state: command.headerState))
                problems.append("\(command.name) failed. \(Self.reason(error))")
            }
        }
        for index in entries.indices {
            if let output = outputs[entries[index].id] { entries[index].command = entries[index].command.taking(output) }
        }
        self.entries = entries
        metrics = scan.metrics
        for metric in metrics {
            let reading = readings[metric.id]
            if reading?.label != metric.label || reading?.headerSymbol != metric.symbol {
                readings[metric.id] = MetricReading(label: metric.label, headerSymbol: metric.symbol)
            }
        }
        readDueMetrics()
        if metricLoop == nil { updateMetricLoop() }
        if problems != self.problems, !problems.isEmpty {
            notify(problems.joined(separator: " "))
        }
        self.problems = problems
    }

    /// Keeps the metrics fresh while the panel shows them, or while the menu bar shows any.
    private func updateMetricLoop() {
        metricLoop?.cancel()
        metricLoop = nil
        guard isShown || metrics.contains(where: \.isTray) else { return }
        metricLoop = Task {
            while !Task.isCancelled {
                readDueMetrics()
                try? await Task.sleep(nanoseconds: Self.metricTick)
            }
        }
    }

    /// Reads each wanted metric whose refresh time has passed.
    private func readDueMetrics() {
        let wanted = MetricSchedule.wanted(metrics, by: entries.map(\.command), isPanelOpen: isShown)
        for metric in metricSchedule.takeDue(wanted, now: Date()) {
            Task {
                do {
                    let value = try await metric.read(timeout: Self.itemsTimeout)
                    readings[metric.id]?.take(value)
                } catch {
                    readings[metric.id]?.markStale()
                }
            }
        }
    }

    /// The sheet of a list command, with the command as the folder last gave it.
    private func sheet(for command: PluginCommand) -> SpotSheet {
        if let sheet = sheets[command.id] {
            sheet.update(command)
            return sheet
        }
        let sheet = SpotSheet(
            command: command,
            recent: UserDefaults.standard.stringArray(forKey: Self.recentKey(command.id)) ?? [],
            prepare: { await SpotIconStore.shared.prepare($0) }
        )
        sheet.onReport = { [weak self] in self?.take($0, of: command.id) }
        sheets[command.id] = sheet
        return sheet
    }

    private func take(_ report: SpotSheet.Report, of id: String) {
        switch report {
        case .toast(let text): confirm(text)
        case .failure(let text): notify(text)
        case .listChange: if !query.isEmpty { updateVisible() }
        case .frame:
            if case .settings? = sheets[id]?.command.shipped { applyConfig() }
        case .output(let output):
            outputs[id] = output
            if let index = entries.firstIndex(where: { $0.id == id }) {
                entries[index].command = entries[index].command.taking(output)
            }
        }
    }

    private static func recentKey(_ id: String) -> String {
        "recent.\(id)"
    }

    private static func reason(_ error: Error) -> String {
        (error as? PluginError)?.reason ?? error.localizedDescription
    }

    /// Runs an action on a spot, and shows the state the plugin then reports.
    private func perform(_ action: SpotAction, on entry: Entry, reloads: Bool = false) {
        Task {
            do {
                if let toast = try await entry.command.perform(action, timeout: Self.actionTimeout) { confirm(toast) }
            } catch {
                notify("\(entry.state.title) failed. \(Self.reason(error))")
            }
            if reloads || entry.command.pick == .stay { sheets[entry.id]?.read() }
            guard entry.kind != .slider, closingPick == nil,
                  let state = try? await entry.command.state(timeout: Self.stateTimeout),
                  let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
            entries[index].state = state
        }
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
        guard let entry = selectedEntry, entry.kind == .slider, let index = index(of: entry) else { return }
        entries[index].state = entries[index].state.adjusted(by: delta)
        perform(.level(entries[index].state.level ?? 0), on: entries[index])
    }

    func tap(_ id: String) {
        guard let position = visible.firstIndex(where: { $0.id == id }) else { return }
        selected = position
        runSelected()
    }

    func setLevel(_ id: String, to value: Double) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let before = entries[index].state.level
        entries[index].state = entries[index].state.withLevel(value)
        guard entries[index].state.level != before else { return }
        perform(.level(entries[index].state.level ?? 0), on: entries[index])
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
        guard let index = index(of: entry) else { return }
        switch entry.kind {
        case .toggle:
            let action = SpotAction.toggle(entry.state)
            entries[index].state = SpotState(
                title: entry.state.title,
                subtitle: entry.state.subtitle,
                on: action.arguments == ["on"]
            )
            perform(action, on: entry)
        case .launch:
            if isShown { dismiss() }
            perform(entry.command.click, on: entry)
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

    /// The marks of the metrics that show in the menu bar, by metric.
    var trayMarks: [(id: String, mark: TrayMark)] {
        metrics.filter(\.isTray).compactMap { metric in
            guard let reading = readings[metric.id], let mark = TrayMark(reading: reading) else { return nil }
            return (metric.id, mark)
        }
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

    private func index(of entry: Entry) -> Int? {
        entries.firstIndex { $0.id == entry.id }
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
    }

    /// Closes the sheet of a staying script when the panel has faded, so that the next open starts it again.
    func panelDidHide() {
        if openSheet?.command.stays == true {
            sheetMoves = false
            closeList()
        } else {
            sheets.values.filter { $0.command.stays }.forEach { $0.close() }
        }
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

    private func pick(_ item: SpotItem, of entry: Entry, action: SpotAction? = nil) {
        if action != nil || entry.command.pick == .close {
            closingPick = (item, entry)
            if isShown {
                dismiss()
            } else {
                finishPick()
            }
        }
        perform(action ?? .item(item), on: entry)
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

    /// Takes Esc and the keys of the parts, and leaves all others to the text areas.
    private func handlePanelKey(_ key: ActionKey, _ panel: SpotPanel) -> Bool {
        if key == ActionKey(name: "escape") {
            allowSheetMotion()
            closeList()
            return true
        }
        guard let part = panel.parts.first(where: { $0.key == key }) else { return false }
        pressPart(part)
        return true
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
        return ActionMenu(command: target.entry.command, item: target.item, showsPrimary: !isOpenList || target.item != nil)
    }

    /// The keys that work on the selected row or card, in words for the bottom of the panel.
    var hint: String {
        if let panel = openPanel { return panel.hint }
        let keys = target.flatMap(actionMenu(on:))?.hint ?? "Esc Close"
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
        guard let row = menu?.press(), let target = menuTarget else { return }
        closeMenu()
        if let action = row.action {
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
            perform(.action(action, item: target.item), on: target.entry, reloads: true)
        } else if let item = target.item {
            pick(item, of: target.entry, action: .action(action, item: item))
        } else {
            if isShown { dismiss() }
            perform(.action(action, item: nil), on: target.entry)
        }
    }

    private func openForm(_ action: CommandAction, on target: Target, prefill: String = "") {
        Task {
            do {
                let form = try await target.entry.command.form(action, item: target.item, timeout: Self.actionTimeout)
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
                let run = try await form.entry.command.submit(form.action, item: form.item, draft: form.draft, timeout: Self.actionTimeout)
                self.form = nil
                sheets[form.entry.id]?.read(selecting: run.isEmpty ? nil : run)
            } catch {
                notify("\(form.action.title) failed. \(Self.reason(error))")
            }
        }
    }
}
