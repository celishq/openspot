import XCTest
@testable import OpenspotCore

/// Proves the Settings spot of the app: it lists the keys of the app, the switches of the Mac, a row for each menu bar
/// place, float and command of a spot, and each value that a spot keeps, and it changes each one through the API.
final class SettingsSpotTests: BuiltInCase {
    private var settings: Spot {
        get throws {
            try spot("settings")
        }
    }

    private func items() async throws -> [SpotItem] {
        try await settings.items(timeout: 5).items
    }

    @discardableResult
    private func call(_ arguments: [String]) async throws -> String? {
        try await settings.perform(SpotAction(arguments: arguments), timeout: 5)
    }

    func testItIsASmallListThatTheSearchFindsAndTheSettingsKeyOpens() throws {
        let spot = try settings
        let defaults = Config(text: try String(contentsOf: repoPlugins.deletingLastPathComponent().appendingPathComponent("app/defaults.toml"), encoding: .utf8))

        XCTAssertEqual(spot.name, "Settings")
        XCTAssertEqual(spot.subtitle, "Choose your key")
        XCTAssertEqual(defaults.arrangement.size(of: spot.id), .small)
        XCTAssertEqual(spot.kind, .list)
        XCTAssertTrue(spot.isGlobal)
        XCTAssertTrue(spot.isFound)
        XCTAssertTrue(spot.read?.has(.panel) == true)
        XCTAssertTrue(spot.read?.has(.sheet) == true)
        XCTAssertEqual(SpotArrangement().spot(openedBy: ActionKey(name: ",", isCommand: true), over: defaults.arrangement), spot.id)
    }

    func testTheSheetListsAMenuBarRowForEachSpotThatCanShowThereAndEnterTurnsItOnAndOff() async throws {
        try script("cups.sh", "title=Cups\non=clock.60")
        try script("relay.sh", "title=Relay\nmode=stay")
        try script("notes.sh", "title=Notes\non=panel.open")

        let before = try await items()
        XCTAssertEqual(before.filter { $0.run.hasPrefix("menubar:") }.map(\.run), ["menubar:cups", "menubar:relay"])
        XCTAssertEqual(before.first { $0.run == "menubar:cups" }?.isOn, false)

        try await call(["open", "menubar:cups"])

        XCTAssertEqual(file.read().arrangement.menuBar, ["cups"])
        let after = try await items()
        XCTAssertEqual(after.first { $0.run == "menubar:cups" }?.isOn, true)

        try await call(["open", "menubar:cups"])

        XCTAssertEqual(file.read().arrangement.menuBar, [])
        let changes = await app.changes
        XCTAssertEqual(changes, 2)
    }

    func testAReadStartsOneOpenspotAndNoJq() async throws {
        try script("cups.sh", "title=Cups\non=clock.60\n\nfield=size")
        let programs = try countPrograms()

        _ = try await items()

        XCTAssertEqual(programs(), ["openspot batch"])
    }

    func testTheSheetListsTheKeyOfTheFile() async throws {
        try file.set("panel_key", to: "option+space")

        let items = try await items()

        XCTAssertEqual(items.map(\.run), ["panel_key", "fix_key", "careful_mode"])
        XCTAssertEqual(items.first?.title, "Open Openspot")
        XCTAssertEqual(items.first?.shortcut, "option+space")
        XCTAssertEqual(items.map { $0.hides ?? [] }, [["clear"], ["clear"], []])
        XCTAssertEqual(items.map(\.takesShake), [false, false, false])
    }

    func testTheSheetListsTheFixKeyAndChangesIt() async throws {
        let before = try await items()
        XCTAssertEqual(before[1].title, "Open a fix")
        XCTAssertEqual(before[1].shortcut, "cmd+option+o")

        try await call(["fix_key", "ctrl+option+f"])

        XCTAssertEqual(file.read().fixKey, Shortcut(text: "ctrl+option+f"))
    }

    func testTheSheetListsEachCommandOfAScriptAndGivesItAKey() async throws {
        try script("move.sh", "title=Move\nicon=macwindow\n\nbutton=left\ntitle=Left side\n\nbutton=right\ntitle=Right side")

        let before = try await items()
        XCTAssertEqual(before.map(\.title), ["Open Openspot", "Open a fix", "Careful mode", "Left side", "Right side"])
        XCTAssertEqual(before.map(\.subtitle), [nil, nil, "Spots get only what their uses name", "Move", "Move"])
        XCTAssertEqual(before.dropFirst(3).map(\.shortcut), ["Record", "Record"])
        XCTAssertEqual(before.dropFirst(3).map(\.takesShake), [true, true])

        try await call(["key:move:left", "ctrl+option+left"])
        try await call(["key:move:left", "ctrl+option+up"])
        try await call(["key:move:right", "ctrl+option+right"])

        XCTAssertEqual(file.read().keys.map(\.act), [.command("left"), .command("right")])
        XCTAssertEqual(file.read().keys.map(\.trigger.text), ["ctrl+option+up", "ctrl+option+right"])
        let after = try await items()
        XCTAssertEqual(after.map(\.shortcut).dropFirst(3), ["ctrl+option+up", "ctrl+option+right"])
        XCTAssertEqual(after.dropFirst(3).map(\.hides), [nil, nil])

        try await call(["clear", "key:move:left"])

        XCTAssertEqual(file.read().keys.map(\.act), [.command("right")])
    }

    func testTheSheetListsAFloatRowForEachSpotWithASheetAndGivesItAKey() async throws {
        try script("shelf.sh", "title=Shelf\nicon=tray.full\non=sheet.open")
        try script("notes.sh", "title=Notes")
        try script("move.sh", "title=Move\n\nbutton=left\ntitle=Left side")

        let before = try await items()
        let floats = before.filter { $0.title == "Float" }
        XCTAssertEqual(floats.map(\.run), ["float:shelf"])
        XCTAssertEqual(before.last?.run, "key:move:left")
        let shelf = try XCTUnwrap(floats.first)
        XCTAssertEqual(shelf.subtitle, "Shelf")
        XCTAssertEqual(shelf.symbol, "tray.full")
        XCTAssertEqual(shelf.shortcut, "Record")
        XCTAssertTrue(shelf.takesShake)

        try await call(["float:shelf", "ctrl+option+s"])

        XCTAssertEqual(file.read().keys, [GlobalKey(spot: "shelf", act: .float, trigger: .key(try XCTUnwrap(Shortcut(text: "ctrl+option+s"))))])
        let after = try await items()
        XCTAssertEqual(after.first { $0.run == "float:shelf" }?.shortcut, "ctrl+option+s")

        try await call(["clear", "float:shelf"])

        XCTAssertEqual(file.read().keys, [])
    }

    func testAShakeOnARowTakesTheShakeFromTheRowThatHadIt() async throws {
        try script("shelf.sh", "title=Shelf\non=sheet.open")
        try script("notes.sh", "title=Notes\non=sheet.open")

        try await call(["float:shelf", "shake"])
        XCTAssertEqual(file.read().keys, [GlobalKey(spot: "shelf", act: .float, trigger: .shake)])

        try await call(["float:notes", "shake"])
        XCTAssertEqual(file.read().keys, [GlobalKey(spot: "notes", act: .float, trigger: .shake)])
        let items = try await items()
        XCTAssertEqual(items.first { $0.run == "float:notes" }?.shortcut, "shake")

        do {
            try await call(["panel_key", "shake"])
            XCTFail("took a shake to open the panel")
        } catch {
            XCTAssertEqual(file.read().panelKey, .standard)
        }
    }

    func testTheSheetListsEachSettingThatAScriptNamesOrKeepsAndRemovesIt() async throws {
        try script("repos.sh", "title=Repos\nicon=folder\n\nfield=folder\n\nfield=editor\ntitle=Default app\nicon=app.badge")
        try file.set(setting: "folder", of: "repos", to: "~/Code")
        try file.set(setting: "editor", of: "gone", to: "Zed")

        let items = try await items().dropFirst(3)

        XCTAssertEqual(items.map(\.title), ["Folder", "Default app", "Editor"])
        XCTAssertEqual(items.map(\.subtitle), ["Repos · ~/Code", "Repos · Not set", "gone · Zed"])
        XCTAssertEqual(items.map(\.run), ["setting:repos:folder", "setting:repos:editor", "setting:gone:editor"])
        XCTAssertEqual(items.map(\.symbol), ["folder", "app.badge", "gearshape"])
        XCTAssertEqual(items.map { $0.hides ?? [] }, [[], ["clear"], []])
        XCTAssertEqual(items.map(\.parent), ["Repos", "Repos", "gone"])

        try await call(["clear", "setting:repos:folder"])

        XCTAssertNil(file.read().setting("folder", of: "repos"))
        XCTAssertEqual(file.read().setting("editor", of: "gone"), "Zed")
    }

    func testAValueThatTheScriptDoesNotNameTakesTheTitleOfItsKeyAndThePictureOfItsSpot() async throws {
        try script("repos.sh", "title=Repos\nicon=folder")
        try file.set(setting: "theme", of: "repos", to: "dark")

        let items = try await items().dropFirst(3)

        XCTAssertEqual(items.map(\.title), ["Theme"])
        XCTAssertEqual(items.map(\.subtitle), ["Repos · dark"])
        XCTAssertEqual(items.map(\.symbol), ["folder"])
    }

    func testEnterOnASettingAsksTheAppToRunTheActionOfItsName() async throws {
        let toast = try await call(["open", "setting:home/repos:folder"])

        XCTAssertNil(toast)
        let opened = await app.opened
        XCTAssertEqual(opened, ["change home/repos folder"])
    }

    func testARowShowsTheIconOfItsCommandOrElseOfItsScript() async throws {
        try script("move.sh", "title=Move\nicon=macwindow\n\nbutton=left\ntitle=Left side\nicon=rectangle.lefthalf.filled\n\nbutton=right\ntitle=Right side\n\nbutton=fun\ntitle=Fun\nicon=🎉")

        let items = try await items()

        XCTAssertEqual(items.dropFirst(3).map(\.symbol), ["rectangle.lefthalf.filled", "macwindow", nil])
        XCTAssertEqual(items.dropFirst(3).map(\.glyph), [nil, nil, "🎉"])
        XCTAssertEqual(items.dropFirst(3).map(\.title), ["Left side", "Right side", "Fun"])
        XCTAssertEqual(items.dropFirst(3).map(\.subtitle), ["Move", "Move", "Move"])
        XCTAssertEqual(items.dropFirst(3).map(\.parent), ["Move", "Move", "Move"])
    }

    func testTheSheetListsTheStandardKeyWithNoFile() async throws {
        let items = try await items()

        XCTAssertEqual(items.first?.shortcut, "ctrl+space")
    }

    func testTheSheetHasNoPartsAndKeepsItsOrder() async throws {
        let output = try await settings.items(timeout: 5)

        XCTAssertTrue(output.parts.isEmpty)
        XCTAssertFalse(output.keepsRecent)
        XCTAssertEqual(output.pick, .stay)
    }

    func testAKeyRecordedOnARowGoesToTheFileAndTheListReadsItAgain() async throws {
        let runs = SpotRuns()
        defer { runs.quit() }
        let sheet = runs.sheet(for: try settings)
        sheet.open {}
        for _ in 0..<500 where sheet.list.shown.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        let item = try XCTUnwrap(sheet.list.selectedItem)

        sheet.set(item, to: "cmd+k")

        for _ in 0..<500 where sheet.list.shown.first?.shortcut != "cmd+k" { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(file.read().panelKey, Shortcut(text: "cmd+k"))
        XCTAssertEqual(sheet.list.shown.first?.shortcut, "cmd+k")
        let changes = await app.changes
        XCTAssertEqual(changes, 1)
    }

    func testAKeyItCannotUseLeavesTheFile() async throws {
        do {
            try await call(["panel_key", "k"])
            XCTFail("took a bad key")
        } catch {
            XCTAssertFalse(FileManager.default.fileExists(atPath: file.url.path))
        }
    }

    func testAnUnknownCallFails() async throws {
        do {
            try await call(["gone"])
            XCTFail("took an unknown call")
        } catch {
            XCTAssertEqual((error as? SpotError)?.reason, "Settings cannot do that.")
        }
    }

    func testTheLoginRowShowsItsStateAndAPickTurnsItOnAndOff() async throws {
        offerLogin()

        let off = try await items()
        XCTAssertEqual(off.map(\.run), ["panel_key", "fix_key", "careful_mode", "open_at_login"])
        XCTAssertEqual(off.last?.title, "Open at login")
        XCTAssertEqual(off.last?.isOn, false)

        try await call(["open", "open_at_login"])
        XCTAssertTrue(opensAtLogin)
        let on = try await items()
        XCTAssertEqual(on.last?.isOn, true)

        try await call(["open", "open_at_login"])
        XCTAssertFalse(opensAtLogin)
    }

    func testTheCarefulRowShowsItsStateAndAPickTurnsItOnAndOff() async throws {
        let off = try await items()
        let row = try XCTUnwrap(off.first { $0.run == "careful_mode" })
        XCTAssertEqual(row.title, "Careful mode")
        XCTAssertEqual(row.isOn, false)

        try await call(["open", "careful_mode"])
        XCTAssertTrue(file.read().isCareful)
        let on = try await items()
        XCTAssertEqual(on.first { $0.run == "careful_mode" }?.isOn, true)

        try await call(["open", "careful_mode"])
        XCTAssertFalse(file.read().isCareful)
        let changes = await app.changes
        XCTAssertEqual(changes, 2)
    }

    func testTheLinkRowIsOffUntilALinkPointsAtTheAppAndAPickLinksAndRemovesIt() async throws {
        offerLink()

        let off = try await items()
        XCTAssertEqual(off.map(\.run), ["panel_key", "fix_key", "careful_mode", "command_link"])
        XCTAssertEqual(off.last?.title, "Use openspot in Terminal")
        XCTAssertEqual(off.last?.isOn, false)

        let installed = try await call(["open", "command_link"])
        XCTAssertEqual(installed, "Installed openspot")
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: linkFile.path), root.appendingPathComponent("Openspot.app/Contents/Helpers/openspot").path)
        let on = try await items()
        XCTAssertEqual(on.last?.isOn, true)

        let removed = try await call(["open", "command_link"])
        XCTAssertEqual(removed, "Removed openspot")
        XCTAssertFalse(FileManager.default.fileExists(atPath: linkFile.path))
        XCTAssertEqual(mac.elevated, [])
    }

    func testARowShowsItsKeyAndRecordsANewOneOnlyWithTypeHotkey() {
        let items = SpotOutput(text: "row=open\ntitle=Open\ntype=hotkey\nshortcut=ctrl+k\nshake=true\n\nrow=shown\ntitle=Shown\nshortcut=cmd+k\n\nrow=other\ntitle=Other\n").items

        XCTAssertEqual(items.map(\.shortcut), ["ctrl+k", "cmd+k", nil])
        XCTAssertEqual(items.map(\.records), [true, false, false])
        XCTAssertEqual(items.map(\.takesShake), [true, false, false])
    }

    func testAPartRecordsAKeyAndReportsItsValue() throws {
        var part = try XCTUnwrap(SpotPart(block: TextBlock(fields: [
            .init(key: "hotkey", value: "open"), .init(key: "title", value: "Open"), .init(key: "value", value: "ctrl+k")
        ])))

        XCTAssertEqual(part.value, "ctrl+k")
        part.set("cmd+j")
        XCTAssertEqual(part.control, .shortcut("cmd+j"))
    }

    func testTheCheckFindsABadHotkey() {
        XCTAssertEqual(SpotOutput(text: "field=a\ntype=hotkey\nvalue=k\n").partFaults, ["the part a needs a shortcut that holds cmd, ctrl or option: k"])
        XCTAssertEqual(SpotOutput(text: "field=a\ntype=hotkey\nvalue=ctrl+k\n").partFaults, [])
    }
}
