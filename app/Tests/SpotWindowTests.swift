import XCTest
@testable import OpenspotCore

@MainActor
final class SpotWindowTests: XCTestCase {
    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: FakeHost!
    private var model: SpotsModel!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-window-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        suite = "openspot-window-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        host = FakeHost()
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path],
            home: folder,
            defaults: defaults
        )
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2))
        host.model = model
        model.runs.api = CommandAPI(mac: Mac(), places: files, app: ModelApp(model: model), runs: model.runs)
    }

    override func tearDown() async throws {
        model.quit()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: folder)
    }

    private var spots: URL {
        folder.appendingPathComponent("spots", isDirectory: true)
    }

    private func windowSpot() async throws {
        try TestSpot(toml: "title = 'Board'", body: "printf 'item=a\\ntitle=Apple\\n'").write(to: spots.spotFile("board"))
        _ = try model.files.config.change { $0.arrangement.set(isWindow: true, of: "board") }
        await model.reload()
    }

    func testASecondOpenBringsTheSameWindowToTheFront() async throws {
        try await windowSpot()
        model.isShown = true

        XCTAssertTrue(model.open("board"))
        try await wait("the window") { self.host.windows == ["board"] }
        XCTAssertTrue(model.open("board"))
        try await wait("the window again") { self.host.windows == ["board", "board"] }

        XCTAssertEqual(model.runs.floating, ["board"])
        XCTAssertEqual(host.landings, [])
        XCTAssertFalse(model.isShown)
    }

    func testAWindowKeyInSpotTomlIsUnknown() async throws {
        try TestSpot(toml: "title = 'Board'\nwindow = 'settings'").write(to: spots.spotFile("board"))
        await model.reload()

        XCTAssertNotNil(model.entry("board")?.spot.fault)
    }
}
