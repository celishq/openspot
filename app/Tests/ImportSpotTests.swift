import XCTest
@testable import OpenspotCore

final class ImportSpotTests: BuiltInCase {
    private var sheet: Spot {
        get throws {
            try spot("import")
        }
    }

    private var scripts: URL {
        root.appendingPathComponent("home/.config/raycast/script-commands")
    }

    override func setUp() async throws {
        try await super.setUp()
        try "#!/bin/sh\n# @raycast.schemaVersion 1\n# @raycast.title Say Hello\n# @raycast.mode compact\necho hello\n".writeScript(to: scripts.appendingPathComponent("hello.sh"))
        try "#!/bin/sh\n# @raycast.schemaVersion 1\n# @raycast.title Notes\n# @raycast.mode silent\n".writeScript(to: scripts.appendingPathComponent("notes.template.sh"))
        let real = tools.appendingPathComponent("openspot-real")
        try FileManager.default.moveItem(at: tools.appendingPathComponent("openspot"), to: real)
        try fake("openspot", "echo \"$*\" >> '\(calls.path)'\nif [ \"$1 $2\" = 'folder pick' ]; then echo '\(scripts.path)'; exit 0; fi\nif [ \"$1 $2\" = 'spot open' ]; then exit 0; fi\nexec '\(real.path)' \"$@\"")
    }

    private var calls: URL {
        root.appendingPathComponent("calls")
    }

    private func answer(_ arguments: [String]) async throws -> String {
        try await runs.answer(of: try sheet, arguments == ["read"] ? .read : SpotAction(arguments: arguments), limit: 60)
    }

    private func rows(_ text: String) -> [String] {
        TextBlock.blocks(in: text).compactMap { $0.value("row") }
    }

    func testAFirstReadAsksForTheFolderOfScriptCommands() async throws {
        let text = try await answer(["read"])

        XCTAssertEqual(rows(text), [])
        XCTAssertTrue(text.contains("button=choose\ntitle=Choose Folder…\nlook=strong\nshortcut=return\n"), text)
    }

    func testAChosenFolderListsWhatAnImportAddsAndWhatItSkips() async throws {
        _ = try await answer(["choose"])

        let text = try await answer(["read"])

        XCTAssertEqual(rows(text), ["added:say-hello", "skipped:notes.template.sh"])
        XCTAssertTrue(text.contains("title=Add 1 script from Raycast\ndetail=\(scripts.path)\n"), text)
        XCTAssertTrue(text.contains("file=\(scripts.path)/hello.sh\nsection=To add\n"), text)
        XCTAssertTrue(text.contains("button=import\n"), text)
    }

    func testImportAddsTheSpotsAndTheListThenShowsThemAsImported() async throws {
        _ = try await answer(["choose"])

        let toast = try await sheet.perform(SpotAction(arguments: ["import"]), timeout: 60)
        let text = try await answer(["read"])

        XCTAssertEqual(toast, "Added 1 spot")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: spots.appendingPathComponent("say-hello.spot/say-hello.sh").path))
        XCTAssertEqual(rows(text), ["kept:say-hello", "skipped:notes.template.sh"])
        XCTAssertTrue(text.contains("title=Nothing new to add\n"), text)
        XCTAssertFalse(text.contains("button=import\n"), text)
    }

    func testThePanelOpensAgainOnTheSheetAfterTheFolderIsPicked() async throws {
        _ = try await answer(["choose"])

        let calls = try String(contentsOf: calls, encoding: .utf8).split(separator: "\n")

        XCTAssertEqual(calls, ["folder pick", "spot open openspot/import"])
    }
}
