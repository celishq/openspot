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

    private var log: URL {
        folder.appendingPathComponent("shows")
    }

    private var shows: [String] {
        ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    private func settingsSpot(window: String = "settings") async throws {
        let body = "at=$(sed -n 's/^input\\.at=//p')\necho \"$1 $at\" >> '\(log.path)'\nprintf 'item=a\\ntitle=Apple\\n'"
        try TestSpot(toml: "title = 'Settings'\nwindow = '\(window)'", body: body).write(to: spots.spotFile("settings"))
        await model.reload()
    }

    func testAWindowKeyGivesTheSpotItsNamedSize() async throws {
        try await settingsSpot()

        XCTAssertEqual(model.entry("settings")?.spot.window, .settings)
        XCTAssertEqual(WindowSize.settings.size, CGSize(width: 880, height: 620))
        XCTAssertLessThan(WindowSize.settings.minSize.width, WindowSize.settings.size.width)
        XCTAssertLessThan(WindowSize.settings.minSize.height, WindowSize.settings.size.height)
    }

    func testAWindowKeyOfAnUnknownSizeIsAFaultThatNamesTheSizes() async throws {
        try await settingsSpot(window: "huge")

        let faults = try XCTUnwrap(model.entry("settings")?.spot.fault?.faults)
        XCTAssertTrue(faults.contains { $0.contains("window = \"huge\"") && $0.contains("window = \"settings\"") }, "\(faults)")
    }

    func testASpotWithAWindowKeyOpensItsWindowWhateverThePersonChose() async throws {
        try await settingsSpot()
        _ = try model.files.config.change { $0.arrangement.set(isWindow: false, of: "settings") }
        await model.reload()

        model.press("settings")

        try await wait("the window") { self.host.windows == ["settings"] }
        XCTAssertEqual(model.place(ofSheet: "settings"), .window)
        XCTAssertEqual(host.shows, 0)
        XCTAssertNil(model.openSheetID)
    }

    func testASecondOpenBringsTheSameWindowToTheFront() async throws {
        try await settingsSpot()
        model.isShown = true

        XCTAssertTrue(model.open("settings"))
        try await wait("the window") { self.host.windows == ["settings"] }
        XCTAssertTrue(model.open("settings"))
        try await wait("the window again") { self.host.windows == ["settings", "settings"] }

        XCTAssertEqual(model.runs.floating, ["settings"])
        XCTAssertEqual(host.landings, [])
        XCTAssertFalse(model.isShown)
    }

    func testOpenAtHandsWhereToLandToTheShowOfTheWindow() async throws {
        try await settingsSpot()

        XCTAssertTrue(model.open("settings", at: "spot/notes"))
        try await wait("the show at the spot") { self.shows.contains("show spot/notes") }
        XCTAssertTrue(model.open("settings", at: "access/screen"))
        try await wait("the show at the access") { self.shows.contains("show access/screen") }

        XCTAssertEqual(host.windows, ["settings", "settings"])
        XCTAssertEqual(shows.filter { $0.hasSuffix("spot/notes") }.count, 1, "\(shows)")
    }

    func testAPlaceGivenBeforeTheWindowCanOpenIsKeptForItsOpen() async throws {
        XCTAssertFalse(model.open("settings", at: "access/screen"))
        try await settingsSpot()

        XCTAssertTrue(model.open("settings"))

        try await wait("the show at the access") { self.shows.contains("show access/screen") }
    }
}
