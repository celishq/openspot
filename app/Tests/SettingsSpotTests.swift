import XCTest
@testable import OpenspotCore

/// Proves the Settings spot of the app: it lists only the settings of the app, its keys and the switches of the Mac, and
/// changes each one through the API. Each spot keeps its own in its own Settings sheet.
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
        let defaults = Config(text: try String(contentsOf: repoSpots.deletingLastPathComponent().appendingPathComponent("app/defaults.toml"), encoding: .utf8))

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

    func testAReadStartsOneOpenspotAndNoJq() async throws {
        let programs = try countPrograms()

        _ = try await items()

        XCTAssertEqual(programs(), ["openspot app status --frame"])
    }

    func testTheSheetListsOnlyTheSettingsOfTheAppAndNoneOfASpot() async throws {
        try script("cups.sh", "title=Cups\non=clock.60\non=sheet.open\n\nbutton=fill\ntitle=Fill\n\nfield=size")
        try file.set(setting: "theme", of: "cups", to: "dark")
        try file.assign(.shake, to: "cups", act: .float)

        let items = try await items()

        XCTAssertEqual(items.map(\.run), ["panel_key", "fix_key", "careful_mode"])
        XCTAssertFalse(items.contains { $0.title == "Show in the menu bar" || $0.title == "Float" || $0.subtitle?.contains("Cups") == true })
    }

    func testTheSheetListsTheKeyOfTheFile() async throws {
        try file.set("panel_key", to: "option+space")

        let items = try await items()

        XCTAssertEqual(items.map(\.run), ["panel_key", "fix_key", "careful_mode"])
        XCTAssertEqual(items.first?.title, "Open Openspot")
        XCTAssertEqual(items.first?.shortcut, "option+space")
        XCTAssertEqual(items.map { $0.hides ?? [] }, [[], [], []])
        XCTAssertEqual(items.map(\.takesShake), [false, false, false])
    }

    func testTheSheetListsTheFixKeyAndChangesIt() async throws {
        let before = try await items()
        XCTAssertEqual(before[1].title, "Open a fix")
        XCTAssertEqual(before[1].shortcut, "cmd+option+o")

        try await call(["fix_key", "ctrl+option+f"])

        XCTAssertEqual(file.read().fixKey, Shortcut(text: "ctrl+option+f"))
    }

    func testTheKeyThatOpensThePanelTakesNoShake() async throws {
        do {
            try await call(["panel_key", "shake"])
            XCTFail("took a shake to open the panel")
        } catch {
            XCTAssertEqual(file.read().panelKey, .standard)
        }
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
