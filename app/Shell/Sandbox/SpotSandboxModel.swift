import Foundation
import Observation
import OpenspotCore

/// The state of the playground window. It runs a file that it keeps in step with the editor in place, or the spot that a
/// person types from a copy in a folder of its own, through the same sheet as the panel. Each edit runs again after a short
/// pause, and only the newest edit runs. It reads, writes and watches the file away from the main thread.
@MainActor
@Observable
final class SpotSandboxModel {
    nonisolated private static let watchPause: Duration = .milliseconds(500)
    private static let editPause: Duration = .milliseconds(300)
    private static let starter = "#!/bin/sh\n# title=Hello\n# on=sheet.open\nprintf 'text=hello\\ntitle=Hello\\ndetail=%s\\n' \"$OPENSPOT_REASON\"\n"

    private(set) var sandbox = SheetSandbox()
    private(set) var source = ""
    /// The text typed in the search of the sheet.
    private(set) var query = ""
    /// The place of the panel where the spot shows.
    private(set) var place = PlaygroundPlace.sheet
    /// Why the header cannot load, or nil when it loads.
    private(set) var fault: String?
    private(set) var spot: Spot?
    private(set) var sheet: SpotRun?
    let file: URL?
    let presets: [(name: String, text: String)]
    @ObservationIgnored private let runs = SpotRuns()
    @ObservationIgnored private let folder: URL
    @ObservationIgnored private let plugins = SpotFolder.standard().url
    @ObservationIgnored private let disk: SpotSandboxFile?
    @ObservationIgnored private var watch: Task<Void, Never>?
    @ObservationIgnored private var edits = 0

    var fileName: String? {
        file?.lastPathComponent
    }

    /// The `on` line that the spot needs before its place reads it, or nil when it has one.
    var lack: String? {
        spot.flatMap(place.lack)
    }

    /// The rows that the spot gives as answers to the text of the main search.
    var answers: [SpotItem] {
        sheet?.answers ?? []
    }

    var panel: SheetParts? {
        sheet?.panel ?? sandbox.panel
    }

    /// The card that the newest frame draws at the size of the spot, or nil when it draws none.
    var card: (layout: WidgetLayout, face: CardFace, size: SpotSize)? {
        guard let spot, !sandbox.text.isEmpty else { return nil }
        let face = SpotOutput(text: sandbox.text).face
        return face.layout(for: spot.size).map { ($0, face, spot.size) }
    }

    /// `isCareful` runs the spot in Careful mode, with no use (protocol: Trust).
    init(path: String?, isCareful: Bool = false) {
        let file = path.map { URL(fileURLWithPath: $0) }
        self.file = file
        disk = file.map(SpotSandboxFile.init)
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-playground-\(UUID().uuidString)")
        let guide = Bundle.main.url(forResource: "GUIDE", withExtension: "md").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        presets = SheetSandbox.presets(guide: guide)
        runs.isCareful = isCareful
        runs.onCall = { [weak self] record, reason in self?.sandbox.take(call: PlaygroundCall(record: record, reason: reason)) }
        runs.panelOpened()
        if file == nil { edit(Self.starter) }
        startWatch()
    }

    nonisolated deinit {}

    /// Takes the text of the spot that a person typed, saves it to the file, and runs it once the typing pauses.
    func edit(_ text: String) {
        source = text
        if let disk { Task.detached { await disk.write(text) } }
        edits += 1
        let edit = edits
        Task { [weak self] in
            try? await Task.sleep(for: Self.editPause)
            guard let self, edit == self.edits else { return }
            self.run(text)
        }
    }

    /// Types the text in the search of the place: the search of the sheet, or the main search.
    func search(_ text: String) {
        query = text
        if let sheet { place.type(text, in: sheet) }
    }

    /// Shows the spot in another place, which runs it as that place of the panel does.
    func choose(_ next: PlaygroundPlace) {
        guard next != place else { return }
        place = next
        guard let sheet else { return }
        sheet.close()
        place.show(sheet, query: query)
    }

    /// Runs the spot again as it is.
    func rerun() {
        guard let sheet else { return }
        if place == .sheet { sheet.read(need: .change) } else { place.show(sheet, query: query) }
    }

    func set(_ part: SpotPart, to value: String) {
        sandbox.set(value, of: part.id)
        sheet?.set(part, to: value)
    }

    /// Picks a row of the sheet or of the main search, which sends `open` with its id.
    func pick(_ item: SpotItem) {
        sandbox.record("open \(item.run)")
        sheet?.pick(item)
    }

    func press(_ part: SpotPart) {
        sandbox.press(part.id)
        sheet?.press(part)
    }

    /// Stops the watch of the file and the spot, and removes the copy, once the window closes.
    func close() {
        watch?.cancel()
        sheet?.close()
        runs.quit()
        try? FileManager.default.removeItem(at: folder)
    }

    /// Loads the header of the file, or of a copy of typed text, and opens a new sheet of it in place of the last one. A
    /// header that cannot load keeps the last sheet and shows why.
    private func run(_ text: String) {
        let (url, id) = SheetSandbox.place(of: file, text: text, plugins: plugins, scratch: folder)
        do {
            if file == nil {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                for old in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [] where old != url {
                    try? FileManager.default.removeItem(at: old)
                }
                try text.write(to: url, atomically: true, encoding: .utf8)
                if url.pathExtension != SpotFile.inlineExtension {
                    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
                }
            }
            guard let loaded = try SpotFile(file: url, id: id)?.spots.first else {
                fault = "This text is no spot. Start it with #!/bin/sh, or with // lines of a JavaScript header."
                return
            }
            fault = nil
            spot = loaded
            sheet?.close()
            let next = runs.sheet(for: loaded)
            next.onReport = { [weak self] in self?.take($0) }
            sheet = next
            place.show(next, query: query)
        } catch {
            fault = (error as? SpotError)?.reason ?? error.localizedDescription
        }
    }

    private func take(_ report: SpotRun.Report) {
        switch report {
        case .frame(let text): sandbox.note(frame: text)
        case .failure(let text), .toast(let text), .failureWithFix(let text, _): sandbox.record(text)
        case .listChange, .chooseFiles, .closed, .landed: break
        }
    }

    /// Reads the file at once, and again each time another app changes it.
    private func startWatch() {
        guard let disk else { return }
        watch = Task.detached { [weak self] in
            while !Task.isCancelled {
                if let text = await disk.change() {
                    guard let self else { return }
                    await self.load(text)
                }
                try? await Task.sleep(for: Self.watchPause)
            }
        }
    }

    private func load(_ text: String) {
        guard text != source else { return }
        source = text
        run(text)
    }
}
