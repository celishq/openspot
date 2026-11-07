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
}
