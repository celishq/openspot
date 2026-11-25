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
        try write("# mine\npanel-key = \"option+space\"\n")

        XCTAssertEqual(file.read().panelKey, Shortcut(text: "option+space"))
        XCTAssertEqual(file.read().faults, [])
    }

    func testTheFixKeyIsCommandOptionOUntilTheFileNamesAnother() {
        XCTAssertEqual(Config(text: "").fixKey, Shortcut(text: "cmd+option+o"))
        XCTAssertEqual(Config(text: "fix-key = \"ctrl+option+f\"\n").fixKey, Shortcut(text: "ctrl+option+f"))
        XCTAssertNil(Config(text: "fix-key = \"f\"\n").fixKey)
        XCTAssertEqual(Config(text: "fix-key = \"f\"\n").faults.count, 1)
    }

    func testTheGridHasFourColumnsUntilTheFileAsksForSixOrEight() {
        XCTAssertEqual(Config(text: "").grid, GridLayout(columns: 4))
        XCTAssertEqual(Config(text: "columns = 8\n").grid, GridLayout(columns: 8))
        XCTAssertEqual(Config(text: "columns = 5\n").faults, ["config.toml: columns is 4, 6 or 8."])
        XCTAssertEqual(Config(text: "left_panel = true\n").faults, [])
    }

    func testTheKeysOfTheOldSidePanelsGoAtTheNextWrite() {
        var config = Config(text: "left_panel = true\nright_panel = false\ncareful = true\n\n[[spots]]\nid = \"a\"\nside = \"left\"\n")
        config.set(columns: 6)
        XCTAssertEqual(config.text, "careful = true\ncolumns = 6\n\n[[spots]]\nid = \"a\"\n")
    }

    func testASpotKeepsItsCellForEachWidth() throws {
        var arrangement = SpotChoices()
        arrangement.set(cell: GridCell(row: 2, column: 3), of: "a", columns: 4)
        arrangement.set(cell: GridCell(row: 0, column: 7), of: "a", columns: 8)
        try file.write(arrangement)

        XCTAssertEqual(file.read().arrangement.cells(of: "a"), [4: GridCell(row: 2, column: 3), 8: GridCell(row: 0, column: 7)])
        XCTAssertNil(file.read().arrangement.cells(of: "b"))
        XCTAssertEqual(Config(text: "[[spots]]\nid = \"a\"\nside = \"left\"\n").faults, [])
        XCTAssertEqual(Config(text: "[[spots]]\nid = \"a\"\nplaces = { 4 = \"up\" }\n").faults.count, 1)
    }

    func testTheBrowsersOfTheFileAddToTheBuiltInOnesAndMayChangeTheFamilyOfOne() {
        let config = Config(text: "[browsers]\n\"company.thebrowser.dia\" = \"chromium\"\n\"com.kagi.kagimacOS\" = \"safari\"\n\"com.google.Chrome\" = \"safari\"\n")

        XCTAssertEqual(config.faults, [])
        XCTAssertEqual(config.browsers.map(\.bundleID), Config(text: "").browsers.map(\.bundleID) + ["company.thebrowser.dia", "com.kagi.kagimacOS"])
        XCTAssertEqual(config.browsers.first { $0.bundleID == "com.google.Chrome" }?.family, .safari)
        XCTAssertEqual(config.browsers.first { $0.bundleID == "com.google.Chrome" }?.name, "Google Chrome")
        XCTAssertEqual(config.browsers.first { $0.bundleID == "company.thebrowser.dia" }?.family, .chromium)
    }

    func testABrowserOfAnUnknownFamilyIsAFaultAndTheOthersStillLoad() {
        let config = Config(text: "[browsers]\n\"org.mozilla.firefox\" = \"gecko\"\n\"company.thebrowser.dia\" = \"chromium\"\n")

        XCTAssertEqual(config.faults, ["config.toml: the browser org.mozilla.firefox is \"chromium\" or \"safari\"."])
        XCTAssertEqual(config.browsers.last?.bundleID, "company.thebrowser.dia")
    }

    func testABadKeyGivesNoKeyAndAFault() {
        let config = Config(text: "panel-key = \"k\"\n")

        XCTAssertNil(config.panelKey)
        XCTAssertEqual(config.faults, ["config.toml: panel-key cannot use k. Hold cmd, ctrl or option with a letter, a digit, a sign, an arrow, space, return or tab."])
    }

    func testAKeyThatIsNotTextIsAFault() {
        XCTAssertNil(Config(text: "panel-key = 1\n").panelKey)
        XCTAssertEqual(Config(text: "panel-key = 1\n").faults.count, 1)
    }

    func testAnUnknownKeyIsAFaultAndTheOthersStillLoad() {
        let config = Config(text: "look = \"dark\"\npanel-key = \"cmd+k\"\n")

        XCTAssertEqual(config.panelKey, Shortcut(text: "cmd+k"))
        XCTAssertEqual(config.faults, ["config.toml: look is not a setting."])
    }

    func testAFileThatCannotBeReadGivesNoKeyAndItsLine() {
        let config = Config(text: "panel-key\n")

        XCTAssertNil(config.panelKey)
        XCTAssertEqual(config.faults, ["config.toml: line 1: expected a key and a value"])
    }

    func testSettingAKeyChangesOnlyItsLine() throws {
        try write("# mine\n\npanel-key = \"cmd+k\"\n# end\n")

        try file.set("panel-key", to: "ctrl+k")

        XCTAssertEqual(try String(contentsOf: file.url, encoding: .utf8), "# mine\n\npanel-key = \"ctrl+k\"\n# end\n")
    }

    func testSettingAKeyAddsItsLineAndMakesTheFile() throws {
        try file.set("panel-key", to: "ctrl+k")

        XCTAssertEqual(try String(contentsOf: file.url, encoding: .utf8), "panel-key = \"ctrl+k\"\n")

        try write("# mine")
        try file.set("panel-key", to: "ctrl+j")

        XCTAssertEqual(try String(contentsOf: file.url, encoding: .utf8), "# mine\npanel-key = \"ctrl+j\"\n")
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

        try file.set("panel-key", to: "option+space")
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

    func testASpotNameWithAQuoteSurvivesASave() throws {
        try file.turn("a\"b\\c", on: true)
        try file.set(setting: "x", of: "y", to: "z")

        XCTAssertEqual(file.read().arrangement.enabled, ["a\"b\\c"])
        XCTAssertEqual(file.read().faults, [])
    }

    func testAKeyEntryThatCannotBeReadSurvivesASave() throws {
        try write("[[keys]]\nspot = \"a\"\nkey = \"hyper+k\"\nwhen = \"held\"\n")

        try file.turn("x", on: true)

        let text = try String(contentsOf: file.url, encoding: .utf8)
        XCTAssertTrue(text.contains("[[keys]]\nspot = \"a\"\nkey = \"hyper+k\"\nwhen = \"held\"\n"), text)
        XCTAssertEqual(file.read().arrangement.enabled, ["x"])
    }

    func testATableWithAnUnknownNameSurvivesASave() throws {
        try write("[[themes]]\nname = \"dark\"\ntones = [\"a\", \"b\"]\n")

        try file.turn("x", on: true)

        let text = try String(contentsOf: file.url, encoding: .utf8)
        XCTAssertTrue(text.contains("[[themes]]\nname = \"dark\"\ntones = [\"a\", \"b\"]\n"), text)
        XCTAssertEqual(file.read().faults, ["config.toml: themes is not a setting."])
    }

    func testASectionSurvivesASaveAndIsNotASetting() throws {
        try write("[look]\nink = \"#FFFFFF\"\n")

        try file.turn("x", on: true)

        let text = try String(contentsOf: file.url, encoding: .utf8)
        XCTAssertTrue(text.contains("[look]\nink = \"#FFFFFF\"\n"), text)
        XCTAssertEqual(file.read().faults, ["config.toml: look is not a setting."])
    }

    func testAKeyWithAQuoteInItsSpotAndCommandSurvivesASave() throws {
        let key = GlobalKey(spot: "a\"b", command: "c\\d\"", shortcut: try XCTUnwrap(Shortcut(text: "ctrl+left")))

        try file.write(keys: [key])

        XCTAssertEqual(file.read().keys, [key])
        XCTAssertEqual(file.read().faults, [])
    }

    func testAChangeReadsOnceAndWritesOnce() throws {
        let disk = FakeDisk(text: "panel-key = \"cmd+k\"\n\n[[spots]]\nid = \"a\"\n")
        let file = ConfigFile(url: file.url, disk: disk)

        try file.change { config in
            config.arrangement.set(isEnabled: true, of: "b")
            config.assign(.shake, to: "a", act: .float)
            config.set(setting: "folder", of: "a", to: "~/Code")
            config.set(isCareful: true)
        }

        XCTAssertEqual(disk.reads, 1)
        XCTAssertEqual(disk.writes, 1)
        let config = Config(text: disk.text ?? "")
        XCTAssertEqual(config.arrangement.enabled, ["b"])
        XCTAssertEqual(config.keys.map(\.trigger), [.shake])
        XCTAssertEqual(config.setting("folder", of: "a"), "~/Code")
        XCTAssertTrue(config.isCareful)
        XCTAssertEqual(config.panelKey, Shortcut(text: "cmd+k"))
    }

    func testAChangeThatChangesNothingWritesNothing() throws {
        let disk = FakeDisk(text: "careful = true\n")
        let file = ConfigFile(url: file.url, disk: disk)

        try file.change { $0.set(isCareful: true) }

        XCTAssertEqual(disk.writes, 0)
    }

    func testAChangeFromAKeptConfigReadsNoFileUntilAnotherWriteChangesIt() throws {
        let disk = FakeDisk(text: "[[spots]]\nid = \"a\"\n")
        let file = ConfigFile(url: file.url, disk: disk)
        let kept = file.readKept()
        let reads = disk.reads

        let next = try file.change(from: kept) { $0.arrangement.set(isEnabled: true, of: "a") }

        XCTAssertEqual(disk.reads, reads)
        XCTAssertEqual(next.config, Config(text: disk.text ?? ""))

        disk.put((disk.text ?? "") + "\n[[settings]]\nspot = \"a\"\nkey = \"k\"\nvalue = \"v\"\n")
        let last = try file.change(from: next) { $0.arrangement.set(isEnabled: true, of: "b") }

        XCTAssertEqual(disk.reads, reads + 1)
        XCTAssertEqual(last.config.setting("k", of: "a"), "v")
        XCTAssertEqual(last.config.arrangement.enabled, ["a", "b"])
    }

    func testAFileThatCannotBeReadIsNotWrittenFromAKeptConfig() throws {
        let disk = FakeDisk(text: "panel-key\n")
        let file = ConfigFile(url: file.url, disk: disk)

        XCTAssertThrowsError(try file.change(from: file.readKept()) { $0.set(isCareful: true) })
        XCTAssertEqual(disk.text, "panel-key\n")
    }

    func testTheSectionsThatDifferNameEachFieldAndTheRest() {
        let config = Config(text: "")

        XCTAssertEqual(Config(text: "panel-key = \"cmd+k\"\n").sections(differingFrom: config), [.keys])
        XCTAssertEqual(Config(text: "[[keys]]\nspot = \"a\"\nkey = \"shake\"\n").sections(differingFrom: config), [.keys])
        XCTAssertEqual(Config(text: "[[spots]]\nid = \"a\"\n").sections(differingFrom: config), [.spots])
        XCTAssertEqual(Config(text: "[[settings]]\nspot = \"a\"\nkey = \"k\"\nvalue = \"v\"\n").sections(differingFrom: config), [.settings])
        XCTAssertEqual(Config(text: "careful = true\n").sections(differingFrom: config), [.careful])
        XCTAssertEqual(Config(text: "columns = 6\n").sections(differingFrom: config), [.columns])
        XCTAssertEqual(Config(text: "look = \"dark\"\n").sections(differingFrom: config), [.rest])
        XCTAssertEqual(Config(text: "theme = \"Dusk\"\n").sections(differingFrom: config), [])
        XCTAssertEqual(Config(text: "[[keys]]\nspot = \"a\"\n").sections(differingFrom: config), [.rest])
        XCTAssertEqual(Config(text: "[[themes]]\nname = \"dark\"\n").sections(differingFrom: Config(text: "[[themes]]\nname = \"light\"\n")), [.rest])
        XCTAssertEqual(config.sections(differingFrom: config), [])
    }

    func testTheStampOfTheFileHoldsUntilAWriteAndAKeptConfigSeesTheWriteOfAnother() throws {
        try file.turn("a", on: true)
        let kept = file.readKept()

        XCTAssertEqual(LocalDisk().readStamp(of: file.url), LocalDisk().readStamp(of: file.url))
        XCTAssertEqual(try file.change(from: kept) { _ in }, kept)

        try file.set(setting: "k", of: "a", to: "v")
        let next = try file.change(from: kept) { $0.arrangement.set(isEnabled: true, of: "b") }

        XCTAssertNotEqual(next, kept)
        XCTAssertEqual(file.read().setting("k", of: "a"), "v")
        XCTAssertEqual(file.read().arrangement.enabled, ["a", "b"])
        XCTAssertEqual(next.config, file.read())
    }

    func testAValueWithACombiningMarkAfterAQuoteABackslashOrANewLineSurvivesASave() throws {
        let values = ["\u{301}x", "a\\\u{301}", "a\n\u{301}b", "\"\u{FE0F}", "\u{200D}\u{1F467}", "a\t\u{308}"]

        for (index, value) in values.enumerated() {
            try file.set(setting: "k\(index)", of: value, to: value)
            try file.turn(value, on: true)
        }

        let config = file.read()
        XCTAssertEqual(config.faults, [])
        XCTAssertEqual(config.settings.map(\.value).map { Array($0.unicodeScalars) }, values.map { Array($0.unicodeScalars) })
        XCTAssertEqual(config.settings.map(\.spot).map { Array($0.unicodeScalars) }, values.map { Array($0.unicodeScalars) })
        XCTAssertEqual(config.arrangement.enabled.count, values.count)
    }

    func testAFileThatIsNotTextIsAFaultAndIsNotWritten() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let bytes = Data([0xFF, 0xFE, 0x00, 0x41])
        try bytes.write(to: file.url)

        XCTAssertFalse(file.read().isReadable)
        XCTAssertEqual(file.read().faults.count, 1)
        XCTAssertNil(file.read().panelKey)
        XCTAssertThrowsError(try file.turn("a", on: true))
        XCTAssertThrowsError(try file.change(from: file.readKept()) { $0.set(isCareful: true) })
        XCTAssertThrowsError(try file.begin(enabling: ["a"]))
        XCTAssertEqual(try Data(contentsOf: file.url), bytes)
    }
}
