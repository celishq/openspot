import AppKit
import Observation
import OpenspotCore

@MainActor
@Observable
final class SpotThemeModel {
    private(set) var names: [String] = []
    private(set) var inUse = ThemeFolder.builtInName
    private(set) var groups: [String] = []
    private(set) var grouped: [String: [ThemeRow]] = [:]
    private(set) var fault: String?
    private(set) var layout = 0
    private(set) var isDark: Bool
    private(set) var lit: ThemeMark?
    private(set) var tip: String?
    private(set) var picked: String?
    var renaming: String?
    @ObservationIgnored private var rows: [ThemeRow] = []
    @ObservationIgnored let stage: SpotsModel
    @ObservationIgnored private let themes: ThemeFolder
    @ObservationIgnored private let panel: SpotsModel
    @ObservationIgnored private let appearance: NSAppearance?
    @ObservationIgnored private var drawn = Theme()
    @ObservationIgnored private var marks = ThemeMarks()
    @ObservationIgnored private var marksScroll: CGFloat = 0
    @ObservationIgnored private var litIndex: Int?
    @ObservationIgnored private var held: (mark: ThemeMark, row: ThemeRow, value: ConfigDocument.Value)?
    @ObservationIgnored private var pending: (id: String, write: @MainActor () -> Void, wait: Task<Void, Never>)?
    @ObservationIgnored private var loading: Task<Void, Never>?
    @ObservationIgnored private var working: Task<Void, Never>?
    @ObservationIgnored private var isClosed = false

    private static let writePause: Duration = .milliseconds(500)

    var isBuiltIn: Bool {
        ThemeFolder.isBuiltIn(inUse)
    }

    init(panel: SpotsModel) {
        self.panel = panel
        themes = ThemeFolder.standard(environment: panel.files.environment)
        stage = SpotsModel(host: SpotQuietHost.shared, files: panel.files, runs: SpotRuns(showing: panel.runs.shownFrames))
        appearance = NSApp.appearance
        isDark = SpotTheme.isDark(NSApp.effectiveAppearance)
        follow()
        refresh()
        loading = Task { [stage] in
            await stage.reload()
            guard !Task.isCancelled else { return }
            stage.panelWillShow()
        }
    }

    nonisolated deinit {}

    func show(isDark next: Bool) {
        guard next != isDark else { return }
        isDark = next
        NSApp.appearance = NSAppearance(named: next ? .darkAqua : .aqua)
    }

    func refresh() {
        act { _ in }
    }

    func use(_ name: String) {
        guard name != inUse else { return }
        act { _ = try $0.use(name) }
    }

    func make() {
        act { _ = try $0.make() }
    }

    func duplicate() {
        let name = inUse
        act { _ = try $0.duplicate(name) }
    }

    func rename(_ name: String, to new: String) {
        renaming = nil
        guard new != name else { return }
        act { try $0.rename(name, to: new) }
    }

    func delete(_ name: String) {
        act { try $0.delete(name) }
    }

    func preview(_ value: ConfigDocument.Value, of key: String, in section: String) {
        var next = rows
        guard let index = next.firstIndex(where: { row in row.key == key && row.cells.contains { $0.section == section } }) else { return }
        next[index].change(value, in: section)
        draw(Theme(rows: next))
    }

    func change(_ value: ConfigDocument.Value, of key: String, in section: String) {
        preview(value, of: key, in: section)
        let id = "\(section) \(key)"
        if pending?.id != id { save() }
        pending?.wait.cancel()
        let name = inUse
        let wait = Task { [weak self] in
            try? await Task.sleep(for: Self.writePause)
            guard !Task.isCancelled else { return }
            self?.save()
        }
        pending = (id, { [weak self] in self?.write(value, of: key, in: section, to: name) }, wait)
    }

    func save() {
        guard let pending else { return }
        self.pending = nil
        pending.wait.cancel()
        pending.write()
    }

    func write(_ value: ConfigDocument.Value?, of key: String, in section: String) {
        write(value, of: key, in: section, to: inUse)
    }

    func point(at location: CGPoint?) {
        guard held == nil else { return }
        if stage.gridScroll != marksScroll { mark() }
        light(location.flatMap(marks.index(at:)))
    }

    func drag(by translation: CGSize) {
        if held == nil, !isBuiltIn, let lit, let row = rows.first(where: { $0.id == lit.id }), let value = row.cells.first?.value {
            held = (lit, row, value)
        }
        guard let held, let start = held.row.cells.first?.value.number else { return }
        let next = held.mark.value(after: translation, from: start, kind: held.row.kind)
        guard next != held.value else { return }
        self.held?.value = next
        tip = "\(held.mark.key) \(Self.words(of: next))"
        preview(next, of: held.mark.key, in: held.mark.section)
    }

    func drop() {
        guard let held else { return }
        self.held = nil
        guard held.value != held.row.cells.first?.value else { return }
        write(held.value, of: held.mark.key, in: held.mark.section)
    }

    func close() {
        save()
        isClosed = true
        loading?.cancel()
        stage.quit()
        NSApp.appearance = appearance
        let previous = working
        let themes = themes
        working = Task { [panel] in
            await previous?.value
            let theme = await Self.run({ _ in }, in: themes).read.theme
            SpotLoadedTheme.shared.take(theme)
            SpotLoadedTheme.shared.layOut(theme)
            panel.take(theme)
        }
    }

    private func write(_ value: ConfigDocument.Value?, of key: String, in section: String, to name: String) {
        act { try $0.write(key, in: section, to: value, of: name) }
    }

    private func act(_ work: @escaping @Sendable (ThemeFolder) throws -> Void) {
        save()
        let previous = working
        let themes = themes
        working = Task { [weak self] in
            await previous?.value
            let (fault, read) = await Self.run(work, in: themes)
            self?.take(read, fault: fault)
        }
    }

    @concurrent
    private nonisolated static func run(_ work: @Sendable (ThemeFolder) throws -> Void, in themes: ThemeFolder) async -> (fault: String?, read: ThemeRead) {
        var fault: String?
        do {
            try work(themes)
        } catch {
            fault = SpotsModel.reason(error)
        }
        return (fault, read(themes))
    }

    private nonisolated static func read(_ themes: ThemeFolder) -> ThemeRead {
        let inUse = themes.readInUse()
        return ThemeRead(names: themes.scan(), inUse: inUse, rows: (try? themes.readRows(of: inUse)) ?? [], theme: themes.read())
    }

    private func take(_ read: ThemeRead, fault: String?) {
        if read.names != names { names = read.names }
        if read.inUse != inUse { inUse = read.inUse }
        if read.rows != rows {
            rows = read.rows
            let order = rows.map(\.group).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            if order != groups { groups = order }
            grouped = Dictionary(grouping: rows, by: \.group)
        }
        let next = fault ?? read.theme.faults.first
        if next != self.fault { self.fault = next }
        guard !isClosed else { return }
        draw(read.theme)
        panel.take(read.theme)
    }

    private func follow() {
        withObservationTracking {
            _ = stage.placements
            _ = stage.openSheetID
            _ = stage.formRect
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.mark()
                self?.follow()
            }
        }
    }

    private func mark() {
        marks = stage.themeMarks()
        marksScroll = stage.gridScroll
        guard let litIndex else { return }
        let next = marks.all.indices.contains(litIndex) && marks.all[litIndex].id == lit?.id ? marks.all[litIndex] : nil
        if held != nil, let next {
            lit = next
        } else if held == nil {
            light(next == nil ? nil : litIndex)
        }
    }

    private func light(_ index: Int?) {
        litIndex = index
        let next = index.map { marks.all[$0] }
        if next != lit { lit = next }
        if next?.id != picked { picked = next?.id }
        let words = next.flatMap { mark in
            rows.first { $0.id == mark.id }.flatMap { $0.cells.first }.map { "\(mark.key) \(Self.words(of: $0.value))\(isBuiltIn ? " · Duplicate to edit" : "")" }
        }
        if words != tip { tip = words }
    }

    private static func words(of value: ConfigDocument.Value) -> String {
        value.number.map { $0.formatted(.number.precision(.fractionLength(0...2))) } ?? ""
    }

    private func draw(_ theme: Theme) {
        guard !isClosed else { return }
        SpotLoadedTheme.shared.take(theme)
        stage.lay(theme)
        if theme.space != drawn.space || theme.radius != drawn.radius || theme.type != drawn.type || theme.motion != drawn.motion {
            SpotLoadedTheme.shared.layOut(theme)
            layout += 1
        }
        drawn = theme
        mark()
    }
}

private struct ThemeRead: Sendable {
    let names: [String]
    let inUse: String
    let rows: [ThemeRow]
    let theme: Theme
}
