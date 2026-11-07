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
        try file.begin()

        XCTAssertFalse(isFirst)
    }

    func testASpotInTheFolderIsNotAFirstLaunch() throws {
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        try "#!/bin/sh\n".writeScript(to: plugins.appendingPathComponent("mine.sh"))

        XCTAssertFalse(isFirst)
    }

    func testBeginLeavesAFileThatHoldsEachDefaultAndKeepsAnOldFile() throws {
        try file.begin()
        XCTAssertEqual(file.read().faults, [])

        try file.set("panel_key", to: "option+space")
        try file.begin()
        XCTAssertEqual(file.read().panelKey, Shortcut(text: "option+space"))
    }

    func testTheKeyToastNamesTheKeyInUse() throws {
        XCTAssertEqual(Shortcut.standard.openHint, "Press ⌃Space to open Openspot")
        XCTAssertEqual(try XCTUnwrap(Shortcut(text: "option+k")).openHint, "Press ⌥K to open Openspot")
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
