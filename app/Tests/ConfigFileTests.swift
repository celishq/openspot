import XCTest
@testable import OpenspotCore

final class ConfigFileTests: XCTestCase {
    private var folder: URL!

    private var file: ConfigFile {
        ConfigFile.standard(environment: ["OPENSPOT_CONFIG": folder.path], home: URL(fileURLWithPath: "/home"))
    }

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-config-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func write(_ text: String) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try text.write(to: file.url, atomically: true, encoding: .utf8)
    }

    func testTheFileIsInTheConfigFolder() {
        XCTAssertEqual(ConfigFile.standard(environment: [:], home: URL(fileURLWithPath: "/home")).url.path, "/home/.config/openspot/config.toml")
        XCTAssertEqual(file.url.path, folder.appendingPathComponent("config.toml").path)
    }

    func testNoFileGivesTheStandardKey() {
        XCTAssertEqual(file.read(), Config(text: ""))
        XCTAssertEqual(file.read().panelKey, .standard)
        XCTAssertEqual(file.read().faults, [])
    }

    func testReadsTheKey() throws {
        try write("# mine\npanel_key = \"option+space\"\n")

        XCTAssertEqual(file.read().panelKey, Shortcut(text: "option+space"))
        XCTAssertEqual(file.read().faults, [])
    }

    func testTheFixKeyIsCommandOptionOUntilTheFileNamesAnother() {
        XCTAssertEqual(Config(text: "").fixKey, Shortcut(text: "cmd+option+o"))
        XCTAssertEqual(Config(text: "fix_key = \"ctrl+option+f\"\n").fixKey, Shortcut(text: "ctrl+option+f"))
        XCTAssertNil(Config(text: "fix_key = \"f\"\n").fixKey)
        XCTAssertEqual(Config(text: "fix_key = \"f\"\n").faults.count, 1)
    }

    func testTheGridHasNoSidePanelsUntilTheFileAsksForThem() {
        XCTAssertEqual(Config(text: "").panels, GridPanels())
        XCTAssertEqual(Config(text: "left_panel = true\nright_panel = true\n").panels, GridPanels(hasLeft: true, hasRight: true))
        XCTAssertEqual(Config(text: "left_panel = 1\n").faults, ["config.toml: left_panel is true or false."])
    }

    func testASpotKeepsItsSidePanel() throws {
        var arrangement = SpotArrangement()
        arrangement.set(panel: .left, of: "a")
        arrangement.set(panel: .center, of: "b")
        try file.write(arrangement)

        XCTAssertEqual(file.read().arrangement.panel(of: "a"), .left)
        XCTAssertNil(file.read().arrangement.panel(of: "b"))
        XCTAssertEqual(Config(text: "[[spots]]\nid = \"a\"\nside = \"up\"\n").faults, ["config.toml: a cannot use the side up."])
    }

    func testABadKeyGivesNoKeyAndAFault() {
        let config = Config(text: "panel_key = \"k\"\n")

        XCTAssertNil(config.panelKey)
        XCTAssertEqual(config.faults, ["config.toml: panel_key cannot use k. Hold cmd, ctrl or option with a letter, a digit, an arrow, space, return or tab."])
    }

    func testAKeyThatIsNotTextIsAFault() {
        XCTAssertNil(Config(text: "panel_key = 1\n").panelKey)
        XCTAssertEqual(Config(text: "panel_key = 1\n").faults.count, 1)
    }

    func testAnUnknownKeyIsAFaultAndTheOthersStillLoad() {
        let config = Config(text: "theme = \"dark\"\npanel_key = \"cmd+k\"\n")

        XCTAssertEqual(config.panelKey, Shortcut(text: "cmd+k"))
        XCTAssertEqual(config.faults, ["config.toml: theme is not a setting."])
    }

    func testAFileThatCannotBeReadGivesNoKeyAndItsLine() {
        let config = Config(text: "panel_key\n")

        XCTAssertNil(config.panelKey)
        XCTAssertEqual(config.faults, ["config.toml: line 1: expected a key and a value"])
    }

    func testSettingAKeyChangesOnlyItsLine() throws {
        try write("# mine\n\npanel_key = \"cmd+k\"\n# end\n")

        try file.set("panel_key", to: "ctrl+k")

        XCTAssertEqual(try String(contentsOf: file.url, encoding: .utf8), "# mine\n\npanel_key = \"ctrl+k\"\n# end\n")
    }

    func testSettingAKeyAddsItsLineAndMakesTheFile() throws {
        try file.set("panel_key", to: "ctrl+k")

        XCTAssertEqual(try String(contentsOf: file.url, encoding: .utf8), "panel_key = \"ctrl+k\"\n")

        try write("# mine")
        try file.set("panel_key", to: "ctrl+j")

        XCTAssertEqual(try String(contentsOf: file.url, encoding: .utf8), "# mine\npanel_key = \"ctrl+j\"\n")
    }

    func testASettingIsKeptForItsSpotAndRemovedWithNoValue() throws {
        try file.set(setting: "folder", of: "repos", to: "~/Developer")
        try file.set(setting: "editor", of: "repos", to: "/Applications/Zed.app")
        try file.set(setting: "folder", of: "notes", to: "~/Notes")
        try file.set(setting: "folder", of: "repos", to: "~/Code")
        try file.set(setting: "editor", of: "repos", to: nil)

        let config = file.read()
        XCTAssertEqual(config.setting("folder", of: "repos"), "~/Code")
        XCTAssertNil(config.setting("editor", of: "repos"))
        XCTAssertEqual(config.setting("folder", of: "notes"), "~/Notes")
        XCTAssertEqual(config.faults, [])
    }

    func testASettingKeepsQuotesBackslashesAndNewLines() throws {
        let value = "a \"b\" \\c\nd"

        try file.set(setting: "note", of: "x", to: value)

        XCTAssertEqual(file.read().setting("note", of: "x"), value)
    }

    func testOtherWritesKeepTheSettings() throws {
        try file.set(setting: "folder", of: "repos", to: "~/Code")

        try file.set("panel_key", to: "option+space")
        try file.turn("cpu", on: true)
        try file.write(keys: [GlobalKey(spot: "move", command: "left", shortcut: try XCTUnwrap(Shortcut(text: "ctrl+left")))])

        XCTAssertEqual(file.read().setting("folder", of: "repos"), "~/Code")
        XCTAssertEqual(file.read().keys.map(\.act), [.command("left")])
    }

    func testWritesAtTheSameTimeLoseNoSetting() throws {
        let file = file

        DispatchQueue.concurrentPerform(iterations: 20) { index in
            try? file.set(setting: "key\(index)", of: "spot", to: "\(index)")
        }

        let config = file.read()
        XCTAssertEqual((0..<20).compactMap { config.setting("key\($0)", of: "spot") }, (0..<20).map(String.init))
    }

    func testASettingWithNoKeyIsAFault() throws {
        try write("[[settings]]\nspot = \"repos\"\nvalue = \"x\"\n")

        XCTAssertEqual(file.read().faults, ["config.toml: a setting needs a spot, a key and a value."])
    }
}
