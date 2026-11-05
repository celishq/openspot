import Foundation
import Observation
import OpenspotCore

@MainActor
@Observable
final class ShelfModel {
    private(set) var rows: [Row] = []
    private(set) var problems: [String] = []
    var query = "" {
        didSet { selected = 0 }
    }
    var selected = 0

    var visibleRows: [Row] {
        SearchQuery(text: query).matching(rows)
    }

    func reload() async {
        let scan = (try? PluginFolder.standard().scan()) ?? ScanResult(plugins: [], refused: [])
        var rows: [Row] = []
        var problems = scan.refused.map { "\($0.file): \($0.reason)" }
        for command in scan.commands {
            do {
                let result = try await PluginRun(command: command, query: "", timeout: 2).execute()
                rows.append(contentsOf: result.rows)
                problems.append(contentsOf: result.errors.map { "\(command.name): bad row \($0)" })
            } catch {
                problems.append("\(command.name): \(error)")
            }
        }
        self.rows = rows
        self.problems = problems
    }

    func moveSelection(by step: Int) {
        let count = visibleRows.count
        guard count > 0 else { return }
        selected = min(max(selected + step, 0), count - 1)
    }

    func runSelected() -> Bool {
        let list = visibleRows
        guard list.indices.contains(selected) else { return false }
        run(list[selected])
        return true
    }

    func run(_ row: Row) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", row.run]
        try? process.run()
    }
}
