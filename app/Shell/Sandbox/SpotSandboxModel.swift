import Foundation
import Observation
import OpenspotCore

@MainActor
@Observable
final class SpotSandboxModel {
    nonisolated private static let watchPause: Duration = .milliseconds(500)
    private static let editPause: Duration = .milliseconds(300)
    private static let starter = "#!/bin/sh\n# title=Hello\n# on=sheet.open\nprintf 'text=hello\\ntitle=Hello\\ndetail=%s\\n' \"$OPENSPOT_REASON\"\n"

    private(set) var sandbox = SheetSandbox()
    private(set) var source = ""
    private(set) var place = PlaygroundPlace.sheet
    private(set) var fault: String?
    private(set) var id: String?
    let file: URL?
    let presets: [(name: String, text: String)]
    @ObservationIgnored let panel: PlaygroundPanel
    @ObservationIgnored private let host = SpotPlaygroundHost()
    @ObservationIgnored private let folder: URL
    @ObservationIgnored private let spots = SpotsFolder.standard().url
    @ObservationIgnored private let disk: SpotSandboxFile?
    @ObservationIgnored private var watch: Task<Void, Never>?
    @ObservationIgnored private var edits = 0

    var fileName: String? {
        file?.lastPathComponent
    }

    var spot: Spot? {
        id.flatMap { id in panel.model.entries.first { $0.id == id }?.spot }
    }

    var lack: String? {
        spot.flatMap(place.lack)
    }

    init(path: String?, isCareful: Bool = false) {
        let file = path.map { URL(fileURLWithPath: $0) }
        self.file = file
        disk = file.map(SpotSandboxFile.init)
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-playground-\(UUID().uuidString)")
        let guide = Bundle.main.url(forResource: "GUIDE", withExtension: "md").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        presets = SheetSandbox.presets(guide: guide)
        panel = PlaygroundPanel(host: host, scratch: folder, defaults: UserDefaults(suiteName: "openspot-playground") ?? .standard)
        host.onNote = { [weak self] in self?.sandbox.record($0) }
        panel.model.runs.isCareful = isCareful
        panel.model.runs.onCall = { [weak self] record, reason in
            self?.sandbox.take(call: PlaygroundCall(record: record, reason: reason))
            if let frame = record.frames.last { self?.sandbox.note(frame: frame) }
        }
        if file == nil { edit(Self.starter) }
        startWatch()
    }

    nonisolated deinit {}

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

    func choose(_ next: PlaygroundPlace) {
        place = next
        if let id { panel.show(next, id: id) }
    }

    func rerun() {
        guard let id else { return }
        panel.model.reload()
        panel.model.panelWillShow(holding: [])
        if place == .sheet { panel.model.sheets[id]?.read(need: .change) }
    }

    func close() {
        watch?.cancel()
        panel.model.quit()
        try? FileManager.default.removeItem(at: folder)
    }

    private func run(_ text: String) {
        do {
            let placed = try panel.place(file: file, text: text, spots: spots)
            guard let url = panel.file, try SpotFile(file: url, id: placed)?.spots.first != nil else {
                fault = "This text is no spot. Start it with #!/bin/sh, or with // lines of a JavaScript header."
                return
            }
            fault = nil
            id = placed
            panel.show(place, id: placed)
        } catch {
            fault = (error as? SpotError)?.reason ?? error.localizedDescription
        }
    }

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
