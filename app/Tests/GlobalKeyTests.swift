import XCTest
@testable import OpenspotCore

final class GlobalKeyTests: XCTestCase {
    private func command(header: String) throws -> Spot {
        let block = PluginHeader(text: "#!/bin/sh\n\(header)\n").block
        let plugin = try Plugin(script: URL(fileURLWithPath: "/plugins/move.sh"), header: block, id: "move")
        return try XCTUnwrap(plugin.commands.first)
    }

    func testAHeaderListsOneCommandOnEachLine() throws {
        let offers = try command(header: "# command=full:Full screen\n# command=left:Left side").offers

        XCTAssertEqual(offers.map(\.id), ["full", "left"])
        XCTAssertEqual(offers.map(\.title), ["Full screen", "Left side"])
    }

    func testABadLineRefusesThePluginAndNamesTheFault() {
        for line in ["# command=full", "# command=read:Read", "# command=full now:Full", "# command=full:"] {
            XCTAssertThrowsError(try command(header: line), line) { error in
                XCTAssertTrue((error as? PluginError)?.reason.contains("unknown command") == true, line)
            }
        }
    }

    func testOnlyACommandThatAScriptListsTakesItsKey() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-keys-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try "#!/bin/sh\n# command=full:Full screen\n".writeScript(to: folder.appendingPathComponent("move.sh"))
        let shortcut = try XCTUnwrap(Shortcut(text: "ctrl+up"))
        let listed = GlobalKey(spot: "move", command: "full", shortcut: shortcut)
        let unlisted = GlobalKey(spot: "move", command: "rm", shortcut: shortcut)
        let gone = GlobalKey(spot: "gone", command: "full", shortcut: shortcut)

        XCTAssertEqual(try PluginFolder(url: folder).scan().offered([listed, unlisted, gone]), [listed])
    }

    func testTheFileHoldsKeysAndNamesABadOne() {
        let config = Config(text: """
        [[keys]]
        spot = "windows"
        command = "left"
        key = "ctrl+option+left"

        [[keys]]
        spot = "windows"
        command = "right"
        key = "k"

        [[keys]]
        spot = "windows"
        """)

        XCTAssertEqual(config.keys.map(\.command), ["left"])
        XCTAssertEqual(config.keys.first?.shortcut.text, "ctrl+option+left")
        XCTAssertEqual(config.faults, ["config.toml: windows right cannot use k.", "config.toml: a key needs a spot and a key."])
    }

    func testAKeyWithNoCommandFloatsItsSpotAndKeepsNoCommandLine() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-keys-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = ConfigFile(url: folder.appendingPathComponent("config.toml"))
        let config = Config(text: "[[keys]]\nspot = \"shelf\"\nkey = \"ctrl+option+s\"\n\n[[keys]]\ncommand = \"left\"\nkey = \"ctrl+option+left\"\n")

        XCTAssertEqual(config.keys, [GlobalKey(spot: "shelf", command: nil, shortcut: try XCTUnwrap(Shortcut(text: "ctrl+option+s")))])
        XCTAssertEqual(config.faults, ["config.toml: a key needs a spot and a key."])

        try file.write(keys: config.keys)

        XCTAssertEqual(file.read().keys, config.keys)
        XCTAssertFalse(try String(contentsOf: file.url, encoding: .utf8).contains("command"))
    }

    func testAKeyWithNoCommandStaysOnlyForASpotWithACard() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-keys-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try "#!/bin/sh\n# shortcut=s\n".writeScript(to: folder.appendingPathComponent("shelf.sh"))
        try "#!/bin/sh\n# read=60\necho text=cups\n".writeScript(to: folder.appendingPathComponent("cups.sh"))
        let shortcut = try XCTUnwrap(Shortcut(text: "ctrl+up"))
        let shelf = GlobalKey(spot: "shelf", command: nil, shortcut: shortcut)
        let cups = GlobalKey(spot: "cups", command: nil, shortcut: shortcut)
        let gone = GlobalKey(spot: "gone", command: nil, shortcut: shortcut)

        XCTAssertEqual(try PluginFolder(url: folder).scan().offered([shelf, cups, gone]), [shelf])
    }

    func testSavingTheGridKeepsTheKeys() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-keys-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = ConfigFile(url: folder.appendingPathComponent("config.toml"))
        let key = GlobalKey(spot: "windows", command: "left", shortcut: try XCTUnwrap(Shortcut(text: "ctrl+option+left")))
        try file.set("panel_key", to: "option+space")
        try file.write(keys: [key])
        var arrangement = SpotArrangement()
        arrangement.set(isOnGrid: false, of: "apps")

        try file.write(arrangement)

        XCTAssertEqual(file.read().keys, [key])
        XCTAssertEqual(file.read().panelKey, Shortcut(text: "option+space"))
        XCTAssertEqual(file.read().arrangement.isOnGrid(of: "apps"), false)
        XCTAssertEqual(file.read().faults, [])
    }

    func testAFileItCannotReadKeepsItsTablesOnAWrite() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-keys-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = ConfigFile(url: folder.appendingPathComponent("config.toml"))
        let text = "[[spots]]\nid = \n"
        try text.write(to: file.url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try file.write(keys: []))
        XCTAssertEqual(try String(contentsOf: file.url, encoding: .utf8), text)
    }
}
