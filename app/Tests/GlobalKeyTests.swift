import XCTest
@testable import OpenspotCore

final class GlobalKeyTests: XCTestCase {
    private func command(toml: String) throws -> Spot {
        let manifest = try Manifest(text: toml, folder: "/spots").script("move.sh")
        let spot = try SpotFile(script: URL(fileURLWithPath: "/spots/move.sh"), manifest: manifest, id: "move")
        return try XCTUnwrap(spot.spots.first)
    }

    func testAHeaderListsEachCommandAsABlockAfterABlankCommentLine() throws {
        let spot = try command(toml: "title = 'Move'\n[commands.full]\ntitle = 'Full screen'\n[commands.meet]\ntitle = 'Join: 09:30'\nicon = 'https://example.com/meet.png'")

        XCTAssertEqual(spot.name, "Move")
        XCTAssertEqual(spot.offers.map(\.id), ["full", "meet"])
        XCTAssertEqual(spot.offers.map(\.title), ["Full screen", "Join: 09:30"])
        XCTAssertEqual(spot.offers.map(\.icon), [nil, "https://example.com/meet.png"])
    }

    func testABadCommandRefusesTheSpotAndNamesTheFault() {
        for block in ["[commands.full]", "[commands.show]\ntitle = 'Show'", "[commands.'full now']\ntitle = 'Full'"] {
            XCTAssertThrowsError(try command(toml: block), block) { error in
                XCTAssertTrue((error as? SpotError)?.reason.contains("cannot read [commands.") == true, block)
            }
        }
    }

    func testASettingIsABlockWithATitleOrItsKey() throws {
        let spot = try command(toml: "title = 'Repos'\n[settings.folder]\n[settings.editor]\ntitle = 'Default app'\nicon = 'app.badge'")

        XCTAssertEqual(spot.settings.map(\.id), ["folder", "editor"])
        XCTAssertEqual(spot.settings.map(\.title), ["Folder", "Default app"])
        XCTAssertEqual(spot.settings.map(\.icon), [nil, "app.badge"])
    }

    func testOnlyACommandThatAScriptListsTakesItsKey() throws {
        let folder = try temporaryFolder()
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("move"), toml: "[commands.full]\ntitle = 'Full screen'")
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

    func testAnOpenKeyIsAKeyThatTheFileKeepsAndThatStaysForASpotThatLoads() throws {
        let folder = try temporaryFolder()
        let file = ConfigFile(url: folder.appendingPathComponent("config.toml"))
        let config = Config(text: "[[keys]]\nspot = \"notes\"\nopen = true\nkey = \"ctrl+option+n\"\n\n[[keys]]\nspot = \"mail\"\nopen = \"yes\"\nkey = \"ctrl+option+m\"\n")
        let notes = GlobalKey(spot: "notes", act: .open, trigger: .key(try XCTUnwrap(Shortcut(text: "ctrl+option+n"))))
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("notes"))
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("hidden"), toml: "offers = ['card']")

        XCTAssertEqual(config.keys, [notes])
        XCTAssertEqual(config.faults, ["config.toml: the key of mail takes open = true, or no open line."])
        try file.write(keys: config.keys)
        XCTAssertEqual(file.read().keys, [notes])
        XCTAssertTrue(try String(contentsOf: file.url, encoding: .utf8).contains("open = true"))
        let others = [GlobalKey(spot: "gone", act: .open, trigger: notes.trigger), GlobalKey(spot: "hidden", act: .open, trigger: notes.trigger)]
        XCTAssertEqual(try SpotsFolder(url: folder).scan().offered([notes] + others), [notes])
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

    func testAFloatKeyStaysForEachSpotThatLoads() throws {
        let folder = try temporaryFolder()
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("shelf"), toml: "on = ['sheet.open']")
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("notes"))
        try "#!/bin/sh\necho text=cups\n".writeScript(to: folder.spotFile("cups"), toml: "on = ['clock.60']")
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("sheet"), toml: "on = ['sheet.open']")
        let shortcut = try XCTUnwrap(Shortcut(text: "ctrl+up"))
        let shelf = GlobalKey(spot: "shelf", act: .float, trigger: .key(shortcut))
        let cups = GlobalKey(spot: "cups", act: .float, trigger: .key(shortcut))
        let notes = GlobalKey(spot: "notes", act: .float, trigger: .key(shortcut))
        let sheet = GlobalKey(spot: "sheet", act: .float, trigger: .key(shortcut))
        let gone = GlobalKey(spot: "gone", act: .float, trigger: .key(shortcut))

        XCTAssertEqual(try SpotsFolder(url: folder).scan().offered([shelf, cups, notes, sheet, gone]), [shelf, cups, notes, sheet])
    }

    func testSavingTheGridKeepsTheKeys() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-keys-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = ConfigFile(url: folder.appendingPathComponent("config.toml"))
        let key = GlobalKey(spot: "windows", command: "left", shortcut: try XCTUnwrap(Shortcut(text: "ctrl+option+left")))
        try file.set("panel-key", to: "option+space")
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
        let folder = try temporaryFolder()
        let file = ConfigFile(url: folder.appendingPathComponent("config.toml"))
        let text = "[[spots]]\nid = \n"
        try text.write(to: file.url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try file.write(keys: []))
        XCTAssertEqual(try String(contentsOf: file.url, encoding: .utf8), text)
    }
}
