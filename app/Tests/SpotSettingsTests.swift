import XCTest
@testable import OpenspotCore

@MainActor
final class SpotSettingsTests: XCTestCase {
    private var folder: URL!

    private var file: ConfigFile {
        ConfigFile(url: folder.appendingPathComponent("config.toml"))
    }

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-keys-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func scan() throws -> ScanResult {
        var scan = try SpotsFolder(url: folder).scan()
        scan.addSettings(in: file, secrets: SecretStore(file: folder.appendingPathComponent("secrets.json")))
        return scan
    }

    private func spot(_ id: String) throws -> Spot {
        try XCTUnwrap(try scan().spots.first { $0.id == id })
    }

    private func rows(of spot: Spot, in runs: SpotRuns) async throws -> [SpotItem] {
        Frame(text: try await runs.answer(of: spot, ScriptEntry.show.name, limit: 1)).items
    }

    func testAScriptWithCommandsAndNoReadOpensToItsSettingsWhichHoldItsKeys() async throws {
        try "#!/bin/sh\n[ \"$1\" = left ] && printf 'toast=Left\\n'\n".writeScript(to: folder.spotFile("move"), toml: "title = 'Move'\n\n[actions.left]\ntitle = 'Left side'")
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("other"), toml: "title = 'Other'\n\n[actions.up]\ntitle = 'Up'")
        let move = try spot("move")
        let settings = try XCTUnwrap(move.settingsSpot)
        let runs = SpotRuns()

        XCTAssertEqual(move.kind, .list)
        XCTAssertTrue(move.opensToKeys)
        XCTAssertEqual(move.soleCommand, "left")
        let items = try await rows(of: settings, in: runs)
        XCTAssertEqual(items.map(\.run), ["key:move:open", "key:move:key.left", "key:move:float", "menubar:move", "window:move"])
        let press = try await runs.answer(of: move, "left", limit: 60)
        XCTAssertEqual(press, "toast=Left\n")
    }

    func testASpotHasASheetUnlessItHasCommandsAndNoEvents() throws {
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("notes"), toml: "title = 'Notes'")
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("move"), toml: "title = 'Move'\n\n[actions.left]\ntitle = 'Left'")
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("shelf"), toml: "title = 'Shelf'\n\n[actions.left]\ntitle = 'Left'\n[actions.right]\ntitle = 'Right'\n\n[on]\n\"sheet.open\" = true")
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("sum"), toml: "title = 'Sum'\n\n[on]\nsearch = '^[0-9]'")
        let notes = try spot("notes")
        let move = try spot("move")
        let shelf = try spot("shelf")

        XCTAssertEqual([notes.hasSheet, move.hasSheet, shelf.hasSheet], [true, false, true])
        XCTAssertEqual([notes.mainAct, move.mainAct, shelf.mainAct], [.sheet, .command("left"), .sheet])
        XCTAssertEqual([notes.opensToKeys, move.opensToKeys, shelf.opensToKeys], [false, true, false])
        XCTAssertEqual([notes.keepsHistory, move.keepsHistory, shelf.keepsHistory], [false, false, false])
        XCTAssertFalse(try XCTUnwrap(try scan().scripts.first { $0.id == "sum" }).hasSheet)
    }

    func testAShakeOnAFloatRowTakesTheShakeFromTheSpotThatHadIt() async throws {
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("shelf"), toml: "title = 'Shelf'")
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("notes"), toml: "title = 'Notes'")
        let runs = SpotRuns()

        _ = try await runs.answer(of: try XCTUnwrap(try spot("shelf").settingsSpot), "key:shelf:float", input: "input.value=shake\n", limit: 60)
        let notes = try XCTUnwrap(try spot("notes").settingsSpot)
        _ = try await runs.answer(of: notes, "key:notes:float", input: "input.value=shake\n", limit: 60)

        XCTAssertEqual(file.read().keys, [GlobalKey(spot: "notes", act: .float, trigger: .shake)])
        let rows = try await rows(of: notes, in: runs)
        XCTAssertEqual(rows.first { $0.run == "key:notes:float" }?.shortcut, "shake")
    }

    func testAValueWithANewLineStaysInItsRow() async throws {
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("move"), toml: "title = 'Move'\n\n[settings]\nplace = { type = 'text', title = 'Place' }")
        try file.set(setting: "place", of: "move", to: "far\n\ntext=other\ntitle=Other")
        let settings = try XCTUnwrap(try spot("move").settingsSpot)

        let items = try await rows(of: settings, in: SpotRuns())

        XCTAssertEqual(items.map(\.run), ["key:move:open", "key:move:float", "setting:move:place", "menubar:move", "window:move"])
        XCTAssertEqual(items.first { $0.run == "setting:move:place" }?.subtitle, "far\n\ntext=other\ntitle=Other")
    }

    func testAKeyRowTakesAKeyAndRemoveTakesItAway() async throws {
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("move"), toml: "title = 'Move'\n\n[actions.left]\ntitle = 'Left side'")
        let move = try XCTUnwrap(try spot("move").settingsSpot)
        let runs = SpotRuns()

        do {
            _ = try await runs.answer(of: move, "key:move:key.left", input: "input.value=k\n", limit: 1)
            XCTFail("took a bad key")
        } catch {}
        _ = try? await runs.answer(of: move, "key:other:key.up", input: "input.value=ctrl+k\n", limit: 60)
        XCTAssertEqual(file.read().keys, [])

        _ = try await runs.answer(of: move, "key:move:key.left", input: "input.value=ctrl+k\n", limit: 60)
        XCTAssertEqual(file.read().keys, [GlobalKey(spot: "move", act: .command("left"), trigger: .key(try XCTUnwrap(Shortcut(text: "ctrl+k"))))])
        let set = try await rows(of: move, in: runs)
        XCTAssertEqual(set.first { $0.run == "key:move:key.left" }?.shortcut, "ctrl+k")

        _ = try await runs.answer(of: move, "clear", input: "input.item=key:move:key.left\n", limit: 60)
        XCTAssertEqual(file.read().keys, [])
    }

    func testASpotWithOneCommandAndAReadKeepsItsOwnSheetAndItsSettingsApart() async throws {
        try "#!/bin/sh\n[ \"$1\" = show ] && printf 'item=own\\ntitle=Own\\n'\nexit 0\n".writeScript(to: folder.spotFile("move"), toml: "title = 'Move'\n\n[actions.left]\ntitle = 'Left side'\n\n[on]\n\"sheet.open\" = true")
        let move = try spot("move")
        let runs = SpotRuns()

        XCTAssertFalse(move.opensToKeys)
        XCTAssertEqual(move.soleCommand, "left")
        XCTAssertTrue(move.keepsHistory)
        let own = try await rows(of: move, in: runs)
        XCTAssertEqual(own.map(\.run), ["own"])
        let settings = try await rows(of: try XCTUnwrap(move.settingsSpot), in: runs)
        XCTAssertEqual(settings.map(\.run), ["key:move:open", "key:move:key.left", "key:move:float", "menubar:move", "window:move"])
    }

    func testAListSpotKeepsItsSettingsInASheetOfTheirOwn() async throws {
        let toml = """
        title = 'Shelf'
        icon = 'tray.full'

        [settings]
        folder = { type = 'text' }
        editor = { type = 'text', title = 'Default app', icon = 'app.badge' }

        [actions.left]
        title = 'Left side'

        [actions.right]
        title = 'Right side'

        [on]
        "sheet.open" = true
        every = 60
        """
        try "#!/bin/sh\nprintf 'item=own\\ntitle=Own\\n'\n".writeScript(to: folder.spotFile("shelf"), toml: toml)
        try file.set(setting: "folder", of: "shelf", to: "~/Code")
        try file.set(setting: "theme", of: "shelf", to: "dark")
        try file.set(setting: "theme", of: "other", to: "light")
        let shelf = try spot("shelf")
        let settings = try XCTUnwrap(shelf.settingsSpot)
        let runs = SpotRuns()

        XCTAssertFalse(shelf.holdsSettings)
        XCTAssertEqual(SpotSettings.owner(of: settings.id), "shelf")
        XCTAssertEqual(settings.name, "Shelf Settings")
        let before = try await rows(of: settings, in: runs)
        XCTAssertEqual(before.map(\.run), [
            "key:shelf:open", "key:shelf:key.left", "key:shelf:key.right", "key:shelf:float",
            "setting:shelf:folder", "setting:shelf:editor", "setting:shelf:theme", "menubar:shelf", "window:shelf"
        ])
        XCTAssertEqual(before.map(\.title), ["Open", "Left side", "Right side", "Float", "Folder", "Default app", "Theme", "Show in the menu bar", "Open in a window"])
        XCTAssertEqual(before.map(\.subtitle), ["Press ⏎ to set", "Press ⏎ to set", "Press ⏎ to set", "Press ⏎ to set", "~/Code", "Not set", "dark", nil, nil])
        XCTAssertEqual(before.map(\.symbol), ["tray.full", "tray.full", "tray.full", "tray.full", "slider.horizontal.3", "slider.horizontal.3", "slider.horizontal.3", "menubar.rectangle", "macwindow"])
        XCTAssertEqual(before.map(\.records), [true, true, true, true, false, false, false, false, false])
        XCTAssertEqual(before.map { $0.hides ?? [] }, [["clear"], ["clear"], ["clear"], ["clear"], [], ["clear"], [], ["clear"], ["clear"]])
        let own = try await runs.answer(of: shelf, ScriptEntry.show.name, limit: 60)
        XCTAssertEqual(Frame(text: own).items.map(\.run), ["own"])

        _ = try await runs.answer(of: settings, "press", input: "input.item=menubar:shelf\n", limit: 1)
        XCTAssertEqual(file.read().arrangement.menuBar, ["shelf"])
        let after = try await rows(of: settings, in: runs)
        XCTAssertEqual(after.first { $0.run == "menubar:shelf" }?.isOn, true)

        for run in ["menubar:shelf", "setting:shelf:folder"] {
            _ = try await runs.answer(of: settings, "clear", input: "input.item=\(run)\n", limit: 1)
        }
        XCTAssertEqual(file.read().arrangement.menuBar, [])
        XCTAssertNil(file.read().setting("folder", of: "shelf"))
        XCTAssertEqual(file.read().setting("theme", of: "other"), "light")
    }

    func testTheSheetOfSettingsRunsNoScriptAndTakesNoKeyItCannotUse() async throws {
        try "#!/bin/sh\necho ran >> '\(folder.appendingPathComponent("ran").path)'\n".writeScript(to: folder.spotFile("shelf"), toml: "title = 'Shelf'")
        let settings = try XCTUnwrap(try spot("shelf").settingsSpot)
        let runs = SpotRuns()

        for (word, input) in [("gone", ""), ("float:shelf", "input.value=k\n"), ("key:shelf:key.gone", "input.value=ctrl+k\n"), ("press", "input.item=own\n")] {
            do {
                _ = try await runs.answer(of: settings, word, input: input, limit: 1)
                XCTFail("took \(word) \(input)")
            } catch {}
        }

        XCTAssertEqual(file.read().keys, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("ran").path))
    }

    func testASpotWithNothingElseToSetHasSettingsWithItsOpenKeyAndItsPlaceInTheMenuBar() async throws {
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("quit"), toml: "title = 'Quit'")
        let quit = try spot("quit")
        let settings = try XCTUnwrap(quit.settingsSheet)
        let runs = SpotRuns()

        XCTAssertTrue(quit.canShowInMenuBar)
        XCTAssertTrue(settings.hasRows(in: file.read()))
        let rows = try await rows(of: try XCTUnwrap(quit.settingsSpot), in: runs)
        XCTAssertEqual(rows.map(\.run), ["key:quit:open", "key:quit:float", "menubar:quit", "window:quit"])
        XCTAssertEqual(rows.map(\.title), ["Open", "Float", "Show in the menu bar", "Open in a window"])
        XCTAssertEqual(rows.map { $0.hides ?? [] }, [["clear"], ["clear"], ["clear"], ["clear"]])
    }
}
