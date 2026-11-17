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
    var renaming: String?
    @ObservationIgnored let stage: SpotsModel
    @ObservationIgnored private let themes: ThemeFolder
    @ObservationIgnored private let panel: SpotsModel
    @ObservationIgnored private let appearance: NSAppearance?
    @ObservationIgnored private var drawn = Theme()

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

    private func draw(_ theme: Theme) {
        SpotLoadedTheme.shared.take(theme)
        SpotType.take(theme.type)
        stage.lay(theme)
        if theme.space != drawn.space || theme.radius != drawn.radius || theme.type != drawn.type { layout += 1 }
        drawn = theme
    }
}
