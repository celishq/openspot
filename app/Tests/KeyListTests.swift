import XCTest
@testable import OpenspotCore

/// Proves the sheet that the app gives a script with commands and no read: a row for each of its commands, whose key a
/// person records or removes.
@MainActor
final class KeyListTests: XCTestCase {
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
        scan.listKeys(in: file)
        return scan
    }

    func testAScriptWithCommandsAndNoReadOpensToTheKeysOfItsOwnCommands() async throws {
        try "#!/bin/sh\n# title=Move\n#\n# button=left\n# title=Left side\n[ \"$1\" = left ] && printf 'toast=Left\\n'\n".writeScript(to: folder.appendingPathComponent("move.sh"))
        try "#!/bin/sh\n# title=Other\n#\n# button=up\n# title=Up\n".writeScript(to: folder.appendingPathComponent("other.sh"))
        let move = try XCTUnwrap(try scan().spots.first { $0.id == "move" })
        let runs = SpotRuns()

        XCTAssertEqual(move.kind, .list)
        XCTAssertTrue(move.setsKeys)
        let items = try await move.items(timeout: 1).items
        XCTAssertEqual(items.map(\.title), ["Left side shortcut"])
        XCTAssertEqual(items.map(\.subtitle), ["Press ⏎ to set"])
        XCTAssertEqual(items.map(\.shortcut), ["Record"])
        _ = try await runs.answer(of: move, .set("key:move:left", to: "ctrl+option+left"), limit: 1)
        XCTAssertEqual(file.read().keys.map(\.act), [.command("left")])
        let press = try await runs.answer(of: move, .press("left"), limit: 5)
        XCTAssertEqual(press, "toast=Left\n")
        _ = try await runs.answer(of: move, SpotAction(arguments: ["clear", "key:move:left"]), limit: 1)
        XCTAssertEqual(file.read().keys, [])
    }

    func testItTakesNoKeyOfAnotherSpotAndNoKeyItCannotUse() async throws {
        try "#!/bin/sh\n# title=Move\n#\n# button=left\n# title=Left side\n".writeScript(to: folder.appendingPathComponent("move.sh"))
        let move = try XCTUnwrap(try scan().spots.first { $0.id == "move" })
        let runs = SpotRuns()

        do {
            _ = try await runs.answer(of: move, .set("key:move:left", to: "k"), limit: 1)
            XCTFail("took a bad key")
        } catch {}
        _ = try? await runs.answer(of: move, .set("key:other:up", to: "ctrl+k"), limit: 5)

        XCTAssertEqual(file.read().keys, [])
    }

    func testAScriptWithAReadShowsTheKeysBesideItsOwnSheet() throws {
        try "#!/bin/sh\n# title=Move\n# on=sheet.open\n#\n# button=left\n# title=Left side\n".writeScript(to: folder.appendingPathComponent("move.sh"))

        let move = try XCTUnwrap(try scan().spots.first { $0.id == "move" })

        XCTAssertTrue(move.listsKeysAbove)
        XCTAssertTrue(move.setsKeys)
    }
}
