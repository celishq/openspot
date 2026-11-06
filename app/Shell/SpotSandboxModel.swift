import Foundation
import Observation
import OpenspotCore

/// The state of the sandbox window. It reads a sheet from typed text, a file it watches, or a script that it runs through
/// the same sheet as the panel.
@MainActor
@Observable
final class SpotSandboxModel {
    private static let watchPause: Duration = .milliseconds(500)

    private(set) var sandbox = SheetSandbox()
    private let sheet: SpotSheet?
    let file: URL?
    @ObservationIgnored private var written: Date?

    var fileName: String? {
        file?.lastPathComponent
    }

    /// Whether the left side is a script's answer, which a person does not edit here.
    var isScript: Bool {
        sheet != nil
    }

    var panel: SpotPanel? {
        sheet?.panel ?? sandbox.panel
    }

    init(path: String?) {
        let file = path.map { URL(fileURLWithPath: $0) }
        self.file = file
        if let file, FileManager.default.isExecutableFile(atPath: file.path) {
            let isLive = PluginHeader(url: file).block.flag("live") ?? false
            sheet = SpotSheet(command: PluginCommand(id: file.lastPathComponent, name: file.lastPathComponent, url: file, kind: .list, isLive: isLive))
        } else {
            sheet = nil
        }
        sheet?.onReport = { [weak self] in self?.take($0) }
        reload()
        watch()
    }

    nonisolated deinit {}

    /// Takes text that a person typed, and saves it when the sandbox has a file.
    func edit(_ text: String) {
        sandbox.take(text: text)
        guard let file, sheet == nil else { return }
        try? text.write(to: file, atomically: true, encoding: .utf8)
        written = Self.modified(file)
    }

    func set(_ part: SpotPart, to value: String) {
        sandbox.set(value, of: part.id)
        sheet?.set(part, to: value)
    }

    func press(_ part: SpotPart) {
        sandbox.press(part.id)
        sheet?.press(part)
    }

    private func take(_ report: SpotSheet.Report) {
        switch report {
        case .frame(let text): sandbox.note(frame: text)
        case .failure(let text), .toast(let text): sandbox.record(text)
        case .output, .listChange: break
        }
    }

    /// Reads the file or runs the script again.
    private func reload() {
        guard let file else { return }
        written = Self.modified(file)
        if let sheet {
            sheet.close()
            sheet.open {}
        } else {
            sandbox.take(text: (try? String(contentsOf: file, encoding: .utf8)) ?? "")
        }
    }

    /// Reads the file again each time something else changes it, such as a model that writes there.
    private func watch() {
        guard let file else { return }
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.watchPause)
                guard let self else { return }
                if Self.modified(file) != self.written { self.reload() }
            }
        }
    }

    private static func modified(_ file: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date
    }
}
