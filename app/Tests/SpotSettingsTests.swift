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

    func testAScriptWithCommandsAndNoReadOpensToTheKeysOfItsOwnCommands() async throws {
        try "#!/bin/sh\n# title=Move\n#\n# button=left\n# title=Left side\n[ \"$1\" = left ] && printf 'toast=Left\\n'\n".writeScript(to: folder.spotFile("move"))
        try "#!/bin/sh\n# title=Other\n#\n# button=up\n# title=Up\n".writeScript(to: folder.spotFile("other"))
        let move = try spot("move")
        let settings = try XCTUnwrap(move.settingsSpot)
        let runs = SpotRuns()

        XCTAssertEqual(move.kind, .list)
        XCTAssertTrue(move.opensToSettings)
        XCTAssertEqual(move.soleCommand, "left")
        let items = try await rows(of: settings, in: runs)
        XCTAssertEqual(items.map(\.run), ["key:move:left", "menubar:move"])
        XCTAssertEqual(items.map(\.title), ["Left side shortcut", "Show in the menu bar"])
        XCTAssertEqual(items.map(\.subtitle), ["Press ⏎ to set", nil])
        XCTAssertEqual(items.map(\.shortcut), ["Record", nil])
        _ = try await runs.answer(of: settings, .set("key:move:left", to: "ctrl+option+left"), limit: 1)
        XCTAssertEqual(file.read().keys.map(\.act), [.command("left")])
        let press = try await runs.answer(of: move, .press("left"), limit: 5)
        XCTAssertEqual(press, "toast=Left\n")
        _ = try await runs.answer(of: settings, SpotAction(arguments: ["clear", "key:move:left"]), limit: 1)
        XCTAssertEqual(file.read().keys, [])
    }

    func testAValueWithANewLineStaysInItsRow() async throws {
        try "#!/bin/sh\n# title=Move\n#\n# field=place\n# title=Place\n".writeScript(to: folder.spotFile("move"))
        try file.set(setting: "place", of: "move", to: "far\n\nrow=other\ntitle=Other")
        let settings = try XCTUnwrap(try spot("move").settingsSpot)

        let items = try await rows(of: settings, in: SpotRuns())

        XCTAssertEqual(items.map(\.run), ["setting:move:place", "menubar:move"])
        XCTAssertEqual(items.first?.subtitle, "far\n\nrow=other\ntitle=Other")
    }

    func testItTakesNoKeyOfAnotherSpotAndNoKeyItCannotUse() async throws {
        try "#!/bin/sh\n# title=Move\n#\n# button=left\n# title=Left side\n".writeScript(to: folder.spotFile("move"))
        let move = try XCTUnwrap(try spot("move").settingsSpot)
        let runs = SpotRuns()

        do {
            _ = try await runs.answer(of: move, .set("key:move:left", to: "k"), limit: 1)
            XCTFail("took a bad key")
        } catch {}
        _ = try? await runs.answer(of: move, .set("key:other:up", to: "ctrl+k"), limit: 5)

        XCTAssertEqual(file.read().keys, [])
    }

    func testASpotWithOneCommandAndAReadKeepsItsOwnSheetAndItsSettingsApart() async throws {
        try "#!/bin/sh\n# title=Move\n# on=sheet.open\n# offers=card\n# offers=float\n#\n# button=left\n# title=Left side\n[ \"$1\" = read ] && printf 'row=own\\ntitle=Own\\n'\nexit 0\n".writeScript(to: folder.spotFile("move"))
        let move = try spot("move")
        let runs = SpotRuns()

        XCTAssertFalse(move.opensToSettings)
        XCTAssertEqual(move.soleCommand, "left")
        XCTAssertTrue(move.keepsHistory)
        let own = try await rows(of: move, in: runs)
        XCTAssertEqual(own.map(\.run), ["own"])
        let settings = try await rows(of: try XCTUnwrap(move.settingsSpot), in: runs)
        XCTAssertEqual(settings.map(\.run), ["key:move:left", "float:move", "menubar:move"])
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
        XCTAssertEqual(before.map(\.run), ["setting:shelf:folder", "setting:shelf:editor", "setting:shelf:theme", "key:shelf:left", "key:shelf:right", "float:shelf", "menubar:shelf"])
        XCTAssertEqual(before.map(\.title), ["Folder", "Default app", "Theme", "Left side", "Right side", "Float", "Show in the menu bar"])
        XCTAssertEqual(before.map(\.subtitle), ["~/Code", "Not set", "dark", nil, nil, nil, nil])
        XCTAssertEqual(before.map(\.symbol), ["slider.horizontal.3", "slider.horizontal.3", "slider.horizontal.3", "keyboard", "keyboard", "pip", "menubar.rectangle"])
        XCTAssertEqual(before.map(\.records), [false, false, false, true, true, true, false])
        XCTAssertEqual(before.map { $0.hides ?? [] }, [[], ["clear"], [], ["clear"], ["clear"], ["clear"], ["clear"]])
        let own = try await runs.answer(of: shelf, .read, limit: 5)
        XCTAssertEqual(SpotOutput(text: own).items.map(\.run), ["own"])

        _ = try await runs.answer(of: settings, .set("float:shelf", to: "ctrl+option+s"), limit: 1)
        _ = try await runs.answer(of: settings, .set("key:shelf:left", to: "shake"), limit: 1)
        _ = try await runs.answer(of: settings, SpotAction(arguments: ["open", "menubar:shelf"]), limit: 1)
        XCTAssertEqual(file.read().keys.map(\.act), [.float, .command("left")])
        XCTAssertEqual(file.read().arrangement.menuBar, ["shelf"])
        let after = try await rows(of: settings, in: runs)
        XCTAssertEqual(after.first { $0.run == "menubar:shelf" }?.isOn, true)
        XCTAssertEqual(after.first { $0.run == "float:shelf" }?.shortcut, "ctrl+option+s")

        for run in ["float:shelf", "key:shelf:left", "menubar:shelf", "setting:shelf:folder"] {
            _ = try await runs.answer(of: settings, SpotAction(arguments: ["clear", run]), limit: 1)
        }
        XCTAssertEqual(file.read().keys, [])
        XCTAssertEqual(file.read().arrangement.menuBar, [])
        XCTAssertNil(file.read().setting("folder", of: "shelf"))
        XCTAssertEqual(file.read().setting("theme", of: "other"), "light")
    }

    func testTheSheetOfSettingsRunsNoScriptAndTakesNoKeyItCannotUse() async throws {
        try "#!/bin/sh\n# title=Shelf\n# on=sheet.open\necho ran >> '\(folder.appendingPathComponent("ran").path)'\n".writeScript(to: folder.spotFile("shelf"))
        let settings = try XCTUnwrap(try spot("shelf").settingsSpot)
        let runs = SpotRuns()

        for arguments in [["gone"], ["float:shelf", "k"], ["open", "own"]] {
            do {
                _ = try await runs.answer(of: settings, SpotAction(arguments: arguments), limit: 1)
                XCTFail("took \(arguments)")
            } catch {}
        }

        XCTAssertEqual(file.read().keys, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("ran").path))
    }

    func testASpotWithNothingElseToSetHasSettingsWithItsPlaceInTheMenuBar() async throws {
        try "#!/bin/sh\n# title=Quit\n".writeScript(to: folder.spotFile("quit"))
        let quit = try spot("quit")
        let settings = try XCTUnwrap(quit.settingsSheet)
        let runs = SpotRuns()

        XCTAssertTrue(quit.canShowInMenuBar)
        XCTAssertTrue(settings.hasRows(in: file.read()))
        let rows = try await rows(of: try XCTUnwrap(quit.settingsSpot), in: runs)
        XCTAssertEqual(rows.map(\.run), ["menubar:quit"])
        XCTAssertEqual(rows.map(\.title), ["Show in the menu bar"])
        XCTAssertEqual(rows.map(\.symbol), ["menubar.rectangle"])
        XCTAssertEqual(rows.map { $0.hides ?? [] }, [["clear"]])
    }

    func testAShakeOnARowTakesTheShakeFromTheRowThatHadIt() async throws {
        try "#!/bin/sh\n# title=Shelf\n# on=sheet.open\n# offers=card\n# offers=float\n".writeScript(to: folder.spotFile("shelf"))
        try "#!/bin/sh\n# title=Notes\n# on=sheet.open\n# offers=card\n# offers=float\n".writeScript(to: folder.spotFile("notes"))
        let shelf = try XCTUnwrap(try spot("shelf").settingsSpot)
        let notes = try XCTUnwrap(try spot("notes").settingsSpot)
        let runs = SpotRuns()

        _ = try await runs.answer(of: shelf, .set("float:shelf", to: "shake"), limit: 1)
        XCTAssertEqual(file.read().keys, [GlobalKey(spot: "shelf", act: .float, trigger: .shake)])
        _ = try await runs.answer(of: notes, .set("float:notes", to: "shake"), limit: 1)

        XCTAssertEqual(file.read().keys, [GlobalKey(spot: "notes", act: .float, trigger: .shake)])
        let rows = try await rows(of: notes, in: runs)
        XCTAssertEqual(rows.first { $0.run == "float:notes" }?.shortcut, "shake")
    }
}
