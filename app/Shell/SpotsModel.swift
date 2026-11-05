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
    private static let liveTimeout: TimeInterval = 10
    private static let metricTick: UInt64 = 1_000_000_000
    private static let textPause: Duration = .milliseconds(300)
    private static let sliderPause: Duration = .milliseconds(100)

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
    private(set) var lists: [String: ItemList] = [:] {
        didSet {
            if !query.isEmpty { updateVisible() }
        }
    }
    var isShown = false {
        didSet {
            if isShown != oldValue { updateMetricLoop() }
        }
    }
    var dismiss: () -> Void = {}
    var show: () -> Void = {}
    var notify: (String) -> Void = { _ in }
    var confirm: (String) -> Void = { _ in }
    private var problems: [String] = []
    private var liveAnswer: Task<Void, Never>?
    private(set) var menu: ActionMenu?
    private var menuTarget: Target?
    private(set) var form: FormSession?
    private(set) var readings: [String: MetricReading] = [:]
    private var metrics: [PluginMetric] = []
    private var metricSchedule = MetricSchedule()
    private var metricLoop: Task<Void, Never>?
    private var outputs: [String: PluginOutput] = [:]
    private(set) var panels: [String: SpotPanel] = [:]
    private var panelCall: Task<Void, Never>?
    private var panelRead: Task<Void, Never>?

    /// Reads the plugin folder again, and asks each plugin for its state.
    func reload() async {
        let folder = PluginFolder.standard()
        let shipped = ShippedSpot.commands(
            folder: folder.url,
            guide: Bundle.main.url(forResource: "GUIDE", withExtension: "md") ?? folder.url,
            app: Bundle.main.executablePath ?? ""
        )
        let scan = (try? folder.scan(shipped: shipped)) ?? ScanResult(plugins: [Plugin(id: "openspot", commands: shipped)], refused: [])
        var entries: [Entry] = []
        var problems = scan.refused.map { "\($0.file) was not loaded: \($0.reason)" }
        scan.commands.filter { $0.kind == .list }.forEach(prepareList)
        scan.commands.filter { $0.kind == .list && $0.read == .open }.forEach { loadItems(of: $0) }
        if scan.commands.allSatisfy({ $0.shipped != nil }) {
            problems.append("No plugins in \(folder.url.path)")
        }
        for command in scan.commands {
            do {
                let opened = try await command.opened(timeout: Self.stateTimeout)
                if command.readsState, opened.command.kind == .list {
                    prepareList(opened.command)
                    loadItems(of: opened.command)
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

    private func prepareList(_ command: PluginCommand) {
        if lists[command.id] == nil {
            lists[command.id] = ItemList(recent: UserDefaults.standard.stringArray(forKey: Self.recentKey(command.id)) ?? [], search: command.search)
        }
    }

    /// Keeps the actions a script printed, for its spot now and after the next reload.
    private func keep(_ output: PluginOutput, of command: PluginCommand) {
        outputs[command.id] = output
        if let index = entries.firstIndex(where: { $0.id == command.id }) {
            entries[index].command = entries[index].command.taking(output)
        }
    }

    /// Asks a list command for its items, and shows them when they arrive.
    private func loadItems(of command: PluginCommand, selecting run: String? = nil) {
        guard command.kind == .list else { return }
        prepareList(command)
        guard command.search == .local else { return }
        lists[command.id]?.beginLoading()
        Task {
            do {
                let lines = try await command.items(input: panels[command.id]?.values, timeout: Self.itemsTimeout)
                keep(lines, of: command)
                takePanel(lines, of: command)
                lists[command.id]?.replace(lines.items)
                if let run { lists[command.id]?.select(run: run) }
                await SpotIconStore.shared.prepare(lines.items)
                if !lines.errors.isEmpty {
                    notify("\(command.name) sent \(lines.errors.count) items Openspot cannot read.")
                }
            } catch {
                lists[command.id]?.loadFailed()
                notify("\(command.name) failed. \(Self.reason(error))")
            }
        }
    }

    /// Asks a live list about its current search. A newer search stops the older one.
    private func askLive(_ command: PluginCommand) {
        guard let query = lists[command.id]?.query else { return }
        liveAnswer?.cancel()
        liveAnswer = Task {
            do {
                let lines = try await command.items(query: query, timeout: Self.liveTimeout)
                await SpotIconStore.shared.prepare(lines.items)
                guard !Task.isCancelled else { return }
                keep(lines, of: command)
                lists[command.id]?.answer(lines.items, to: query)
            } catch {
                guard !Task.isCancelled else { return }
                lists[command.id]?.stopWaiting(for: query)
                if error as? PluginError != .timedOut {
                    notify("\(command.name) failed. \(Self.reason(error))")
                }
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
            if reloads || entry.command.pick == .stay { loadItems(of: entry.command) }
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
        let found = SearchQuery(text: text).matching(in: sources.map { lists[$0.id] ?? ItemList() })
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
            perform(.run, on: entry)
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
            query = ""
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
        openList.flatMap { panels[$0] }
    }

    var openEntry: Entry? {
        entries.first { $0.id == openList }
    }

    var openItems: ItemList? {
        openList.flatMap { lists[$0] }
    }

    /// The text of the field: the search of the open list, or else the search of the spots.
    var searchText: String {
        get { openItems?.query ?? query }
        set {
            if let entry = openEntry {
                if lists[entry.id]?.search(newValue) == true, entry.command.search == .live {
                    askLive(entry.command)
                }
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

    private func open(_ id: String) {
        openList = id
        lists[id]?.reset()
        guard let command = openEntry?.command else { return }
        if command.search == .live {
            askLive(command)
        } else {
            loadItems(of: command)
        }
    }

    func closeList() {
        openList = nil
        liveAnswer?.cancel()
        panelCall?.cancel()
        panelRead?.cancel()
    }

    /// Lets the next open or close of a sheet move, as it does when the person asks for it in the open panel.
    func allowSheetMotion() {
        sheetMoves = true
    }

    func moveItem(by step: Int) {
        guard let openList else { return }
        lists[openList]?.move(by: step)
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
            lists[pick.entry.id]?.remember(pick.item)
            UserDefaults.standard.set(lists[pick.entry.id]?.recent, forKey: Self.recentKey(pick.entry.id))
        }
        sheetMoves = false
        closeList()
        query = ""
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

    /// Shows the parts a script printed, and keeps them fresh when it asks for that.
    private func takePanel(_ lines: PluginOutput, of command: PluginCommand) {
        guard var panel = panels[command.id] else {
            panels[command.id] = SpotPanel(output: lines)
            return readPanelAgain(command)
        }
        if panel.take(lines, answering: panel.generation) {
            panels[command.id] = panel
            readPanelAgain(command)
        }
    }

    /// Reads an open sheet of parts again after the time it asks for.
    private func readPanelAgain(_ command: PluginCommand) {
        panelRead?.cancel()
        guard openList == command.id, let every = panels[command.id]?.every else { return }
        panelRead = Task {
            try? await Task.sleep(for: .seconds(every))
            if !Task.isCancelled { loadItems(of: command) }
        }
    }

    /// Takes a value the person set, so that it shows at once, and tells the script after a pause that fits the control.
    func setPart(_ part: SpotPart, to value: String) {
        guard let entry = openEntry, let generation = panels[entry.id]?.set(value, of: part.id) else { return }
        let pause: Duration? = switch part.control {
        case .text: Self.textPause
        case .slider: Self.sliderPause
        default: nil
        }
        call(.set(part.id, to: value), on: entry, generation: generation, pause: pause, keeping: part.isEditable ? part.id : nil)
    }

    func pressPart(_ part: SpotPart) {
        guard let entry = openEntry, let generation = panels[entry.id]?.advance() else { return }
        if part.closes, isShown { dismiss() }
        call(.press(part.id), on: entry, generation: generation, closes: part.closes)
    }

    /// Runs one change of a sheet of parts. A newer change stops it, and only the newest answer shows. A script that
    /// prints no parts is read again.
    private func call(_ action: SpotAction, on entry: Entry, generation: Int, pause: Duration? = nil, keeping: String? = nil, closes: Bool = false) {
        panelCall?.cancel()
        panelCall = Task {
            if let pause { try? await Task.sleep(for: pause) }
            guard !Task.isCancelled, let values = panels[entry.id]?.values else { return }
            do {
                let lines = try await entry.command.change(action, values: values, timeout: Self.actionTimeout)
                guard !Task.isCancelled || closes else { return }
                if let toast = lines.summary?.value("toast") { confirm(toast) }
                if lines.parts.isEmpty, !closes {
                    loadItems(of: entry.command)
                } else {
                    panels[entry.id]?.take(lines, answering: generation, keeping: keeping)
                }
            } catch {
                guard !Task.isCancelled else { return }
                notify("\(entry.state.title) failed. \(Self.reason(error))")
                loadItems(of: entry.command)
            }
        }
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
                lists[form.entry.id]?.reset()
                loadItems(of: form.entry.command, selecting: run.isEmpty ? nil : run)
            } catch {
                notify("\(form.action.title) failed. \(Self.reason(error))")
            }
        }
    }
}
