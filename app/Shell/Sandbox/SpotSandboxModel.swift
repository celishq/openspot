import Foundation
import Observation
import OpenspotCore

/// The state of the sandbox window. It reads a sheet from typed text, a file it watches, or a script that it runs through
/// the same sheet as the panel. It reads, writes and watches the file away from the main thread.
@MainActor
@Observable
final class SpotSandboxModel {
    nonisolated private static let watchPause: Duration = .milliseconds(500)

    private(set) var sandbox = SheetSandbox()
    private let sheet: SpotRun?
    let file: URL?
    @ObservationIgnored private let disk: SpotSandboxFile?
    @ObservationIgnored private var watch: Task<Void, Never>?

    var fileName: String? {
        file?.lastPathComponent
    }

    /// Whether the left side is a script's answer, which a person does not edit here.
    var isScript: Bool {
        sheet != nil
    }

    var panel: SheetParts? {
        sheet?.panel ?? sandbox.panel
    }

    /// `isCareful` runs a script in Careful mode, with no use (Z8).
    init(path: String?, isCareful: Bool = false) {
        let file = path.map { URL(fileURLWithPath: $0) }
        self.file = file
        disk = file.map(SpotSandboxFile.init)
        if let file, FileManager.default.isExecutableFile(atPath: file.path) {
            let runs = SpotRuns()
            runs.isCareful = isCareful
            sheet = runs.sheet(for: SheetSandbox.command(file: file))
        } else {
            sheet = nil
        }
        sheet?.onReport = { [weak self] in self?.take($0) }
        startWatch()
    }

    nonisolated deinit {}

    /// Takes text that a person typed, and saves it when the sandbox has a file.
    func edit(_ text: String) {
        sandbox.take(text: text)
        guard let disk, sheet == nil else { return }
        Task.detached { await disk.write(text) }
    }

    func set(_ part: SpotPart, to value: String) {
        sandbox.set(value, of: part.id)
        sheet?.set(part, to: value)
    }

    func press(_ part: SpotPart) {
        sandbox.press(part.id)
        sheet?.press(part)
    }

    /// Stops the watch of the file and the script, once the window closes.
    func close() {
        watch?.cancel()
        sheet?.close()
    }

    private func take(_ report: SpotRun.Report) {
        switch report {
        case .frame(let text): sandbox.note(frame: text)
        case .failure(let text), .toast(let text), .failureWithFix(let text, _): sandbox.record(text)
        case .listChange, .chooseFiles, .closed, .landed: break
        }
    }

    /// Reads the file, or runs the script, at once and again each time something else changes the file.
    private func startWatch() {
        guard let disk else { return }
        watch = Task.detached { [weak self] in
            while !Task.isCancelled {
                if let text = await disk.change() {
                    guard let self else { return }
                    await self.reload(text)
                }
                try? await Task.sleep(for: Self.watchPause)
            }
        }
    }

    private func reload(_ text: String) {
        if let sheet {
            sheet.close()
            sheet.open(need: .change) {}
        } else {
            sandbox.take(text: text)
        }
    }
}
