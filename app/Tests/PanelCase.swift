import XCTest
@testable import OpenspotCore

@MainActor
class PanelCase: XCTestCase {
    var folder: URL!
    var defaults: UserDefaults!
    var suite = ""
    var host: FakeHost!
    var model: SpotsModel!

    var stopPause: TimeInterval {
        0.2
    }

    var motionLength: TimeInterval? {
        nil
    }

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-panel-case-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        suite = "openspot-panel-case-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let host = FakeHost()
        self.host = host
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path],
            home: folder,
            defaults: defaults
        )
        model = SpotsModel(host: host, files: files, runs: SpotRuns(opening: SheetOpening(motionLength: motionLength), stopPause: stopPause, prepare: { await host.prepare($0, glyphs: $1) }))
        host.model = model
    }

    override func tearDown() async throws {
        model.quit()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: folder)
    }

    func takeCalls() {
        model.runs.api = CommandAPI(mac: Mac(), places: model.files, app: ModelApp(model: model), runs: model.runs)
    }

    var spots: URL {
        folder.appendingPathComponent("spots", isDirectory: true)
    }

    let back = ActionKey(name: "[", isCommand: true)
    let forward = ActionKey(name: "]", isCommand: true)
    let escape = ActionKey(name: "escape")
    let toGrid = ActionKey(name: "escape", isCommand: true)

    func script(_ name: String, toml: String, _ body: String) throws {
        try TestSpot(toml: toml, body: "\(body)").write(to: spots.spotFile(name))
    }

    var titles: [String] {
        model.openItems?.shown.map(\.title) ?? []
    }

    func openList() async throws {
        try script("list", toml: "title = 'List'\npages = ['*']", """
        page=$(sed -n 's/^input\\.route=//p')
        if [ -n "$page" ]; then printf 'item=x\\ntitle=Detail %s\\n' "$page"; else printf 'item=a\\ntitle=A\\nroute=a\\n'; fi
        """)
        try script("other", toml: "", "printf 'item=o\\ntitle=Other\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("list")
        try await wait("the open list") { self.model.transition.phase == .open && self.titles == ["A"] }
    }

    func openPage() async throws {
        model.runSelectedItem()
        try await wait("the page") { self.titles == ["Detail a"] }
    }
}
