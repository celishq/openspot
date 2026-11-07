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
        try write("apps.sh", in: core, header: "name=Core apps")
        try write("apps.sh", in: folder, header: "name=My apps")

        XCTAssertEqual(try names(enabled: []), ["My apps"])
        XCTAssertEqual(try names(enabled: ["apps"]), ["My apps"])
    }

    func testASpotThatIsOnLoadsThePartsItPlaces() throws {
        try write("cpu.sh", in: core, header: "read=5")
        try "[[widgets]]\nname = \"Overview\"\nlayout = \"single\"\nplaces = [\"cpu\"]\n".write(to: core.appendingPathComponent("overview.toml"), atomically: true, encoding: .utf8)

        let off = try PluginFolder(url: folder, core: core, enabled: []).scan()
        XCTAssertEqual(off.scripts.map(\.id), [])

        let on = try PluginFolder(url: folder, core: core, enabled: ["overview"]).scan()
        XCTAssertEqual(on.commands.map(\.name), ["Overview"])
        XCTAssertEqual(on.scripts.map(\.id), ["cpu"])
        XCTAssertEqual(on.refused, [])
    }

    func testAWidgetInThePluginsFolderCanPlaceACorePart() throws {
        try write("cpu.sh", in: core, header: "read=5")
        try "[[widgets]]\nname = \"Mine\"\nlayout = \"single\"\nplaces = [\"cpu\"]\n".write(to: folder.appendingPathComponent("mine.toml"), atomically: true, encoding: .utf8)

        let scan = try PluginFolder(url: folder, core: core, enabled: []).scan()

        XCTAssertEqual(scan.commands.map(\.name), ["Mine"])
        XCTAssertEqual(scan.refused, [])
    }

    func testAKeyOfAFolderFileWinsOverACoreSpot() throws {
        try write("mine.sh", in: folder, header: "key=a")
        try write("apps.sh", in: core, header: "key=a")

        let scan = try PluginFolder(url: folder, core: core, enabled: ["apps"]).scan()

        XCTAssertEqual(scan.commands.first { $0.name == "Mine" }?.key?.name, "a")
        XCTAssertNil(scan.commands.first { $0.name == "Apps" }?.key)
        XCTAssertEqual(scan.refused.map(\.file), ["apps"])
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
        try "[[widgets]]\nname = \"Overview\"\nlayout = \"single\"\nplaces = [\"cpu\"]\n".write(to: core.appendingPathComponent("overview.toml"), atomically: true, encoding: .utf8)

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
        try "[[widgets]]\nname = \"Overview\"\nlayout = \"single\"\nplaces = [\"cpu\"]\n".write(to: core.appendingPathComponent("overview.toml"), atomically: true, encoding: .utf8)
        let scan = try PluginFolder(url: folder, core: core, enabled: ["overview"]).scan()

        let spot = try SharedSpot(sharing: XCTUnwrap(scan.commands.first), from: scan)

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

    func testTheRepoSpotsGiveThirteenChoicesAndOverviewBringsItsFourParts() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let plugins = repo.appendingPathComponent("plugins")
        let place = PluginFolder(url: folder, core: plugins, enabled: ["overview"])

        XCTAssertEqual(place.coreChoices().count, 13)
        XCTAssertEqual(place.coreChoices().filter { $0.subtitle == nil }.map(\.name), [])
        XCTAssertEqual(Set(try place.scan().scripts.map(\.id)), ["agents", "battery", "cpu", "disk"])
    }
}
