import Foundation
import OpenspotCore

@MainActor
@Observable
final class SpotsModel {
    struct Entry: Identifiable {
        let id: String
        let kind: SpotKind
        let size: SpotSize
        let symbol: String
        let command: PluginCommand
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
    var isShown = false
    var dismiss: () -> Void = {}
    var show: () -> Void = {}
    var notify: (String) -> Void = { _ in }
    private var problems: [String] = []
    private var liveAnswer: Task<Void, Never>?
    private(set) var menu: ActionMenu?
    private var menuTarget: Target?
    private(set) var form: FormSession?

    /// Reads the plugin folder again, and asks each plugin for its state.
    func reload() async {
        let folder = PluginFolder.standard()
        let scan = (try? folder.scan()) ?? ScanResult(plugins: [], refused: [])
        var entries: [Entry] = []
        var problems = scan.refused.map { "\($0.file) was not loaded: \($0.reason)" }
        scan.commands.filter { $0.kind == .list }.forEach { loadItems(of: $0) }
        if scan.commands.isEmpty {
            problems.append("No plugins in \(folder.url.path)")
        }
        for command in scan.commands {
            do {
                entries.append(Entry(command: command, state: try await command.state(timeout: Self.stateTimeout)))
            } catch {
                entries.append(Entry(command: command, state: command.manifestState))
                problems.append("\(command.name) failed. \(Self.reason(error))")
            }
        }
        self.entries = entries
        if problems != self.problems, !problems.isEmpty {
            notify(problems.joined(separator: " "))
        }
        self.problems = problems
    }

    /// Asks a list command for its items, and shows them when they arrive.
    private func loadItems(of command: PluginCommand, selecting run: String? = nil) {
        guard command.kind == .list else { return }
        if lists[command.id] == nil {
            lists[command.id] = ItemList(recent: UserDefaults.standard.stringArray(forKey: Self.recentKey(command.id)) ?? [], search: command.search)
        }
        guard command.search == .local else { return }
        Task {
            do {
                let lines = try await command.items(timeout: Self.itemsTimeout)
                lists[command.id]?.replace(lines.items)
                if let run { lists[command.id]?.select(run: run) }
                await SpotIconStore.shared.prepare(lines.items)
                if !lines.errors.isEmpty {
                    notify("\(command.name) sent \(lines.errors.count) items Openspot cannot read.")
                }
            } catch {
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
                try await entry.command.perform(action, timeout: Self.actionTimeout)
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
        let items = entries.filter(\.command.isGlobal).flatMap { entry in
            (lists[entry.id]?.matches(text) ?? []).map { Entry(command: entry.command, item: $0) }
        }
        visible = spots + items.prefix(Self.globalItemLimit)
    }

    func moveSelection(dx: Int, dy: Int) {
        let spots = placements
        guard let here = spots.first(where: { $0.index == selected }) else { return }
        let hereX = Double(here.column) + Double(here.size.columns) / 2
        let hereY = Double(here.row) + Double(here.size.rows) / 2
        let candidates: [(index: Int, score: Double)] = spots.compactMap { spot in
            guard spot.index != selected else { return nil }
            let x = Double(spot.column) + Double(spot.size.columns) / 2 - hereX
            let y = Double(spot.row) + Double(spot.size.rows) / 2 - hereY
            let along = x * Double(dx) + y * Double(dy)
            guard along > 0 else { return nil }
            let across = dx != 0 ? abs(y) : abs(x)
            return (spot.index, along + 2 * across)
        }
        if let best = candidates.min(by: { $0.score < $1.score }) {
            selected = best.index
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
        guard entry.kind == .list else {
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
        let isOpenList = openList == target.entry.id
        menu = ActionMenu(command: target.entry.command, item: target.item, showsPrimary: !isOpenList || target.item != nil)
        menuTarget = target
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
