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

    private func write(_ name: String, in place: URL, header: String = "") throws {
        let lines = header.split(separator: "\n").map { "# \($0)\n" }.joined()
        try "#!/bin/sh\n\(lines)\n".writeScript(to: place.appendingPathComponent(name.inSpotFolder))
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
        try write("apps.sh", in: core, header: "title=Core apps")
        try write("apps.sh", in: folder, header: "title=My apps")

        XCTAssertEqual(try names(enabled: []), ["My apps"])
        XCTAssertEqual(try names(enabled: ["apps"]), ["My apps"])
    }

    func testASpotThatIsOnLoadsThePartsItPlaces() throws {
        try write("cpu.sh", in: core, header: "on=clock.5")
        try "#!/bin/sh\n# title=Overview\n# grid.square=cpu\n".writeScript(to: core.appendingPathComponent("overview.spot/overview.sh"))

        let off = try SpotsFolder(url: folder, core: core, enabled: []).scan()
        XCTAssertEqual(off.scripts.map(\.id), [])

        let on = try SpotsFolder(url: folder, core: core, enabled: ["overview"]).scan()
        XCTAssertEqual(on.spots.filter(\.headerState.isOnGrid).map(\.name), ["Overview"])
        XCTAssertEqual(on.scripts.map(\.id), ["cpu"])
        XCTAssertEqual(on.refused, [])
    }

    func testAWidgetInTheSpotsFolderCanPlaceACorePart() throws {
        try write("cpu.sh", in: core, header: "on=clock.5")
        try "#!/bin/sh\n# title=Mine\n# grid.square=cpu\n".writeScript(to: folder.appendingPathComponent("mine.sh"))

        let scan = try SpotsFolder(url: folder, core: core, enabled: []).scan()

        XCTAssertEqual(scan.spots.filter(\.headerState.isOnGrid).map(\.name), ["Mine"])
        XCTAssertEqual(scan.refused, [])
    }

    func testTheFolderOfACoreSpotHoldsItsFilesAndIsNoSpot() throws {
        let files = core.appendingPathComponent("party", isDirectory: true)
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
        try write("party.sh", in: core, header: "title=Party")
        try write("shared.sh", in: files)

        let scan = try SpotsFolder(url: folder, core: core, enabled: ["party"]).scan()

        XCTAssertEqual(scan.spots.map(\.id), ["party"])
        XCTAssertEqual(scan.spots.map(\.name), ["Party"])
        XCTAssertEqual(scan.refused, [])
    }

    func testEachLetterOfTheDefaultConfigIsALetterOfOneSpotThatShips() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let config = Config(text: try String(contentsOf: repo.appendingPathComponent("app/defaults.toml"), encoding: .utf8))
        let spots = try FileManager.default.contentsOfDirectory(atPath: repo.appendingPathComponent("spots").path)
        let app = try SpotsFolder(url: folder, core: repo.appendingPathComponent("spots")).scan().spots.filter(\.isBuiltIn).map(\.id)

        XCTAssertEqual(config.faults, [])
        for choice in config.arrangement.choices {
            XCTAssertTrue(app.contains(choice.id) || spots.contains { $0.hasPrefix("\(choice.id).") }, choice.id)
            if let letter = choice.letter { XCTAssertNotNil(CommandKey(name: letter), choice.id) }
        }
        XCTAssertEqual(config.arrangement.letters(over: SpotArrangement()).count, config.arrangement.choices.filter { $0.letter?.isEmpty == false }.count)
    }

    func testAFaultInACoreSpotThatIsOffStaysQuiet() throws {
        try write("bad.sh", in: core, header: "read=never")

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

    func testTheChoicesLeaveOutPartsWithNoCard() throws {
        try write("cpu.sh", in: core, header: "on=clock.5")
        try write("apps.sh", in: core)
        try "#!/bin/sh\n# title=Overview\n# grid.square=cpu\n".writeScript(to: core.appendingPathComponent("overview.spot/overview.sh"))

        XCTAssertEqual(SpotsFolder(url: folder, core: core).coreChoices().map(\.name), ["Apps", "Overview"])
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

    func testACoreWidgetSharesWithItsPartsFromTheCoreFolder() throws {
        try write("cpu.sh", in: core, header: "on=clock.5")
        try "#!/bin/sh\n# title=Overview\n# grid.square=cpu\n".writeScript(to: core.appendingPathComponent("overview.spot/overview.sh"))
        let scan = try SpotsFolder(url: folder, core: core, enabled: ["overview"]).scan()

        let spot = try SpotFolder(sharing: XCTUnwrap(scan.spots.first { $0.name == "Overview" }), from: scan)

        XCTAssertEqual(spot.files.map(\.path), ["overview.spot/overview.sh", "cpu.spot/cpu.sh"])
        XCTAssertEqual(spot.files.last?.isExecutable, true)
    }

    func testTheConfigReadsAndWritesEnabled() throws {
        let config = Config(text: "[[spots]]\nid = \"apps\"\nenabled = true\n\n[[spots]]\nid = \"files\"\nenabled = false\n")

        XCTAssertEqual(config.faults, [])
        XCTAssertEqual(config.arrangement.enabled, ["apps"])

        var arrangement = config.arrangement
        arrangement.set(isEnabled: true, of: "links")
        arrangement.set(isEnabled: false, of: "apps")
        XCTAssertEqual(arrangement.enabled, ["links"])
        XCTAssertEqual(Config(text: arrangement.text).arrangement.enabled, ["links"])
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
