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
        SpotOutput(text: try await runs.answer(of: spot, .read, limit: 1)).items
    }

    func testAScriptWithCommandsAndNoReadOpensToItsSettingsWhichHoldItsKeys() async throws {
        try "#!/bin/sh\n# title=Move\n#\n# button=left\n# title=Left side\n[ \"$1\" = left ] && printf 'toast=Left\\n'\n".writeScript(to: folder.spotFile("move"))
        try "#!/bin/sh\n# title=Other\n#\n# button=up\n# title=Up\n".writeScript(to: folder.spotFile("other"))
        let move = try spot("move")
        let settings = try XCTUnwrap(move.settingsSpot)
        let runs = SpotRuns()

        XCTAssertEqual(move.kind, .list)
        XCTAssertTrue(move.opensToKeys)
        XCTAssertEqual(move.soleCommand, "left")
        let items = try await rows(of: settings, in: runs)
        XCTAssertEqual(items.map(\.run), ["key:move:open", "key:move:key.left", "menubar:move"])
        let press = try await runs.answer(of: move, .press("left"), limit: 60)
        XCTAssertEqual(press, "toast=Left\n")
    }

    func testAShakeOnAFloatRowTakesTheShakeFromTheSpotThatHadIt() async throws {
        try "#!/bin/sh\n# title=Shelf\n# on=sheet.open\n# offers=card\n# offers=float\n".writeScript(to: folder.spotFile("shelf"))
        try "#!/bin/sh\n# title=Notes\n# on=sheet.open\n# offers=card\n# offers=float\n".writeScript(to: folder.spotFile("notes"))
        let runs = SpotRuns()

        _ = try await runs.answer(of: try XCTUnwrap(try spot("shelf").settingsSpot), .set("key:shelf:float", to: "shake"), limit: 60)
        let notes = try XCTUnwrap(try spot("notes").settingsSpot)
        _ = try await runs.answer(of: notes, .set("key:notes:float", to: "shake"), limit: 60)

        XCTAssertEqual(file.read().keys, [GlobalKey(spot: "notes", act: .float, trigger: .shake)])
        let rows = try await rows(of: notes, in: runs)
        XCTAssertEqual(rows.first { $0.run == "key:notes:float" }?.shortcut, "shake")
    }

    func testAValueWithANewLineStaysInItsRow() async throws {
        try "#!/bin/sh\n# title=Move\n#\n# field=place\n# title=Place\n".writeScript(to: folder.spotFile("move"))
        try file.set(setting: "place", of: "move", to: "far\n\nrow=other\ntitle=Other")
        let settings = try XCTUnwrap(try spot("move").settingsSpot)

        let items = try await rows(of: settings, in: SpotRuns())

        XCTAssertEqual(items.map(\.run), ["key:move:open", "setting:move:place", "menubar:move"])
        XCTAssertEqual(items.first { $0.run == "setting:move:place" }?.subtitle, "far\n\nrow=other\ntitle=Other")
    }

    func testAKeyRowTakesAKeyAndRemoveTakesItAway() async throws {
        try "#!/bin/sh\n# title=Move\n#\n# button=left\n# title=Left side\n".writeScript(to: folder.spotFile("move"))
        let move = try XCTUnwrap(try spot("move").settingsSpot)
        let runs = SpotRuns()

        do {
            _ = try await runs.answer(of: move, .set("key:move:key.left", to: "k"), limit: 1)
            XCTFail("took a bad key")
        } catch {}
        _ = try? await runs.answer(of: move, .set("key:other:key.up", to: "ctrl+k"), limit: 60)
        XCTAssertEqual(file.read().keys, [])

        _ = try await runs.answer(of: move, .set("key:move:key.left", to: "ctrl+k"), limit: 60)
        XCTAssertEqual(file.read().keys, [GlobalKey(spot: "move", act: .command("left"), trigger: .key(try XCTUnwrap(Shortcut(text: "ctrl+k"))))])
        let set = try await rows(of: move, in: runs)
        XCTAssertEqual(set.first { $0.run == "key:move:key.left" }?.shortcut, "ctrl+k")

        _ = try await runs.answer(of: move, SpotAction(arguments: ["clear", "key:move:key.left"]), limit: 60)
        XCTAssertEqual(file.read().keys, [])
    }

    func testASpotWithOneCommandAndAReadKeepsItsOwnSheetAndItsSettingsApart() async throws {
        try "#!/bin/sh\n# title=Move\n# on=sheet.open\n# offers=card\n# offers=float\n#\n# button=left\n# title=Left side\n[ \"$1\" = read ] && printf 'row=own\\ntitle=Own\\n'\nexit 0\n".writeScript(to: folder.spotFile("move"))
        let move = try spot("move")
        let runs = SpotRuns()

        XCTAssertFalse(move.opensToKeys)
        XCTAssertEqual(move.soleCommand, "left")
        XCTAssertTrue(move.keepsHistory)
        let own = try await rows(of: move, in: runs)
        XCTAssertEqual(own.map(\.run), ["own"])
        let settings = try await rows(of: try XCTUnwrap(move.settingsSpot), in: runs)
        XCTAssertEqual(settings.map(\.run), ["key:move:open", "key:move:key.left", "key:move:float", "menubar:move"])
    }

    func testAListSpotKeepsItsSettingsInASheetOfTheirOwn() async throws {
        let header = ["title=Shelf", "icon=tray.full", "on=sheet.open", "on=clock.60", "offers=card", "offers=float", "", "button=left", "title=Left side", "", "button=right", "title=Right side", "", "field=folder", "", "field=editor", "title=Default app", "icon=app.badge"]
        try "#!/bin/sh\n\(header.map { $0.isEmpty ? "#" : "# \($0)" }.joined(separator: "\n"))\nprintf 'row=own\\ntitle=Own\\n'\n".writeScript(to: folder.spotFile("shelf"))
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
            "setting:shelf:folder", "setting:shelf:editor", "setting:shelf:theme", "menubar:shelf"
        ])
        XCTAssertEqual(before.map(\.title), ["Open", "Left side", "Right side", "Float", "Folder", "Default app", "Theme", "Show in the menu bar"])
        XCTAssertEqual(before.map(\.subtitle), ["Press ⏎ to set", "Press ⏎ to set", "Press ⏎ to set", "Press ⏎ to set", "~/Code", "Not set", "dark", nil])
        XCTAssertEqual(before.map(\.symbol), ["tray.full", "tray.full", "tray.full", "tray.full", "slider.horizontal.3", "slider.horizontal.3", "slider.horizontal.3", "menubar.rectangle"])
        XCTAssertEqual(before.map(\.records), [true, true, true, true, false, false, false, false])
        XCTAssertEqual(before.map { $0.hides ?? [] }, [["clear"], ["clear"], ["clear"], ["clear"], [], ["clear"], [], ["clear"]])
        let own = try await runs.answer(of: shelf, .read, limit: 60)
        XCTAssertEqual(SpotOutput(text: own).items.map(\.run), ["own"])

        _ = try await runs.answer(of: settings, SpotAction(arguments: ["open", "menubar:shelf"]), limit: 1)
        XCTAssertEqual(file.read().arrangement.menuBar, ["shelf"])
        let after = try await rows(of: settings, in: runs)
        XCTAssertEqual(after.first { $0.run == "menubar:shelf" }?.isOn, true)

        for run in ["menubar:shelf", "setting:shelf:folder"] {
            _ = try await runs.answer(of: settings, SpotAction(arguments: ["clear", run]), limit: 1)
        }
        XCTAssertEqual(file.read().arrangement.menuBar, [])
        XCTAssertNil(file.read().setting("folder", of: "shelf"))
        XCTAssertEqual(file.read().setting("theme", of: "other"), "light")
    }

    func testTheSheetOfSettingsRunsNoScriptAndTakesNoKeyItCannotUse() async throws {
        try "#!/bin/sh\n# title=Shelf\n# on=sheet.open\necho ran >> '\(folder.appendingPathComponent("ran").path)'\n".writeScript(to: folder.spotFile("shelf"))
        let settings = try XCTUnwrap(try spot("shelf").settingsSpot)
        let runs = SpotRuns()

        for arguments in [["gone"], ["float:shelf", "k"], ["key:shelf:float", "ctrl+k"], ["open", "own"]] {
            do {
                _ = try await runs.answer(of: settings, SpotAction(arguments: arguments), limit: 1)
                XCTFail("took \(arguments)")
            } catch {}
        }

        XCTAssertEqual(file.read().keys, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("ran").path))
    }

    func testASpotWithNothingElseToSetHasSettingsWithItsOpenKeyAndItsPlaceInTheMenuBar() async throws {
        try "#!/bin/sh\n# title=Quit\n".writeScript(to: folder.spotFile("quit"))
        let quit = try spot("quit")
        let settings = try XCTUnwrap(quit.settingsSheet)
        let runs = SpotRuns()

        XCTAssertTrue(quit.canShowInMenuBar)
        XCTAssertTrue(settings.hasRows(in: file.read()))
        let rows = try await rows(of: try XCTUnwrap(quit.settingsSpot), in: runs)
        XCTAssertEqual(rows.map(\.run), ["key:quit:open", "menubar:quit"])
        XCTAssertEqual(rows.map(\.title), ["Open", "Show in the menu bar"])
        XCTAssertEqual(rows.map { $0.hides ?? [] }, [["clear"], ["clear"]])
    }
}
