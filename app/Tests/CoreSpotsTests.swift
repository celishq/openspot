import XCTest
@testable import OpenspotCore

final class CoreSpotsTests: XCTestCase {
    private var root: URL!
    private var folder: URL!
    private var core: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-core-\(UUID().uuidString)")
        folder = root.appendingPathComponent("spots")
        core = root.appendingPathComponent("core")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: core, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ name: String, in place: URL, toml: String = "") throws {
        try "#!/bin/sh\n".writeScript(to: place.appendingPathComponent(name.inSpotFolder), toml: toml)
    }

    private func names(enabled: Set<String>) throws -> [String] {
        try SpotsFolder(url: folder, core: core, enabled: enabled).scan().spots.map(\.name)
    }

    func testACoreSpotIsOffUntilItIsTurnedOn() throws {
        try write("apps.sh", in: core)
        try write("files.sh", in: core)

        XCTAssertEqual(try names(enabled: []), [])
        XCTAssertEqual(try names(enabled: ["files"]), ["Files"])
    }

    func testAFileInTheSpotsFolderWinsOverACoreSpotAndIsAlwaysOn() throws {
        try write("apps.sh", in: core, toml: "title = 'Core apps'")
        try write("apps.sh", in: folder, toml: "title = 'My apps'")

        XCTAssertEqual(try names(enabled: []), ["My apps"])
        XCTAssertEqual(try names(enabled: ["apps"]), ["My apps"])
    }

    func testTheFolderOfACoreSpotHoldsItsFilesAndIsNoSpot() throws {
        let files = core.appendingPathComponent("party", isDirectory: true)
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
        try write("party.sh", in: core, toml: "title = 'Party'")
        try write("shared.sh", in: files)

        let scan = try SpotsFolder(url: folder, core: core, enabled: ["party"]).scan()

        XCTAssertEqual(scan.spots.map(\.id), ["party"])
        XCTAssertEqual(scan.spots.map(\.name), ["Party"])
        XCTAssertEqual(scan.refused, [])
    }

    func testEachSpotOfTheDefaultConfigIsASpotThatShips() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let config = Config(text: try String(contentsOf: repo.appendingPathComponent("app/defaults.toml"), encoding: .utf8))
        let spots = try FileManager.default.contentsOfDirectory(atPath: repo.appendingPathComponent("spots").path)
        let app = try SpotsFolder(url: folder, core: repo.appendingPathComponent("spots")).scan().spots.filter(\.isBuiltIn).map(\.id)

        XCTAssertEqual(config.faults, [])
        for choice in config.arrangement.choices {
            XCTAssertTrue(app.contains(choice.id) || spots.contains { $0.hasPrefix("\(choice.id).") }, choice.id)
        }
    }

    func testTheDefaultGridOpensWithNewSpotAsAStripThenSpotsAndStoreWide() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let defaults = Config(text: try String(contentsOf: repo.appendingPathComponent("app/defaults.toml"), encoding: .utf8)).arrangement

        XCTAssertEqual(defaults.choices.prefix(3).map(\.id), ["openspot/new", "openspot/spots", "openspot/store"])
        XCTAssertEqual(defaults.size(of: "openspot/new"), .strip)
        XCTAssertEqual(defaults.size(of: "openspot/spots"), .wide)
        XCTAssertEqual(defaults.size(of: "openspot/store"), .wide)
    }

    @MainActor func testAMetricThatAGetTurnsOnShowsItsCard() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let defaults = Config(text: try String(contentsOf: repo.appendingPathComponent("app/defaults.toml"), encoding: .utf8)).arrangement
        let metrics = ["battery", "cpu", "devices", "disk", "memory"]
        let scan = try SpotsFolder(url: folder, core: repo.appendingPathComponent("spots"), enabled: Set(metrics)).scan()

        for id in metrics {
            let spot = try XCTUnwrap(scan.spots.first { $0.id == id }, id)
            XCTAssertTrue(SpotsModel.Entry(spot: spot, run: nil, defaults: defaults).isOnGrid, id)
        }
    }

    func testACoreSpotRunsInPlaceFromItsFolderInTheApp() throws {
        try write("apps.sh", in: core)

        let apps = try XCTUnwrap(SpotsFolder(url: folder, core: core, enabled: ["apps"]).scan().spots.first)

        XCTAssertEqual(apps.url.resolvingSymlinksInPath().path, core.appendingPathComponent("apps.spot/apps.sh").resolvingSymlinksInPath().path)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), [])
    }

    func testAFaultInACoreSpotThatIsOffStaysQuiet() throws {
        try write("bad.sh", in: core, toml: "read = 'never'")

        XCTAssertEqual(try SpotsFolder(url: folder, core: core, enabled: []).scan().refused, [])
    }

    func testWithNoCoreFolderAScanGivesTheFolder() throws {
        try write("mine.sh", in: folder)
        let gone = root.appendingPathComponent("gone")

        XCTAssertEqual(try SpotsFolder(url: folder, core: gone, enabled: ["apps"]).scan().spots.map(\.name), ["Mine"])
    }

    func testAMissingSpotsFolderStillGivesTheCoreSpots() throws {
        try write("apps.sh", in: core)
        let gone = root.appendingPathComponent("gone")

        XCTAssertEqual(try SpotsFolder(url: gone, core: core, enabled: ["apps"]).scan().spots.map(\.name), ["Apps"])
    }

    func testAScanRunsNoCoreSpot() throws {
        let mark = root.appendingPathComponent("ran")
        try "#!/bin/sh\ntouch \"\(mark.path)\"\n".writeScript(to: core.appendingPathComponent("apps.spot/apps.sh"))

        _ = try SpotsFolder(url: folder, core: core, enabled: ["apps"]).scan()

        XCTAssertFalse(FileManager.default.fileExists(atPath: mark.path))
    }

    func testTheChoicesLeaveOutSpotsWithAClock() throws {
        try write("cpu.sh", in: core, toml: "on = ['clock.5']")
        try write("apps.sh", in: core)

        XCTAssertEqual(SpotsFolder(url: folder, core: core).coreChoices().map(\.name), ["Apps"])
    }

    func testACoreSpotCannotBeRemovedAndStaysOnTheDisk() throws {
        try write("apps.sh", in: core)
        let place = SpotsFolder(url: folder, core: core, enabled: ["apps"])
        let apps = try XCTUnwrap(place.scan().spots.first)

        XCTAssertTrue(place.isCore(apps))
        XCTAssertThrowsError(try place.remove(apps, discard: { _ in XCTFail("It discarded a core file.") }))
    }

    func testAFolderFileIsNotCore() throws {
        try write("mine.sh", in: folder)
        let place = SpotsFolder(url: folder, core: core)
        let mine = try XCTUnwrap(place.scan().spots.first)

        XCTAssertFalse(place.isCore(mine))
    }

    func testTheConfigReadsAndWritesEnabled() throws {
        let config = Config(text: "[[spots]]\nid = \"apps\"\nenabled = true\n\n[[spots]]\nid = \"files\"\nenabled = false\n")

        XCTAssertEqual(config.faults, [])
        XCTAssertEqual(config.arrangement.enabled, ["apps"])

        var arrangement = config.arrangement
        arrangement.set(isEnabled: true, of: "links")
        arrangement.set(isEnabled: false, of: "apps")
        XCTAssertEqual(arrangement.enabled, ["links"])
        var changed = config
        changed.arrangement = arrangement
        XCTAssertEqual(Config(text: changed.text).arrangement.enabled, ["links"])
    }

    func testTheStandardFolderTakesTheEnabledSpotsFromTheConfig() throws {
        let home = root.appendingPathComponent("config")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try "[[spots]]\nid = \"apps\"\nenabled = true\n".write(to: home.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        XCTAssertEqual(SpotsFolder.standard(environment: ["OPENSPOT_CONFIG": home.path], home: root).enabled, ["apps"])
    }

    func testEachRepoSpotHasASubtitle() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let place = SpotsFolder(url: folder, core: repo.appendingPathComponent("spots"))

        XCTAssertEqual(place.coreChoices().filter { $0.subtitle == nil }.map(\.name), [])
    }
}
