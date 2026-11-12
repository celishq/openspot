import XCTest
@testable import OpenspotCore

final class GlobalKeyTests: XCTestCase {
    private func command(header: String) throws -> Spot {
        let block = SpotHeader(text: "#!/bin/sh\n\(header)\n").block
        let spot = try SpotFile(script: URL(fileURLWithPath: "/spots/move.sh"), header: block, id: "move")
        return try XCTUnwrap(spot.spots.first)
    }

    func testAHeaderListsEachCommandAsABlockAfterABlankCommentLine() throws {
        let spot = try command(header: "# title=Move\n#\n# button=full\n# title=Full screen\n#\n# button=meet\n# title=Join: 09:30\n# icon=https://example.com/meet.png")

        XCTAssertEqual(spot.name, "Move")
        XCTAssertEqual(spot.offers.map(\.id), ["full", "meet"])
        XCTAssertEqual(spot.offers.map(\.title), ["Full screen", "Join: 09:30"])
        XCTAssertEqual(spot.offers.map(\.icon), [nil, "https://example.com/meet.png"])
    }

    func testABadCommandRefusesTheSpotAndNamesTheFault() {
        for block in ["# button=full", "# button=read\n# title=Read", "# button=full now\n# title=Full"] {
            XCTAssertThrowsError(try command(header: block), block) { error in
                XCTAssertTrue((error as? SpotError)?.reason.contains("cannot read the button") == true, block)
            }
        }
    }

    func testACommandInTheOldFormIsRefusedWithTheNewForm() {
        for header in ["# command=full:Full screen", "# title=Move\n# command=full:Full screen"] {
            XCTAssertThrowsError(try command(header: header), header) { error in
                XCTAssertEqual((error as? SpotError)?.reason, "Move has command=full:Full screen, which Openspot no longer reads. Write each command as a button block after a blank comment line, such as button=left with title=Left side")
            }
        }
    }

    func testASettingIsABlockWithATitleOrItsKey() throws {
        let spot = try command(header: "# title=Repos\n#\n# field=folder\n#\n# field=editor\n# title=Default app\n# icon=app.badge")

        XCTAssertEqual(spot.settings.map(\.id), ["folder", "editor"])
        XCTAssertEqual(spot.settings.map(\.title), ["Folder", "Default app"])
        XCTAssertEqual(spot.settings.map(\.icon), [nil, "app.badge"])
        XCTAssertThrowsError(try command(header: "# title=Repos\n# settings=folder")) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "Repos has settings, which Openspot no longer reads. Write each setting as a field block after a blank comment line, such as field=folder with title=Folder")
        }
    }

    func testOnlyACommandThatAScriptListsTakesItsKey() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-keys-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try "#!/bin/sh\n# button=full\n# title=Full screen\n".writeScript(to: folder.spotFile("move"))
        let shortcut = try XCTUnwrap(Shortcut(text: "ctrl+up"))
        let listed = GlobalKey(spot: "move", command: "full", shortcut: shortcut)
        let unlisted = GlobalKey(spot: "move", command: "rm", shortcut: shortcut)
        let gone = GlobalKey(spot: "gone", command: "full", shortcut: shortcut)

        XCTAssertEqual(try SpotsFolder(url: folder).scan().offered([listed, unlisted, gone]), [listed])
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

        XCTAssertEqual(config.keys.map(\.act), [.command("left")])
        XCTAssertEqual(config.keys.first?.trigger.text, "ctrl+option+left")
        XCTAssertEqual(config.faults, ["config.toml: windows right cannot use k.", "config.toml: a key needs a spot and a key."])
    }

    func testAKeyWithNoCommandFloatsItsSpotAndKeepsNoCommandLine() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-keys-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = ConfigFile(url: folder.appendingPathComponent("config.toml"))
        let config = Config(text: "[[keys]]\nspot = \"shelf\"\nkey = \"ctrl+option+s\"\n\n[[keys]]\ncommand = \"left\"\nkey = \"ctrl+option+left\"\n")

        XCTAssertEqual(config.keys, [GlobalKey(spot: "shelf", act: .float, trigger: .key(try XCTUnwrap(Shortcut(text: "ctrl+option+s"))))])
        XCTAssertEqual(config.faults, ["config.toml: a key needs a spot and a key."])

        try file.write(keys: config.keys)

        XCTAssertEqual(file.read().keys, config.keys)
        XCTAssertFalse(try String(contentsOf: file.url, encoding: .utf8).contains("command"))
    }

    func testAShakeIsAKeyThatTheFileKeeps() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-keys-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = ConfigFile(url: folder.appendingPathComponent("config.toml"))
        let config = Config(text: "[[keys]]\nspot = \"shelf\"\nkey = \"shake\"\n")

        XCTAssertEqual(config.keys, [GlobalKey(spot: "shelf", act: .float, trigger: .shake)])
        XCTAssertEqual(config.faults, [])

        try file.write(keys: config.keys)

        XCTAssertEqual(file.read().keys, config.keys)
        XCTAssertTrue(try String(contentsOf: file.url, encoding: .utf8).contains("key = \"shake\""))
        XCTAssertEqual(Trigger.shake.label, "Shake")
        XCTAssertEqual(Trigger(text: "ctrl+space")?.label, "⌃Space")
    }

    func testAKeyWithNoCommandStaysOnlyForASpotWithASheet() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-keys-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try "#!/bin/sh\n# on=sheet.open\n".writeScript(to: folder.spotFile("shelf"))
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("notes"))
        try "#!/bin/sh\n# on=clock.60\necho text=cups\n".writeScript(to: folder.spotFile("cups"))
        let shortcut = try XCTUnwrap(Shortcut(text: "ctrl+up"))
        let shelf = GlobalKey(spot: "shelf", act: .float, trigger: .key(shortcut))
        let cups = GlobalKey(spot: "cups", act: .float, trigger: .key(shortcut))
        let notes = GlobalKey(spot: "notes", act: .float, trigger: .key(shortcut))
        let gone = GlobalKey(spot: "gone", act: .float, trigger: .key(shortcut))

        XCTAssertEqual(try SpotsFolder(url: folder).scan().offered([shelf, cups, notes, gone]), [shelf, cups])
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
