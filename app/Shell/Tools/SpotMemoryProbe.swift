#if OPENSPOT_TOOLS
import AppKit
import OpenspotCore

@MainActor
final class SpotMemoryProbe {
    private static let action = "memory"
    private static let settle: Duration = .seconds(8)
    private static let pause: Duration = .seconds(4)
    private static let megabyte = 1_048_576.0

    private let model: SpotsModel
    private let output: String
    private var lines: [String] = []

    init?(model: SpotsModel, environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let output = environment["OPENSPOT_PROBE"], environment["OPENSPOT_ACTION"] == Self.action else { return nil }
        self.model = model
        self.output = output
        SpotSheetWindow.showsQuietly = true
    }

    func run() {
        Task { @MainActor in
            try? await Task.sleep(for: Self.settle)
            read("idle")
            await measure("settings") { _ = self.model.openSettings() }
            await measure("store") { Task { _ = await StoreWindow.show(model: self.model, id: nil, search: nil) } }
            await measure("playground") { Task { await SpotPlayground.show(path: nil) } }
            await measure("settings again") { _ = self.model.openSettings() }
            await measure("store again") { Task { _ = await StoreWindow.show(model: self.model, id: nil, search: nil) } }
            FileManager.default.createFile(atPath: output, contents: Data((lines.joined(separator: "\n") + "\n").utf8))
            exit(0)
        }
    }

    private func measure(_ name: String, open: () -> Void) async {
        open()
        try? await Task.sleep(for: Self.pause)
        read("\(name) open")
        for window in NSApp.windows.compactMap({ $0 as? SpotSheetWindow }) where window.isVisible {
            window.close()
        }
        try? await Task.sleep(for: Self.pause)
        read("\(name) closed")
    }

    private func read(_ state: String) {
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0) }
        }
        let megabytes = result == 0 ? Double(info.ri_phys_footprint) / Self.megabyte : 0
        lines.append("\(state)\t\(String(format: "%.1f", megabytes))")
    }
}
#endif
