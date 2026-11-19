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

    private var export: URL {
        root.appendingPathComponent("home/Raycast 2026-11-18.rayconfig")
    }

    private var log: URL {
        root.appendingPathComponent("calls")
    }

    override func setUp() async throws {
        try await super.setUp()
        try "#!/bin/sh\n# @raycast.schemaVersion 1\n# @raycast.title Say Hello\n# @raycast.mode compact\necho hello\n".writeScript(to: scripts.appendingPathComponent("hello.sh"))
        try "#!/bin/sh\n# @raycast.schemaVersion 1\n# @raycast.title Notes\n# @raycast.mode silent\n".writeScript(to: scripts.appendingPathComponent("notes.template.sh"))
        for name in ["links", "snippets"] {
            try FileManager.default.copyItem(at: repoSpots.appendingPathComponent("\(name).spot"), to: core.appendingPathComponent("\(name).spot"))
        }
        try RaycastExport.file(RaycastExport.testPayload, passphrase: "openspot-test").write(to: export)
        let real = tools.appendingPathComponent("openspot-real")
        try FileManager.default.moveItem(at: tools.appendingPathComponent("openspot"), to: real)
        try fake("openspot", "echo \"$*\" >> '\(log.path)'\ncase \"$1 $2\" in 'spot open'|'spot push'|'spot choose') exit 0 ;; esac\nexec '\(real.path)' \"$@\"")
    }

    private func answer(_ arguments: [String], page: String? = nil, input: String? = nil) async throws -> String {
        let action = arguments == ["read"] ? SpotAction.read : SpotAction(arguments: arguments)
        return try await runs.answer(of: try sheet, action, input: input, limit: 60, variables: page.map { ["OPENSPOT_PAGE": $0] } ?? [:])
    }

    private func blocks(_ text: String) -> [TextBlock] {
        TextBlock.blocks(in: text)
    }

    private func rows(_ text: String) -> [String] {
        blocks(text).compactMap { $0.value("row") }
    }

    private func block(_ id: String, in text: String) -> TextBlock? {
        blocks(text).first { $0.fields.first?.value == id }
    }

    private func calls() throws -> [String] {
        try String(contentsOf: log, encoding: .utf8).split(separator: "\n").map(String.init)
    }

    func testTheHubHasARowForEachSourceThatOpensItsPage() async throws {
        let text = try await answer(["read"])

        XCTAssertEqual(rows(text), ["scripts", "export"])
        XCTAssertEqual(block("scripts", in: text)?.value("push"), "scripts")
        XCTAssertEqual(block("export", in: text)?.value("push"), "export")
        XCTAssertEqual(blocks(text).first?.value("search"), "off")
        XCTAssertFalse(text.contains("button="), text)
    }

    func testEachPageSaysWhereToFindItsSourceInRaycast() async throws {
        let scriptsPage = try await answer(["read"], page: "scripts")
        let exportPage = try await answer(["read"], page: "export")

        XCTAssertTrue(block("where", in: scriptsPage)?.value("detail")?.contains("Settings → Extensions → Script Commands") == true, scriptsPage)
        XCTAssertEqual(block("choose", in: scriptsPage)?.value("title"), "Choose Folder…")
        XCTAssertTrue(block("where", in: exportPage)?.value("detail")?.contains("Export Settings & Data") == true, exportPage)
        XCTAssertEqual(block("choose", in: exportPage)?.value("title"), "Choose Export File…")
    }

    func testADropKeepsEachSourceAndOpensItsPage() async throws {
        _ = try await answer(["choose"], page: "scripts")
        _ = try await answer(["drop", scripts.path])
        _ = try await answer(["drop", export.path])
        let hub = try await answer(["read"])

        XCTAssertEqual(try calls().prefix(5), [
            "spot choose openspot/import",
            "spot open openspot/import", "spot push openspot/import scripts --title Script Commands",
            "spot open openspot/import", "spot push openspot/import export --title Settings & Data"
        ])
        XCTAssertEqual(block("export", in: hub)?.value("detail"), "Enter the passphrase to open it")
        XCTAssertTrue(try sheet.takesFolders)
        XCTAssertTrue(try sheet.accepts(FileKinds([export.path], kinds: [export.path: .file])))
    }

    func testTheScriptsPageListsWhatItAddsAndImportsIt() async throws {
        _ = try await answer(["drop", scripts.path])

        let page = try await answer(["read"], page: "scripts")
        let toast = try await sheet.perform(SpotAction(arguments: ["import"]), page: "scripts", timeout: 60)
        let after = try await answer(["read"], page: "scripts")
        let hub = try await answer(["read"])

        XCTAssertEqual(rows(page), ["source", "added:say-hello", "skipped:notes.template.sh"])
        XCTAssertEqual(block("import", in: page)?.value("title"), "Import")
        XCTAssertEqual(block("added:say-hello", in: page)?.value("section"), "To add · 1 of 1")
        XCTAssertNil(block("added:say-hello", in: page)?.value("type"))
        XCTAssertEqual(block("added:say-hello", in: page)?.value("path"), "hello.sh")
        XCTAssertEqual(block("added:say-hello", in: page)?.value("value"), "true")
        XCTAssertEqual(block("import", in: page)?.value("shortcut"), "cmd+return")
        XCTAssertEqual(toast, "Added 1 spot. Find it on the grid.")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: spots.appendingPathComponent("say-hello.spot/say-hello.sh").path))
        XCTAssertEqual(rows(after), ["source", "kept:say-hello", "skipped:notes.template.sh"])
        XCTAssertNil(block("import", in: after))
        XCTAssertEqual(block("scripts", in: hub)?.value("detail"), "All imported from script-commands")
    }

    func testTheExportPageAsksForThePassphraseAndSaysWhereItIs() async throws {
        _ = try await answer(["drop", export.path])

        let text = try await answer(["read"], page: "export", input: "passphrase=openspot-test\n")

        XCTAssertEqual(block("passphrase", in: text)?.value("type"), "secret")
        XCTAssertEqual(block("passphrase", in: text)?.value("placeholder"), "Passphrase from Raycast → Settings → Advanced")
        XCTAssertEqual(block("file", in: text)?.value("title"), "Raycast 2026-11-18.rayconfig")
        XCTAssertEqual(blocks(text).first?.values("grid"), ["file", "passphrase", "unlock"])
        XCTAssertNil(block("hint", in: text))
        XCTAssertEqual(block("unlock", in: text)?.value("shortcut"), "return")
        XCTAssertEqual(rows(text), [])
        XCTAssertFalse(try calls().contains { $0.hasPrefix("import rayconfig") })
    }

    func testOpenKeepsTheLayoutWhileItOpensThenListsWhatItAdds() async throws {
        _ = try await answer(["drop", export.path])

        let frames = try await answer(["unlock"], page: "export", input: "passphrase=openspot-test\n").components(separatedBy: "---\n")
        let open = try await answer(["read"], page: "export", input: "passphrase=openspot-test\n")

        XCTAssertEqual(block("unlock", in: frames[0])?.value("title"), "Opening…")
        XCTAssertEqual(blocks(frames[0]).first?.values("grid"), ["file", "passphrase", "unlock"])
        XCTAssertNotNil(block("passphrase", in: frames[0]))
        XCTAssertEqual(rows(open), ["source", "added:links", "added:snippets", "skipped:hotkeys", "skipped:aliases"])
        XCTAssertEqual(block("skipped:hotkeys", in: open)?.value("section"), "Not supported yet")
        XCTAssertNil(block("passphrase", in: open))
        XCTAssertEqual(block("import", in: open)?.value("shortcut"), "cmd+return")
        XCTAssertEqual(block("added:links", in: open)?.value("value"), "true")
    }

    func testAWrongPassphraseIsARedLineWithAPlainHintUnderIt() async throws {
        _ = try await answer(["drop", export.path])

        _ = try await answer(["unlock"], page: "export", input: "passphrase=wrong-pass\n")
        let text = try await answer(["read"], page: "export", input: "passphrase=wrong-pass\n")

        XCTAssertEqual(block("failure", in: text)?.value("title"), "Wrong passphrase")
        XCTAssertEqual(block("failure", in: text)?.value("tone"), "bad")
        XCTAssertNil(block("failure", in: text)?.value("detail"))
        XCTAssertNil(block("hint", in: text))
        XCTAssertEqual(blocks(text).first?.values("grid"), ["file", "passphrase", "failure", "unlock"])
    }

    func testImportAddsTheLinksAndSnippetsAndMarksThemImported() async throws {
        _ = try await answer(["drop", export.path])
        _ = try await answer(["unlock"], page: "export", input: "passphrase=openspot-test\n")

        let toast = try await sheet.perform(SpotAction(arguments: ["import"]), page: "export", timeout: 60)
        let after = try await answer(["read"], page: "export")
        let hub = try await answer(["read"])

        XCTAssertEqual(toast, "Added 1 link to Links and Added 1 snippet to Snippets.")
        XCTAssertEqual(rows(after), ["source", "done:links", "done:snippets", "skipped:hotkeys", "skipped:aliases"])
        XCTAssertEqual(block("done:links", in: after)?.value("push.spot"), "links")
        XCTAssertNil(block("import", in: after))
        XCTAssertEqual(block("export", in: hub)?.value("detail"), "Imported")
    }

    func testAReadWhileTheExportOpensSaysOpening() async throws {
        _ = try await answer(["drop", export.path])
        try export.path.write(to: root.appendingPathComponent("data/openspot/raycast-opening"), atomically: true, encoding: .utf8)

        let text = try await answer(["read"], page: "export", input: "passphrase=openspot-test\n")

        XCTAssertEqual(block("unlock", in: text)?.value("title"), "Opening…")
    }

    func testAChangeOfThePassphraseRedrawsNothing() async throws {
        let text = try await answer(["passphrase", "abc"], page: "export", input: "passphrase=abc\n")

        XCTAssertEqual(blocks(text).map { $0.fields.first?.key }, ["recents"])
    }

    func testReturnOnAScriptUnticksItAndImportLeavesItOut() async throws {
        _ = try await answer(["drop", scripts.path])

        _ = try await answer(["open", "added:say-hello"], page: "scripts", input: "path=hello.sh\n")
        let page = try await answer(["read"], page: "scripts")

        XCTAssertEqual(block("added:say-hello", in: page)?.value("value"), "false")
        XCTAssertEqual(block("added:say-hello", in: page)?.value("section"), "To add · 0 of 1")
        XCTAssertNil(block("import", in: page))
    }

    func testReturnOnAKindUnticksItAndImportLeavesItOut() async throws {
        _ = try await answer(["drop", export.path])
        _ = try await answer(["unlock"], page: "export", input: "passphrase=openspot-test\n")

        _ = try await answer(["open", "added:snippets"], page: "export")
        let page = try await answer(["read"], page: "export")
        let toast = try await sheet.perform(SpotAction(arguments: ["import"]), page: "export", timeout: 60)

        XCTAssertEqual(block("added:snippets", in: page)?.value("value"), "false")
        XCTAssertEqual(block("added:links", in: page)?.value("value"), "true")
        XCTAssertEqual(toast, "Added 1 link to Links.")
    }

    func testTheTopRowNamesTheChoiceAndOpensTheChooserAndChangeIsInTheMenu() async throws {
        _ = try await answer(["drop", export.path])
        _ = try await answer(["unlock"], page: "export", input: "passphrase=openspot-test\n")

        let page = try await answer(["read"], page: "export")
        _ = try await answer(["open", "source"], page: "export")

        XCTAssertEqual(rows(page).first, "source")
        XCTAssertEqual(block("source", in: page)?.value("title"), "Raycast 2026-11-18.rayconfig")
        XCTAssertEqual(block("source", in: page)?.value("pin"), "top")
        XCTAssertEqual(block("choose", in: page)?.value("title"), "Change File")
        XCTAssertEqual(block("choose", in: page)?.value("shortcut"), "cmd+o")
        XCTAssertFalse(page.contains("grid=choose"), page)
        XCTAssertEqual(try calls().last, "spot choose openspot/import")
    }
}
