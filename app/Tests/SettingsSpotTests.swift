import XCTest
@testable import OpenspotCore

@MainActor
final class SettingsSpotTests: XCTestCase {
    private var folder: URL!

    private var file: ConfigFile {
        ConfigFile(url: folder.appendingPathComponent("config.toml"))
    }

    private var spot: Spot {
        get throws {
            let commands = ShippedSpot.commands(folder: folder, guide: folder, app: "", config: file)
            return try XCTUnwrap(commands.first { $0.name == "Settings" })
        }
    }

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-settings-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testTwoSpotsShipAndSettingsHasNoLetter() throws {
        let commands = ShippedSpot.commands(folder: folder, guide: folder, app: "", config: file)

        XCTAssertEqual(commands.map(\.name), ["Spots", "Settings", "Build"])
        XCTAssertEqual(commands.map(\.key?.name), ["p", nil, nil])
    }

    func testTheMainSearchFindsItsRows() throws {
        XCTAssertTrue(try spot.isGlobal)
        XCTAssertTrue(try spot.read?.has(.panel) == true)
    }

    func testTheSheetListsTheKeyOfTheFile() async throws {
        try file.set("panel_key", to: "option+space")

        let items = try await spot.items(timeout: 1).items

        XCTAssertEqual(items.map(\.run), ["panel_key", "fix_key"])
        XCTAssertEqual(items.first?.title, "Open Openspot")
        XCTAssertEqual(items.first?.shortcut, "option+space")
    }

    func testTheSheetListsTheFixKeyAndChangesIt() async throws {
        let before = try await spot.items(timeout: 1).items
        XCTAssertEqual(before.last?.title, "Open a fix")
        XCTAssertEqual(before.last?.shortcut, "cmd+option+o")

        _ = try await SpotRuns().answer(of: spot, .set("fix_key", to: "ctrl+option+f"), input: "", limit: 1)

        XCTAssertEqual(file.read().fixKey, Shortcut(text: "ctrl+option+f"))
    }

    func testTheSheetListsEachCommandOfAScriptAndGivesItAKey() async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "#!/bin/sh\n# title=Move\n# icon=macwindow\n# command=left:Left side\n# command=right:Right side\n".writeScript(to: folder.appendingPathComponent("move.sh"))
        let runs = SpotRuns()

        let before = try await spot.items(timeout: 1).items
        XCTAssertEqual(before.map(\.title), ["Open Openspot", "Open a fix", "Left side", "Right side"])
        XCTAssertEqual(before.map(\.subtitle), [nil, nil, "Move", "Move"])
        XCTAssertEqual(before.dropFirst(2).map(\.shortcut), ["Record", "Record"])

        _ = try await runs.answer(of: spot, .set("key:move:left", to: "ctrl+option+left"), input: "", limit: 1)
        _ = try await runs.answer(of: spot, .set("key:move:left", to: "ctrl+option+up"), input: "", limit: 1)
        _ = try await runs.answer(of: spot, .set("key:move:right", to: "ctrl+option+right"), input: "", limit: 1)

        XCTAssertEqual(file.read().keys.map(\.command), ["left", "right"])
        XCTAssertEqual(file.read().keys.map(\.shortcut.text), ["ctrl+option+up", "ctrl+option+right"])
        let after = try await spot.items(timeout: 1).items
        XCTAssertEqual(after.map(\.shortcut).dropFirst(2), ["ctrl+option+up", "ctrl+option+right"])

        _ = try await runs.answer(of: spot, SpotAction(arguments: ["clear", "key:move:left"]), input: "", limit: 1)

        XCTAssertEqual(file.read().keys.map(\.command), ["right"])
    }

    func testTheSheetListsEachSettingThatAScriptKeepsAndRemovesIt() async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "#!/bin/sh\n# title=Repos\n# icon=folder\n# shortcut=r\n".writeScript(to: folder.appendingPathComponent("repos.sh"))
        try file.set(setting: "folder", of: "repos", to: "~/Code")
        try file.set(setting: "editor", of: "gone", to: "Zed")

        let items = try await spot.items(timeout: 1).items.dropFirst(2)

        XCTAssertEqual(items.map(\.title), ["Folder", "Editor"])
        XCTAssertEqual(items.map(\.subtitle), ["Repos · ~/Code", "gone · Zed"])
        XCTAssertEqual(items.map(\.run), ["setting:repos:folder", "setting:gone:editor"])
        XCTAssertEqual(items.map(\.symbol), ["folder", "gearshape"])

        _ = try await SpotRuns().answer(of: spot, SpotAction(arguments: ["clear", "setting:repos:folder"]), input: "", limit: 1)

        XCTAssertNil(file.read().setting("folder", of: "repos"))
        XCTAssertEqual(file.read().setting("editor", of: "gone"), "Zed")
    }

    func testEnterOnASettingSaysWhereToChangeIt() async throws {
        try file.set(setting: "folder", of: "repos", to: "~/Code")

        let toast = try await spot.perform(.item(SpotItem(title: "Folder", run: "setting:repos:folder")), timeout: 1)

        XCTAssertEqual(toast, "repos keeps this value. Change it in repos, or press `⌘⌫` to remove it.")
    }

    func testARowShowsTheIconOfItsCommandOrElseOfItsScript() async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "#!/bin/sh\n# title=Move\n# icon=macwindow\n# command=left:Left side:rectangle.lefthalf.filled\n# command=right:Right side\n# command=fun:Fun:🎉\n".writeScript(to: folder.appendingPathComponent("move.sh"))

        let items = try await spot.items(timeout: 1).items

        XCTAssertEqual(items.dropFirst(2).map(\.symbol), ["rectangle.lefthalf.filled", "macwindow", nil])
        XCTAssertEqual(items.dropFirst(2).map(\.glyph), [nil, nil, "🎉"])
        XCTAssertEqual(items.dropFirst(2).map(\.title), ["Left side", "Right side", "Fun"])
        XCTAssertEqual(items.dropFirst(2).map(\.subtitle), ["Move", "Move", "Move"])
        XCTAssertEqual(items.dropFirst(2).map(\.parent), ["Move", "Move", "Move"])
    }

    func testAScriptWithCommandsAndNoReadOpensToTheKeysOfItsOwnCommands() async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "#!/bin/sh\n# title=Move\n# command=left:Left side\n[ \"$1\" = left ] && printf 'toast=Left\\n'\n".writeScript(to: folder.appendingPathComponent("move.sh"))
        try "#!/bin/sh\n# title=Other\n# command=up:Up\n".writeScript(to: folder.appendingPathComponent("other.sh"))
        let scan = try PluginFolder(url: folder).scan(shipped: ShippedSpot.commands(folder: folder, guide: folder, app: "", config: file))
        let move = try XCTUnwrap(scan.commands.first { $0.id == "move" })
        let runs = SpotRuns()

        XCTAssertEqual(move.kind, .list)
        let items = try await move.items(timeout: 1).items
        XCTAssertEqual(items.map(\.title), ["Left side"])
        XCTAssertEqual(items.map(\.subtitle), [nil])
        _ = try await runs.answer(of: move, .set("key:move:left", to: "ctrl+option+left"), limit: 1)
        XCTAssertEqual(file.read().keys.map(\.command), ["left"])
        let press = try await runs.answer(of: move, .press("left"), limit: 5)
        XCTAssertEqual(press, "toast=Left\n")
    }

    func testTheSheetListsTheStandardKeyWithNoFile() async throws {
        let items = try await spot.items(timeout: 1).items

        XCTAssertEqual(items.first?.shortcut, "ctrl+space")
    }

    func testTheSheetHasNoPartsAndKeepsItsOrder() async throws {
        let output = try await spot.items(timeout: 1)

        XCTAssertTrue(output.parts.isEmpty)
        XCTAssertFalse(output.keepsRecent)
    }

    func testAKeyRecordedOnARowGoesToTheFileAndTheListReadsItAgain() async throws {
        let runs = SpotRuns()
        let sheet = runs.sheet(for: try spot)
        sheet.open {}
        for _ in 0..<200 where sheet.list.shown.isEmpty { try await Task.sleep(for: .milliseconds(5)) }
        let item = try XCTUnwrap(sheet.list.selectedItem)

        sheet.set(item, to: "cmd+k")

        for _ in 0..<200 where sheet.list.shown.first?.shortcut != "cmd+k" { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertEqual(file.read().panelKey, Shortcut(text: "cmd+k"))
        XCTAssertEqual(sheet.list.shown.first?.shortcut, "cmd+k")
    }

    func testARowCarriesItsKey() {
        let items = PluginOutput(text: "row=open\ntitle=Open\nshortcut=ctrl+k\n\nrow=other\ntitle=Other\n").items

        XCTAssertEqual(items.map(\.shortcut), ["ctrl+k", nil])
    }

    func testAKeyItCannotUseLeavesTheFile() async throws {
        do {
            _ = try await SpotRuns().answer(of: spot, .set("panel_key", to: "k"), input: "", limit: 1)
            XCTFail("took a bad key")
        } catch {
            XCTAssertFalse(FileManager.default.fileExists(atPath: file.url.path))
        }
    }

    func testAPartRecordsAKeyAndReportsItsValue() throws {
        var part = try XCTUnwrap(SpotPart(block: TextBlock(fields: [
            .init(key: "hotkey", value: "open"), .init(key: "title", value: "Open"), .init(key: "value", value: "ctrl+k")
        ])))

        XCTAssertEqual(part.value, "ctrl+k")
        part.set("cmd+j")
        XCTAssertEqual(part.control, .shortcut("cmd+j"))
    }

    func testTheCatalogTeachesThePartAndFindsABadKey() {
        XCTAssertTrue(PartCatalog.text.contains("`hotkey`"))
        XCTAssertEqual(PluginOutput(text: "hotkey=a\nvalue=k\n").partFaults, ["the part a needs a shortcut that holds cmd, ctrl or option: k"])
        XCTAssertEqual(PluginOutput(text: "hotkey=a\nvalue=ctrl+k\n").partFaults, [])
    }
}
