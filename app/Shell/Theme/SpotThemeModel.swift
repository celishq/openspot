import AppKit
import Observation
import OpenspotCore

@MainActor
@Observable
final class SpotThemeModel {
    private(set) var names: [String] = []
    private(set) var inUse = ThemeFolder.builtInName
    private(set) var rows: [ThemeRow] = []
    private(set) var fault: String?
    private(set) var layout = 0
    private(set) var isDark: Bool
    private(set) var lit: ThemeMark?
    private(set) var tip: String?
    private(set) var picked: String?
    var renaming: String?
    @ObservationIgnored let stage: SpotsModel
    @ObservationIgnored private let themes: ThemeFolder
    @ObservationIgnored private let panel: SpotsModel
    @ObservationIgnored private let appearance: NSAppearance?
    @ObservationIgnored private var drawn = Theme()
    @ObservationIgnored private var marks = ThemeMarks()
    @ObservationIgnored private var marksScroll: CGFloat = 0
    @ObservationIgnored private var litIndex: Int?
    @ObservationIgnored private var held: (mark: ThemeMark, row: ThemeRow, value: ConfigDocument.Value)?

    var isBuiltIn: Bool {
        ThemeFolder.isBuiltIn(inUse)
    }

    init(panel: SpotsModel) {
        self.panel = panel
        themes = ThemeFolder.standard(environment: panel.files.environment)
        stage = SpotsModel(host: SpotQuietHost.shared, files: panel.files, runs: SpotRuns())
        appearance = NSApp.appearance
        isDark = SpotTheme.isDark(NSApp.effectiveAppearance)
        scan()
        follow()
        Task { [stage] in
            await stage.reload()
            stage.panelWillShow()
        }
    }

    nonisolated deinit {}

    func show(isDark next: Bool) {
        guard next != isDark else { return }
        isDark = next
        NSApp.appearance = NSAppearance(named: next ? .darkAqua : .aqua)
    }

    func use(_ name: String) {
        guard name != inUse else { return }
        act { _ = try themes.use(name) }
    }

    func make() {
        act { _ = try themes.make() }
    }

    func duplicate() {
        act { _ = try themes.duplicate(inUse) }
    }

    func rename(_ name: String, to new: String) {
        renaming = nil
        guard new != name else { return }
        act { try themes.rename(name, to: new) }
    }

    func delete(_ name: String) {
        act { try themes.delete(name) }
    }

    func preview(_ value: ConfigDocument.Value, of key: String, in section: String) {
        var next = rows
        guard let index = next.firstIndex(where: { row in row.key == key && row.cells.contains { $0.section == section } }) else { return }
        next[index].change(value, in: section)
        draw(Theme(rows: next))
    }

    func write(_ value: ConfigDocument.Value?, of key: String, in section: String) {
        let name = inUse
        act { try themes.write(key, in: section, to: value, of: name) }
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
        stage.quit()
        NSApp.appearance = appearance
        let theme = themes.read()
        SpotType.take(theme.type)
        stage.lay(theme)
    }

    private func act(_ work: () throws -> Void) {
        do {
            try work()
            fault = nil
        } catch {
            fault = (error as? SpotError)?.reason ?? error.localizedDescription
        }
        scan()
    }

    private func scan() {
        let found = themes.scan()
        if found != names { names = found }
        inUse = themes.readInUse()
        let next = (try? themes.readRows(of: inUse)) ?? []
        if next != rows { rows = next }
        let theme = themes.read()
        if fault == nil, let first = theme.faults.first { fault = first }
        draw(theme)
        panel.take(theme)
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
        SpotLoadedTheme.shared.take(theme)
        SpotType.take(theme.type)
        stage.lay(theme)
        if theme.space != drawn.space || theme.radius != drawn.radius || theme.type != drawn.type { layout += 1 }
        drawn = theme
        mark()
    }
}
