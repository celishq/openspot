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
        var state: SpotState

        init(command: PluginCommand, state: SpotState) {
            id = command.id
            kind = command.kind
            size = command.size
            symbol = command.symbol
            self.command = command
            self.state = state
        }
    }

    private static let stateTimeout: TimeInterval = 2
    private static let actionTimeout: TimeInterval = 30
    private static let itemsTimeout: TimeInterval = 10

    var entries: [Entry] = []
    var query = "" {
        didSet {
            if query != oldValue { selected = 0 }
        }
    }
    var selected = 0
    var openList: String?
    private(set) var lists: [String: ItemList] = [:]
    var isShown = false
    var dismiss: () -> Void = {}
    var show: () -> Void = {}
    var notify: (String) -> Void = { _ in }
    private var problems: [String] = []

    /// Reads the plugin folder again, and asks each plugin for its state.
    func reload() async {
        let folder = PluginFolder.standard()
        let scan = (try? folder.scan()) ?? ScanResult(plugins: [], refused: [])
        var entries: [Entry] = []
        var problems = scan.refused.map { "\($0.file) was not loaded: \($0.reason)" }
        scan.commands.filter { $0.kind == .list }.forEach(loadItems)
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
    private func loadItems(of command: PluginCommand) {
        if lists[command.id] == nil {
            lists[command.id] = ItemList(recent: UserDefaults.standard.stringArray(forKey: Self.recentKey(command.id)) ?? [])
        }
        Task {
            do {
                let lines = try await command.items(timeout: Self.itemsTimeout)
                lists[command.id]?.replace(lines.items)
                if !lines.errors.isEmpty {
                    notify("\(command.name) sent \(lines.errors.count) items Openspot cannot read.")
                }
            } catch {
                notify("\(command.name) failed. \(Self.reason(error))")
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
    private func perform(_ action: SpotAction, on entry: Entry) {
        Task {
            do {
                try await entry.command.perform(action, timeout: Self.actionTimeout)
            } catch {
                notify("\(entry.state.title) failed. \(Self.reason(error))")
            }
            if entry.kind == .list, entry.command.pick == .stay { loadItems(of: entry.command) }
            guard entry.kind != .slider,
                  let state = try? await entry.command.state(timeout: Self.stateTimeout),
                  let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
            entries[index].state = state
        }
    }

    var visible: [Entry] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return entries }
        return entries.filter { $0.state.title.localizedCaseInsensitiveContains(text) }
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
        show()
        open(id)
    }

    private func run(_ entry: Entry) {
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
            if let openList {
                lists[openList]?.search(newValue)
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
        lists[id]?.search("")
    }

    func closeList() {
        openList = nil
    }

    func moveItem(by step: Int) {
        guard let openList else { return }
        lists[openList]?.move(by: step)
    }

    func runSelectedItem() {
        guard let item = openItems?.selectedItem else { return }
        runItem(item)
    }

    func runItem(_ item: SpotItem) {
        guard let entry = openEntry else { return }
        if entry.command.pick == .close {
            lists[entry.id]?.remember(item)
            UserDefaults.standard.set(lists[entry.id]?.recent, forKey: Self.recentKey(entry.id))
            if isShown { dismiss() }
            closeList()
            query = ""
        }
        perform(.item(item), on: entry)
    }
}
