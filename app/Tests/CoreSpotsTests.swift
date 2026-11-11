import XCTest
@testable import OpenspotCore

final class CoreSpotsTests: XCTestCase {
    private var root: URL!
    private var folder: URL!
    private var core: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-core-\(UUID().uuidString)")
        folder = root.appendingPathComponent("plugins")
        core = root.appendingPathComponent("core")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: core, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ name: String, in place: URL, header: String = "") throws {
        let lines = header.split(separator: "\n").map { "# \($0)\n" }.joined()
        try "#!/bin/sh\n\(lines)\n".writeScript(to: place.appendingPathComponent(name))
    }

    private func names(enabled: Set<String>) throws -> [String] {
        try PluginFolder(url: folder, core: core, enabled: enabled).scan().commands.map(\.name)
    }

    func testACoreSpotIsOffUntilItIsTurnedOn() throws {
        try write("apps.sh", in: core)
        try write("files.sh", in: core)

        XCTAssertEqual(try names(enabled: []), [])
        XCTAssertEqual(try names(enabled: ["files"]), ["Files"])
    }

    func testAFileInThePluginsFolderWinsOverACoreSpotAndIsAlwaysOn() throws {
        try write("apps.sh", in: core, header: "title=Core apps")
        try write("apps.sh", in: folder, header: "title=My apps")

        XCTAssertEqual(try names(enabled: []), ["My apps"])
        XCTAssertEqual(try names(enabled: ["apps"]), ["My apps"])
    }

    func testASpotThatIsOnLoadsThePartsItPlaces() throws {
        try write("cpu.sh", in: core, header: "read=5")
        try "[[widgets]]\ntitle = \"Overview\"\ngrid = [\"cpu\"]\nsize = \"square\"\n".write(to: core.appendingPathComponent("overview.toml"), atomically: true, encoding: .utf8)

        let off = try PluginFolder(url: folder, core: core, enabled: []).scan()
        XCTAssertEqual(off.scripts.map(\.id), [])

        let on = try PluginFolder(url: folder, core: core, enabled: ["overview"]).scan()
        XCTAssertEqual(on.commands.filter(\.headerState.isOnGrid).map(\.name), ["Overview"])
        XCTAssertEqual(on.scripts.map(\.id), ["cpu"])
        XCTAssertEqual(on.refused, [])
    }

    func testAWidgetInThePluginsFolderCanPlaceACorePart() throws {
        try write("cpu.sh", in: core, header: "read=5")
        try "[[widgets]]\ntitle = \"Mine\"\ngrid = [\"cpu\"]\nsize = \"square\"\n".write(to: folder.appendingPathComponent("mine.toml"), atomically: true, encoding: .utf8)

        let scan = try PluginFolder(url: folder, core: core, enabled: []).scan()

        XCTAssertEqual(scan.commands.filter(\.headerState.isOnGrid).map(\.name), ["Mine"])
        XCTAssertEqual(scan.refused, [])
    }

    func testTheFolderOfACoreSpotHoldsItsFilesAndIsNoSpot() throws {
        let files = core.appendingPathComponent("party", isDirectory: true)
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
        try write("party.sh", in: core, header: "title=Party")
        try write("shared.sh", in: files)

        let scan = try PluginFolder(url: folder, core: core, enabled: ["party"]).scan()

        XCTAssertEqual(scan.commands.map(\.id), ["party"])
        XCTAssertEqual(scan.commands.map(\.name), ["Party"])
        XCTAssertEqual(scan.refused, [])
    }

    func testEachLetterOfTheDefaultConfigIsALetterOfOneSpotThatShips() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let config = Config(text: try String(contentsOf: repo.appendingPathComponent("app/defaults.toml"), encoding: .utf8))
        let plugins = try FileManager.default.contentsOfDirectory(atPath: repo.appendingPathComponent("plugins").path)
        let shipped = ShippedSpot.commands(folder: repo, guide: repo, app: "").map(\.id)

        XCTAssertEqual(config.faults, [])
        for choice in config.arrangement.choices {
            XCTAssertTrue(shipped.contains(choice.id) || plugins.contains { $0.hasPrefix("\(choice.id).") }, choice.id)
            if let letter = choice.letter { XCTAssertNotNil(CommandKey(name: letter), choice.id) }
        }
        XCTAssertEqual(config.arrangement.letters(over: SpotArrangement()).count, config.arrangement.choices.filter { $0.letter?.isEmpty == false }.count)
    }

    func testAFaultInACoreSpotThatIsOffStaysQuiet() throws {
        try write("bad.sh", in: core, header: "read=never")

        XCTAssertEqual(try PluginFolder(url: folder, core: core, enabled: []).scan().refused, [])
    }

    func testWithNoCoreFolderAScanGivesTheFolder() throws {
        try write("mine.sh", in: folder)
        let gone = root.appendingPathComponent("gone")

        XCTAssertEqual(try PluginFolder(url: folder, core: gone, enabled: ["apps"]).scan().commands.map(\.name), ["Mine"])
    }

    func testAMissingPluginsFolderStillGivesTheCoreSpots() throws {
        try write("apps.sh", in: core)
        let gone = root.appendingPathComponent("gone")

        XCTAssertEqual(try PluginFolder(url: gone, core: core, enabled: ["apps"]).scan().commands.map(\.name), ["Apps"])
    }

    func testAScanRunsNoCoreSpot() throws {
        let mark = root.appendingPathComponent("ran")
        try "#!/bin/sh\ntouch \"\(mark.path)\"\n".writeScript(to: core.appendingPathComponent("apps.sh"))

        _ = try PluginFolder(url: folder, core: core, enabled: ["apps"]).scan()

        XCTAssertFalse(FileManager.default.fileExists(atPath: mark.path))
    }

    func testTheChoicesLeaveOutPartsWithNoCard() throws {
        try write("cpu.sh", in: core, header: "read=5")
        try write("apps.sh", in: core)
        try "[[widgets]]\ntitle = \"Overview\"\ngrid = [\"cpu\"]\nsize = \"square\"\n".write(to: core.appendingPathComponent("overview.toml"), atomically: true, encoding: .utf8)

        XCTAssertEqual(PluginFolder(url: folder, core: core).coreChoices().map(\.name), ["Apps", "Overview"])
    }

    func testACoreSpotCannotBeRemovedAndStaysOnTheDisk() throws {
        try write("apps.sh", in: core)
        let place = PluginFolder(url: folder, core: core, enabled: ["apps"])
        let apps = try XCTUnwrap(place.scan().commands.first)

        XCTAssertTrue(place.isCore(apps))
        XCTAssertThrowsError(try place.remove(apps, discard: { _ in XCTFail("It discarded a core file.") }))
    }

    func testAFolderFileIsNotCore() throws {
        try write("mine.sh", in: folder)
        let place = PluginFolder(url: folder, core: core)
        let mine = try XCTUnwrap(place.scan().commands.first)

        XCTAssertFalse(place.isCore(mine))
    }

    func testACoreWidgetSharesWithItsPartsFromTheCoreFolder() throws {
        try write("cpu.sh", in: core, header: "read=5")
        try "[[widgets]]\ntitle = \"Overview\"\ngrid = [\"cpu\"]\nsize = \"square\"\n".write(to: core.appendingPathComponent("overview.toml"), atomically: true, encoding: .utf8)
        let scan = try PluginFolder(url: folder, core: core, enabled: ["overview"]).scan()

        let spot = try SharedSpot(sharing: XCTUnwrap(scan.commands.first { $0.name == "Overview" }), from: scan)

        XCTAssertEqual(spot.files.map(\.path), ["overview.toml", "cpu.sh"])
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

        XCTAssertEqual(PluginFolder.standard(environment: ["OPENSPOT_CONFIG": home.path], home: root).enabled, ["apps"])
    }

    func testEachRepoSpotHasASubtitle() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let place = PluginFolder(url: folder, core: repo.appendingPathComponent("plugins"))

        XCTAssertEqual(place.coreChoices().filter { $0.subtitle == nil }.map(\.name), [])
    }
}
