import Foundation
import Observation
import OpenspotCore

/// The state of the sandbox window. It reads a sheet from typed text, a file it watches, or a script that it runs through
/// the same sheet as the panel. A script that is a spot of the plugins folder is a Try: it also shows the card of the spot,
/// read as the open panel reads it, and the log of its calls, to which its own calls add.
@MainActor
@Observable
final class SpotSandboxModel {
    private static let watchPause: Duration = .milliseconds(500)

    private(set) var sandbox = SheetSandbox()
    private let sheet: SpotRun?
    let file: URL?
    /// The model of the plugins folder, which draws the card of a spot that is tried.
    let spots: SpotsModel?
    /// The ID of the spot that is tried.
    let id: String?
    /// The log of the calls of the spot that is tried.
    private(set) var calls = ""
    @ObservationIgnored private var written: Date?

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

    init(path: String?) {
        let file = path.map { URL(fileURLWithPath: $0) }
        self.file = file
        var spots: SpotsModel?
        var entry: SpotsModel.Entry?
        if let file, FileManager.default.isExecutableFile(atPath: file.path) {
            let model = SpotsModel(host: SpotQuietHost.shared, runs: SpotRuns(log: SpotFiles.standard.log))
            model.reload()
            entry = model.entries.first { $0.command.url.resolvingSymlinksInPath().path == file.resolvingSymlinksInPath().path }
            spots = entry == nil ? nil : model
            sheet = entry.flatMap { model.sheets[$0.id] } ?? SpotRuns().sheet(for: SheetSandbox.command(file: file))
        } else {
            sheet = nil
        }
        self.spots = spots
        id = entry?.id
        sheet?.onReport = { [weak self] in self?.take($0) }
        reload()
        watch()
    }

    /// The card of the spot that is tried, as the model last read it.
    var card: SpotsModel.Entry? {
        spots?.entries.first { $0.id == id }
    }

    /// The title of the window.
    var title: String {
        card.map { "Try \($0.command.name)" } ?? "Openspot sandbox"
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

    private func take(_ report: SpotRun.Report) {
        switch report {
        case .frame(let text): sandbox.note(frame: text)
        case .failure(let text), .toast(let text), .failureWithFix(let text, _): sandbox.record(text)
        case .listChange, .chooseFiles, .closed: break
        }
    }

    /// Reads the file or runs the script again, with the card of a spot that is tried.
    private func reload() {
        guard let file else { return }
        written = Self.modified(file)
        if let spots, let id {
            spots.reload()
            if spots.sheets[id]?.command.readsState == true { spots.sheets[id]?.read(need: .change) }
        }
        if let sheet {
            sheet.close()
            sheet.open(need: .change) {}
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
                if let id = self.id {
                    let calls = SpotFiles.standard.log.text(of: id)
                    if calls != self.calls { self.calls = calls }
                }
            }
        }
    }

    private static func modified(_ file: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date
    }
}
