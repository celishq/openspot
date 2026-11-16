import XCTest
@testable import OpenspotCore

final class FirstLaunchTests: XCTestCase {
    private var root: URL!
    private var spots: URL!
    private var file: ConfigFile!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-first-\(UUID().uuidString)")
        spots = root.appendingPathComponent("spots")
        file = ConfigFile(url: root.appendingPathComponent("config.toml"))
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private var isFirst: Bool {
        SpotsFolder(url: spots).isFirstLaunch(config: file)
    }

    func testNoConfigAndNoFolderIsAFirstLaunch() {
        XCTAssertTrue(isFirst)
    }

    func testNoConfigAndAnEmptyFolderIsAFirstLaunch() throws {
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)

        XCTAssertTrue(isFirst)
    }

    func testAConfigWithNoSpotsIsNotAFirstLaunch() throws {
        try file.begin(enabling: [])

        XCTAssertFalse(isFirst)
    }

    func testASpotInTheFolderIsNotAFirstLaunch() throws {
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        try "#!/bin/sh\n".writeScript(to: spots.spotFile("mine"))

        XCTAssertFalse(isFirst)
    }

    func testBeginWritesTheStartingSpotsAndKeepsAnOldFile() throws {
        try file.begin(enabling: ["apps", "files"])
        XCTAssertEqual(file.read().faults, [])
        XCTAssertEqual(file.read().arrangement.enabled, ["apps", "files"])

        try file.set("panel-key", to: "option+space")
        try file.begin(enabling: ["links"])
        XCTAssertEqual(file.read().panelKey, Shortcut(text: "option+space"))
        XCTAssertEqual(file.read().arrangement.enabled, ["apps", "files"])
    }

    func testOnlyQuietRepoSpotsStartOn() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let place = SpotsFolder(url: spots, core: repo.appendingPathComponent("spots"))

        let starting = place.startingSpots()

        XCTAssertFalse(starting.isEmpty)
        XCTAssertTrue(starting.contains("settings"))
        let scan = try SpotsFolder(url: spots, core: place.core, enabled: Set(starting)).scan()
        XCTAssertEqual(scan.refused, [])
        XCTAssertFalse(scan.scripts.contains { $0.read?.seconds != nil })
    }

    func testWithNoCoreFolderNoSpotsStartOn() {
        XCTAssertEqual(SpotsFolder(url: spots).startingSpots(), [])
    }

    func testTheKeyToastNamesTheKeyInUse() throws {
        XCTAssertEqual(Shortcut.standard.openHint, "Press `⌃Space` to open Openspot")
        XCTAssertEqual(try XCTUnwrap(Shortcut(text: "option+k")).openHint, "Press `⌥K` to open Openspot")
    }

    private static let launchHeader = "title=Hello\non=sheet.open\noffers=none\nedits=launch"

    @MainActor
    private func firstLaunch(core launch: Bool, own: Bool = false) async throws -> (SpotsModel, FakeHost) {
        let core = root.appendingPathComponent("core", isDirectory: true)
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: core.appendingPathComponent("openspot.spot"), withIntermediateDirectories: true)
        let spot = TestSpot(header: Self.launchHeader, body: "printf 'row=a\\ntitle=A\\n'")
        if launch { try spot.write(to: core.spotFile("openspot/hello")) }
        if own { try spot.write(to: spots.spotFile("openspot/hello")) }
        let suite = "openspot-first-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let host = FakeHost()
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": root.appendingPathComponent("config").path, "OPENSPOT_CORE": core.path],
            home: root,
            defaults: defaults
        )
        let model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2, prepare: { await host.prepare($0, glyphs: $1) }))
        host.model = model
        addTeardownBlock { @MainActor in
            model.quit()
            defaults.removePersistentDomain(forName: suite)
        }
        return (model, host)
    }

    @MainActor
    func testTheFirstLaunchOpensOnTheLaunchSpot() async throws {
        let (model, host) = try await firstLaunch(core: true)

        await model.beginFirstLaunch()

        try await wait("the launch sheet") { model.openSheetID == "openspot/hello" }
        XCTAssertEqual(host.presents, 1)
    }

    @MainActor
    func testWithNoLaunchSpotTheFirstLaunchShowsTheGrid() async throws {
        let (model, host) = try await firstLaunch(core: false)

        await model.beginFirstLaunch()

        XCTAssertEqual(host.presents, 1)
        XCTAssertNil(model.openSheetID)
    }

    @MainActor
    func testAnOwnSpotCannotTakeTheLaunchRole() async throws {
        let (model, _) = try await firstLaunch(core: false, own: true)

        await model.reload()

        XCTAssertNil(model.runs.launchSheet)
    }
}
