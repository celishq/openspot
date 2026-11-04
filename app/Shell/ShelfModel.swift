import Foundation
import Observation
import OpenspotCore

@MainActor
@Observable
final class ShelfModel {
    private(set) var rows: [Row] = []
    private(set) var problems: [String] = []

    func reload() async {
        let folder = PluginFolder.url()
        let scan = (try? PluginScanner.scan(folder)) ?? ScanResult(plugins: [], refused: [])
        var rows: [Row] = []
        var problems = scan.refused.map { "\($0.file): \($0.reason)" }
        for plugin in scan.plugins {
            do {
                let result = try await PluginRunner.run(plugin, query: "", timeout: 2)
                rows.append(contentsOf: result.rows)
                problems.append(contentsOf: result.errors.map { "\(plugin.name): bad row \($0)" })
            } catch {
                problems.append("\(plugin.name): \(error)")
            }
        }
        self.rows = rows
        self.problems = problems
    }

    func run(_ row: Row) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", row.run]
        try? process.run()
    }
}
