import Foundation
import Observation

@MainActor
@Observable
public final class SettingsBook {
    public private(set) var access = AccessFacts()
    public private(set) var spots = SpotStandings()
    public private(set) var rows = SettingRows()
    public private(set) var looks: [ListedTheme] = []
    public private(set) var account: AccountStatus?
    public private(set) var index = SettingsIndex()
    public private(set) var trail = SettingsTrail()
    public private(set) var found = SettingsIndex.Found.none
    public private(set) var shownSpots: [SpotStanding] = []
    public private(set) var query = "" {
        didSet { if query != oldValue { find() } }
    }
    public private(set) var target: String?
    public private(set) var recording: String?
    private var pending: [String: String] = [:]
    public internal(set) var grant: AccessGrant?
    public private(set) var isOpen = false
    @ObservationIgnored weak var model: SpotsModel?
    @ObservationIgnored public internal(set) var searchRows = ItemList()
    @ObservationIgnored var rowsRead: Task<Void, Never>?
    @ObservationIgnored private var landing: SettingsPlace?
    @ObservationIgnored private var reading: Task<Void, Never>?
    @ObservationIgnored private var hasRead = false

    public init() {}

    public var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var page: SettingsPage {
        trail.now.page
    }

    public var mark: SettingsPage {
        trail.now.mark
    }

    public var title: String {
        guard query.isEmpty else { return "Search" }
        if case .accessOf(let id) = page { return "\(title(of: mark)) › \(id.title)" }
        return title(of: page)
    }

    private func title(of page: SettingsPage) -> String {
        switch page {
        case .top(let section): section.title
        case .account: "Account"
        case .accessOf(let id): id.title
        case .spotOf(let id): spots.standing(id)?.title ?? id
        }
    }

    private func find() {
        let next = isSearching ? index.found(query) : .none
        if next != found { found = next }
        let ids = Set(next.standings.map(\.id) + next.rows.map(\.spot))
        let shown = isSearching ? spots.all.filter { ids.contains($0.id) } : spots.all
        if shown != shownSpots { shownSpots = shown }
    }

    public func value(of row: SettingRow) -> SettingValue {
        let text = pending[row.item] ?? row.value ?? ""
        return SettingValue(text.isEmpty ? row.default ?? "" : text, of: row.kind)
    }

    func open(at place: SettingsPlace?) {
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
        if next.rows != rows { rows = next.rows }
        if next.looks != looks { looks = next.looks }
        if next.account != account { account = next.account }
        if !isIndexed {
            index = SettingsIndex(accesses: access.all, standings: spots.all, rows: rows.all)
            find()
        }
        take(rows: rows.all)
    }

    public func go(_ next: SettingsPage) {
        guard next != page || !query.isEmpty else { return }
        let remembers = query.isEmpty
        query = ""
        recording = nil
        target = nil
        trail.go(next, remembers: remembers)
    }

    public func goBack() {
        recording = nil
        target = nil
        _ = trail.goBack()
    }

    public func goForward() {
        recording = nil
        target = nil
        _ = trail.goForward()
    }

    public func search(_ text: String) {
        guard text != query else { return }
        query = text
    }

    public func land(_ place: SettingsPlace) {
        query = ""
        recording = nil
        target = nil
        switch place {
        case .row(let item):
            guard let row = rows.row(item) else { return trail.land(.general) }
            reveal(row)
        case .search(let words):
            trail.land(page)
            query = words
        case .page(.spotOf(let id)) where spots.standing(id) == nil && !rows.rows(of: id).isEmpty:
            trail.land(.general)
        case .page(let page):
            trail.land(page)
        }
    }

    public func reveal(_ row: SettingRow) {
        land(.page(row.spot == ReservedSetting.appSpot ? .top(row.section ?? .general) : spots.standing(row.spot) == nil ? .general : .spotOf(row.spot)))
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
        await run(SettingCall.setting(row.spot, row.key, to: value.isEmpty ? nil : value), as: "setting set")
    }

    public func set(_ row: SettingRow, on isOn: Bool) async {
        await set(row, to: String(isOn))
    }

    public func remove(_ row: SettingRow) async {
        pending[row.item] = ""
        await run(SettingCall.removing(row.spot, row.key), as: "setting remove")
    }

    public func use(theme name: String) async {
        await run(ThemeCall.use(name), as: "theme use")
    }

    public func duplicate(theme name: String) async {
        await run(ThemeCall.duplicate(name), as: "theme duplicate")
    }

    public func delete(theme name: String) async {
        await run(ThemeCall.delete(name), as: "theme delete", says: true)
    }

    public func themePrompt(words: String) async -> String? {
        guard let api = model?.runs.api, let used = looks.first(where: \.isUsed) else { return nil }
        let answer = await api.answer(PromptCall.theme(used.name, words: words), as: "prompt theme")
        guard answer.code == 0 else {
            say(answer.errors)
            return nil
        }
        return answer.output
    }

    public func allow(_ spot: String) async {
        await run(AccessCall.grant(spot, end: false), as: "access grant")
    }

    public func review(_ spot: String, use: SpotUse) async {
        await run(SpotCall.allow(spot, use: use.rawValue), as: "spot allow")
    }

    public func ask(_ access: MacAccess) async {
        guard access == .accessibility else { return openPane(of: access) }
        await run(AccessCall.ask(access.rawValue), as: "access ask")
    }

    public func openPane(of access: MacAccess) {
        guard let pane = access.pane else { return }
        model?.host.open(pane)
    }

    public func endGrant() async {
        await run(AccessCall.grant(nil, end: true), as: "access grant")
    }

    public func restart() async {
        await run(AppCall.restart, as: "app restart")
    }

    public func say(_ words: String) {
        model?.toast(ToastNote(words: words))
    }

    func run(_ call: any NounCall, as name: String, says: Bool = false) async {
        guard let api = model?.runs.api else { return }
        let answer = await api.answer(call, as: name)
        if answer.code != 0, let line = answer.errors.split(separator: "\n").last { model?.toast(.failure(String(line))) }
        if answer.code == 0, says, let line = answer.output.split(separator: "\n").last { say(String(line)) }
        await read()
    }
}
