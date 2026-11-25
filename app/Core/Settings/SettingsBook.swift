import Foundation
import Observation

@MainActor
@Observable
public final class SettingsBook {
    public private(set) var access = AccessFacts()
    public private(set) var spots = SpotStandings()
    public private(set) var keys = KeyMap()
    public private(set) var rows = SettingRows()
    public private(set) var looks: [SettingsFacts.Look] = []
    public private(set) var account: SettingsFacts.Account?
    public private(set) var index = SettingsIndex()
    public private(set) var page = SettingsPage.access
    public private(set) var back: [SettingsPage] = []
    public private(set) var forward: [SettingsPage] = []
    public private(set) var query = ""
    public private(set) var target: String?
    public private(set) var recording: String?
    private var pending: [String: String] = [:]
    public internal(set) var grant: AccessGrant?
    public private(set) var isOpen = false
    @ObservationIgnored weak var model: SpotsModel?
    @ObservationIgnored public internal(set) var searchRows = ItemList()
    @ObservationIgnored var rowsRead: Task<Void, Never>?
    @ObservationIgnored private var landing: SettingsPage?
    @ObservationIgnored private var reading: Task<Void, Never>?
    @ObservationIgnored private var hasRead = false

    public init() {}

    public var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var title: String {
        guard query.isEmpty else { return "Search" }
        return switch page {
        case .accessOf(let id): id.title
        case .spotOf(let id): spots.standing(id)?.title ?? id
        default: page.section.title
        }
    }

    public func value(of row: SettingRow) -> SettingValue {
        let text = pending[row.item] ?? row.value ?? ""
        return SettingValue(text.isEmpty ? row.default ?? "" : text, of: row.kind)
    }

    func open(at place: SettingsPage?) {
        isOpen = true
        landing = place
        if let place { land(place) }
        refresh()
    }

    public func closed() {
        isOpen = false
        recording = nil
        reading?.cancel()
        reading = nil
    }

    public func refresh() {
        guard isOpen else { return }
        reading?.cancel()
        reading = Task { [weak self] in await self?.readFacts() }
    }

    public func read() async {
        isOpen = true
        reading?.cancel()
        reading = nil
        await readFacts()
    }

    private func readFacts() async {
        guard let api = model?.runs.api else { return }
        let next = await api.settingsFacts()
        guard !Task.isCancelled else { return }
        hasRead = true
        take(next)
        if !pending.isEmpty { pending = [:] }
        if let place = landing {
            landing = nil
            land(place)
        }
    }

    private func take(_ next: SettingsFacts) {
        let isIndexed = next.access == access && next.spots == spots && next.rows == rows
        if next.access != access { access = next.access }
        if next.spots != spots { spots = next.spots }
        if next.keys != keys { keys = next.keys }
        if next.rows != rows { rows = next.rows }
        if next.looks != looks { looks = next.looks }
        if next.account != account { account = next.account }
        if !isIndexed { index = SettingsIndex(accesses: access.all, standings: spots.all, rows: rows.all) }
        take(rows: rows.all)
    }

    public func go(_ next: SettingsPage) {
        guard next != page || !query.isEmpty else { return }
        if query.isEmpty { back.append(page) }
        forward = []
        query = ""
        recording = nil
        target = nil
        page = next
    }

    public func goBack() {
        guard let last = back.popLast() else { return }
        forward.append(page)
        recording = nil
        target = nil
        page = last
    }

    public func goForward() {
        guard let next = forward.popLast() else { return }
        back.append(page)
        recording = nil
        target = nil
        page = next
    }

    public func search(_ text: String) {
        guard text != query else { return }
        query = text
    }

    public func land(_ place: SettingsPage) {
        query = ""
        recording = nil
        back = []
        forward = []
        target = nil
        switch place {
        case .row(let item):
            guard let row = rows.row(item) else { return page = .access }
            reveal(row)
        case .search(let words):
            query = words
        case .spotOf(let id) where spots.standing(id) == nil && !rows.rows(of: id).isEmpty:
            page = .keys
            target = "\(id)/open"
        default:
            page = place
        }
    }

    public func reveal(_ row: SettingRow) {
        land(row.spot == ReservedSetting.appSpot ? row.section.page : spots.standing(row.spot) == nil ? .keys : .spotOf(row.spot))
        target = row.item
    }

    public func startRecording(_ row: SettingRow) {
        recording = row.item
    }

    @discardableResult
    public func record(key name: String, modifiers: [String]) -> Bool {
        guard let id = recording, let row = rows.row(id) else { return false }
        if name == "escape" {
            recording = nil
            return true
        }
        if name == "backspace", modifiers.isEmpty {
            recording = nil
            Task { await remove(row) }
            return true
        }
        guard modifiers.contains(where: { ["cmd", "ctrl", "option"].contains($0) }) else { return true }
        recording = nil
        let value = (modifiers + [name]).joined(separator: "+")
        Task { await set(row, to: value) }
        return true
    }

    public func set(_ row: SettingRow, to value: String) async {
        pending[row.item] = value
        await run(["setting", "set", "--spot", row.spot, row.key] + (value.isEmpty ? [] : [value]))
    }

    public func set(_ row: SettingRow, on isOn: Bool) async {
        await set(row, to: String(isOn))
    }

    public func remove(_ row: SettingRow) async {
        pending[row.item] = ""
        await run(["setting", "remove", "--spot", row.spot, row.key])
    }

    public func turn(_ spot: String, on isOn: Bool) async {
        await run(["setting", "set", "--spot", spot, "enabled", isOn ? "true" : "false"])
    }

    public func use(theme name: String) async {
        await run(["theme", "use", name])
    }

    public func allow(_ spot: String) async {
        await run(["access", "grant", spot])
    }

    public func review(_ spot: String, use: SpotUse) async {
        await run(["spot", "allow", spot, use.rawValue])
    }

    public func ask(_ access: MacAccess) async {
        guard access == .accessibility else { return openPane(of: access) }
        await run(["access", "ask", access.rawValue])
    }

    public func openPane(of access: MacAccess) {
        guard let pane = access.pane else { return }
        model?.host.open(pane)
    }

    public func endGrant() async {
        await run(["access", "grant", "--end"])
    }

    public func restart() async {
        await run(["app", "restart"])
    }

    public func say(_ words: String) {
        model?.toast(ToastNote(words: words))
    }

    func run(_ arguments: [String]) async {
        guard let api = model?.runs.api else { return }
        let answer = await api.answer(arguments)
        if answer.code != 0, let line = answer.errors.split(separator: "\n").last { model?.toast(.failure(String(line))) }
        await read()
    }
}
