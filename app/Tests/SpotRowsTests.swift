import XCTest
@testable import OpenspotCore

@MainActor
final class SpotRowsTests: XCTestCase {
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
        scan.addSettings(in: file)
        return scan
    }

    private func spot(_ id: String) throws -> Spot {
        try XCTUnwrap(try scan().spots.first { $0.id == id })
    }

    private func rows(of id: String) throws -> [SettingRow] {
        try XCTUnwrap(try spot(id).rows).rows(in: file.read(), secrets: [:])
    }

    func testAScriptWithCommandsAndNoReadOpensToItsSettingsWhichHoldItsKeys() async throws {
        try "#!/bin/sh\n[ \"$1\" = left ] && printf 'toast=Left\\n'\n".writeScript(to: folder.spotFile("move"), toml: "title = 'Move'\n\n[actions.left]\ntitle = 'Left side'")
        let move = try spot("move")

        XCTAssertEqual(move.kind, .list)
        XCTAssertTrue(move.opensToKeys)
        XCTAssertEqual(move.soleCommand, "left")
        XCTAssertEqual(try rows(of: "move").map(\.key), ["open", "key.left", "float", "menubar", "window"])
        let press = try await SpotRuns().answer(of: move, "left", limit: 60)
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

    func testAValueWithANewLineStaysInItsRow() throws {
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("move"), toml: "title = 'Move'\n\n[settings]\nplace = { type = 'text', title = 'Place' }")
        try file.set(setting: "place", of: "move", to: "far\n\ntext=other\ntitle=Other")

        let rows = try rows(of: "move")

        XCTAssertEqual(rows.map(\.key), ["open", "float", "place", "menubar", "window"])
        XCTAssertEqual(rows.first { $0.key == "place" }?.value, "far\n\ntext=other\ntitle=Other")
    }

    func testAListSpotHasARowForEachKeyFieldKeptValueAndPlace() throws {
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

        let rows = try rows(of: "shelf")

        XCTAssertEqual(rows.map(\.key), ["open", "key.left", "key.right", "float", "folder", "editor", "theme", "menubar", "window"])
        XCTAssertEqual(rows.map(\.title), ["Open", "Left side", "Right side", "Float", "Folder", "Default app", "Theme", "Show in the menu bar", "Open in a window"])
        XCTAssertEqual(rows.map(\.value), [nil, nil, nil, nil, "~/Code", nil, "dark", "false", "false"])
        XCTAssertEqual(rows.map(\.icon), ["tray.full", "tray.full", "tray.full", "tray.full", "slider.horizontal.3", "slider.horizontal.3", "slider.horizontal.3", "menubar.rectangle", "macwindow"])
    }
}
