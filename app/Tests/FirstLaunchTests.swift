import XCTest
@testable import OpenspotCore

final class FirstLaunchTests: XCTestCase {
    private var root: URL!
    private var plugins: URL!
    private var file: ConfigFile!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-first-\(UUID().uuidString)")
        plugins = root.appendingPathComponent("plugins")
        file = ConfigFile(url: root.appendingPathComponent("config.toml"))
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private var isFirst: Bool {
        PluginFolder(url: plugins).isFirstLaunch(config: file)
    }

    func testNoConfigAndNoFolderIsAFirstLaunch() {
        XCTAssertTrue(isFirst)
    }

    func testNoConfigAndAnEmptyFolderIsAFirstLaunch() throws {
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)

        XCTAssertTrue(isFirst)
    }

    func testAConfigWithNoSpotsIsNotAFirstLaunch() throws {
        try file.begin(enabling: [])

        XCTAssertFalse(isFirst)
    }

    func testASpotInTheFolderIsNotAFirstLaunch() throws {
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        try "#!/bin/sh\n".writeScript(to: plugins.appendingPathComponent("mine.sh"))

        XCTAssertFalse(isFirst)
    }

    func testBeginWritesTheStartingSpotsAndKeepsAnOldFile() throws {
        try file.begin(enabling: ["apps", "files"])
        XCTAssertEqual(file.read().faults, [])
        XCTAssertEqual(file.read().arrangement.enabled, ["apps", "files"])

        try file.set("panel_key", to: "option+space")
        try file.begin(enabling: ["links"])
        XCTAssertEqual(file.read().panelKey, Shortcut(text: "option+space"))
        XCTAssertEqual(file.read().arrangement.enabled, ["apps", "files"])
    }

    func testOnlyQuietRepoSpotsStartOn() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let place = PluginFolder(url: plugins, core: repo.appendingPathComponent("plugins"))

        let starting = place.startingSpots()

        XCTAssertFalse(starting.isEmpty)
        let scan = try PluginFolder(url: plugins, core: place.core, enabled: Set(starting)).scan()
        XCTAssertEqual(scan.refused, [])
        XCTAssertFalse(scan.scripts.contains { $0.read?.seconds != nil })
    }

    func testWithNoCoreFolderNoSpotsStartOn() {
        XCTAssertEqual(PluginFolder(url: plugins).startingSpots(), [])
    }

    func testTheKeyToastNamesTheKeyInUse() throws {
        XCTAssertEqual(Shortcut.standard.openHint, "Press `⌃Space` to open Openspot")
        XCTAssertEqual(try XCTUnwrap(Shortcut(text: "option+k")).openHint, "Press `⌥K` to open Openspot")
    }

    func testTheFirstLaunchListOffersTheLoginRowAndAPickTurnsItOn() throws {
        final class Fake: @unchecked Sendable { var isOn = false }
        let fake = Fake()
        let item = LoginItem(isOn: { fake.isOn }, set: { fake.isOn = $0 })
        let catalog = SpotCatalog(folder: plugins, core: nil, config: file, login: item)

        let rows = PluginOutput(text: try catalog.answer(["read"])).items
        XCTAssertEqual(rows.map(\.run), [LoginItem.run, SpotCatalog.buildRun])
        XCTAssertEqual(rows.first?.hides, [SpotCatalog.reviewID])

        XCTAssertEqual(try catalog.answer(["open", LoginItem.run]), "")
        XCTAssertTrue(fake.isOn)
    }

    func testTheNormalListHasNoLoginRow() throws {
        let catalog = SpotCatalog(folder: plugins, core: nil, config: file)

        XCTAssertEqual(PluginOutput(text: try catalog.answer(["read"])).items.map(\.run), [SpotCatalog.buildRun])
    }
}
