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

    private var copied: URL {
        root.appendingPathComponent("copied")
    }

    private var extensions: URL {
        root.appendingPathComponent("home/.config/raycast/extensions")
    }

    private func install(_ folder: String, name: String, title: String) throws {
        let url = extensions.appendingPathComponent(folder)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try #"{"name":"\#(name)","title":"\#(title)","description":"\#(title) in Raycast.","commands":[{"name":"run","title":"Run","mode":"view"}]}"#.write(to: url.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
    }

    private func showExtensions() throws {
        try install("a1", name: "linear", title: "Linear")
        try install("b2", name: "jira", title: "Jira")
        try install("c3", name: "translate", title: "Google Translate")
        try install("d4", name: "caffeinate", title: "Caffeinate")
        try FileManager.default.copyItem(at: repoSpots.appendingPathComponent("caffeinate.spot"), to: core.appendingPathComponent("caffeinate.spot"))
        try FileManager.default.copyItem(at: repoSpots.appendingPathComponent("translate.spot"), to: spots.appendingPathComponent("translate.spot"))
        let data = root.appendingPathComponent("data/openspot")
        try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        try extensions.path.write(to: data.appendingPathComponent("raycast-extensions"), atomically: true, encoding: .utf8)
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
        try fake("openspot", "echo \"$*\" >> '\(log.path)'\n[ \"$1\" = toast ] && exit 0\ncase \"$1 $2\" in 'spot open'|'spot push'|'spot choose') exit 0 ;; 'store get') echo \"Turned on $3.\"; exit 0 ;; 'clipboard copy') cat > '\(copied.path)'; exit 0 ;; esac\nexec '\(real.path)' \"$@\"")
    }

    private func answer(_ arguments: [String], page: String? = nil, input: String? = nil) async throws -> String {
        let route = page.map { "route=\($0)\n" } ?? ""
        return try await runs.answer(of: try sheet, SpotAction(arguments: arguments), input: route + (input ?? ""), limit: 60)
    }

    private func toast() throws -> String? {
        try calls().last { $0.hasPrefix("toast ") }.map { String($0.dropFirst(6)) }
    }

    private func blocks(_ text: String) -> [TextBlock] {
        TextBlock.blocks(in: text)
    }

    private func rows(_ text: String) -> [String] {
        let placed = Set(blocks(text).first { $0.fields.first?.key == "frame" }?.values("grid").flatMap { $0.split(separator: " ").map(String.init) } ?? [])
        return blocks(text).compactMap { $0.value("text") }.filter { !placed.contains($0) }
    }

    private func block(_ id: String, in text: String) -> TextBlock? {
        blocks(text).first { $0.fields.first?.value == id }
    }

    private func calls() throws -> [String] {
        try String(contentsOf: log, encoding: .utf8).split(separator: "\n").map(String.init)
    }

    func testTheHubHasARowForEachSourceThatOpensItsPage() async throws {
        let text = try await answer(["show"])

        XCTAssertEqual(rows(text), ["scripts", "export", "analogs", "extensions"])
        XCTAssertEqual(block("scripts", in: text)?.value("route"), "scripts")
        XCTAssertEqual(block("export", in: text)?.value("route"), "export")
        XCTAssertEqual(blocks(text).first?.fields.first?.key, "frame")
        XCTAssertFalse(text.contains("button="), text)
    }

    func testEachPageSaysWhereToFindItsSourceInRaycast() async throws {
        let scriptsPage = try await answer(["show"], page: "scripts")
        let exportPage = try await answer(["show"], page: "export")

        XCTAssertTrue(block("where", in: scriptsPage)?.value("detail")?.contains("Settings → Extensions → Script Commands") == true, scriptsPage)
        XCTAssertEqual(block("choose", in: scriptsPage)?.value("title"), "Choose Folder…")
        XCTAssertTrue(block("where", in: exportPage)?.value("detail")?.contains("Export Settings & Data") == true, exportPage)
        XCTAssertEqual(block("choose", in: exportPage)?.value("title"), "Choose Export File…")
    }

    func testADropKeepsEachSourceAndOpensItsPage() async throws {
        _ = try await answer(["choose"], page: "scripts")
        _ = try await answer(["drop", scripts.path])
        _ = try await answer(["drop", export.path])
        let hub = try await answer(["show"])

        XCTAssertEqual(try calls().prefix(5), [
            "spot choose openspot/import",
            "spot open openspot/import", "spot push openspot/import scripts",
            "spot open openspot/import", "spot push openspot/import export"
        ])
        XCTAssertEqual(block("export", in: hub)?.value("detail"), "Enter the passphrase to open it")
        XCTAssertTrue(try sheet.takesFolders)
        XCTAssertTrue(try sheet.accepts(FileKinds([export.path], kinds: [export.path: .file])))
    }

    func testTheScriptsPageListsWhatItAddsAndImportsIt() async throws {
        _ = try await answer(["drop", scripts.path])

        let page = try await answer(["show"], page: "scripts")
        try await sheet.perform(SpotAction(arguments: ["import"]), page: "scripts", timeout: 60)
        let toast = try toast()
        let after = try await answer(["show"], page: "scripts")
        let hub = try await answer(["show"])

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

        let text = try await answer(["show"], page: "export", input: "input.passphrase=openspot-test\n")

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

        let frames = try await answer(["unlock"], page: "export", input: "input.passphrase=openspot-test\n").components(separatedBy: "---\n")
        let open = try await answer(["show"], page: "export", input: "input.passphrase=openspot-test\n")

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

        _ = try await answer(["unlock"], page: "export", input: "input.passphrase=wrong-pass\n")
        let text = try await answer(["show"], page: "export", input: "input.passphrase=wrong-pass\n")

        XCTAssertEqual(block("failure", in: text)?.value("title"), "Wrong passphrase")
        XCTAssertEqual(block("failure", in: text)?.value("tone"), "bad")
        XCTAssertNil(block("failure", in: text)?.value("detail"))
        XCTAssertNil(block("hint", in: text))
        XCTAssertEqual(blocks(text).first?.values("grid"), ["file", "passphrase", "failure", "unlock"])
    }

    func testImportAddsTheLinksAndSnippetsAndMarksThemImported() async throws {
        _ = try await answer(["drop", export.path])
        _ = try await answer(["unlock"], page: "export", input: "input.passphrase=openspot-test\n")

        try await sheet.perform(SpotAction(arguments: ["import"]), page: "export", timeout: 60)
        let toast = try toast()
        let after = try await answer(["show"], page: "export")
        let hub = try await answer(["show"])

        XCTAssertEqual(toast, "Added 1 link to Links and Added 1 snippet to Snippets.")
        XCTAssertEqual(rows(after), ["source", "done:links", "done:snippets", "skipped:hotkeys", "skipped:aliases"])
        XCTAssertEqual(block("done:links", in: after)?.value("spot"), "links")
        XCTAssertNil(block("import", in: after))
        XCTAssertEqual(block("export", in: hub)?.value("detail"), "Imported")
    }

    func testAReadWhileTheExportOpensSaysOpening() async throws {
        _ = try await answer(["drop", export.path])
        try export.path.write(to: root.appendingPathComponent("data/openspot/raycast-opening"), atomically: true, encoding: .utf8)

        let text = try await answer(["show"], page: "export", input: "input.passphrase=openspot-test\n")

        XCTAssertEqual(block("unlock", in: text)?.value("title"), "Opening…")
    }

    func testAChangeOfThePassphraseRedrawsNothing() async throws {
        let text = try await answer(["passphrase", "abc"], page: "export", input: "input.passphrase=abc\n")

        XCTAssertEqual(blocks(text).map { $0.fields.first?.key }, ["frame"])
    }

    func testReturnOnAScriptUnticksItAndImportLeavesItOut() async throws {
        _ = try await answer(["drop", scripts.path])

        _ = try await answer(["open", "added:say-hello"], page: "scripts", input: "item.path=hello.sh\n")
        let page = try await answer(["show"], page: "scripts")

        XCTAssertEqual(block("added:say-hello", in: page)?.value("value"), "false")
        XCTAssertEqual(block("added:say-hello", in: page)?.value("section"), "To add · 0 of 1")
        XCTAssertNil(block("import", in: page))
    }

    func testReturnOnAKindUnticksItAndImportLeavesItOut() async throws {
        _ = try await answer(["drop", export.path])
        _ = try await answer(["unlock"], page: "export", input: "input.passphrase=openspot-test\n")

        _ = try await answer(["open", "added:snippets"], page: "export")
        let page = try await answer(["show"], page: "export")
        try await sheet.perform(SpotAction(arguments: ["import"]), page: "export", timeout: 60)
        let toast = try toast()

        XCTAssertEqual(block("added:snippets", in: page)?.value("value"), "false")
        XCTAssertEqual(block("added:links", in: page)?.value("value"), "true")
        XCTAssertEqual(toast, "Added 1 link to Links.")
    }

    func testTheTopRowNamesTheChoiceAndOpensTheChooserAndChangeIsInTheMenu() async throws {
        _ = try await answer(["drop", export.path])
        _ = try await answer(["unlock"], page: "export", input: "input.passphrase=openspot-test\n")

        let page = try await answer(["show"], page: "export")
        _ = try await answer(["open", "source"], page: "export")

        XCTAssertEqual(rows(page).first, "source")
        XCTAssertEqual(block("source", in: page)?.value("title"), "Raycast 2026-11-18.rayconfig")
        XCTAssertEqual(block("source", in: page)?.value("pin"), "top")
        XCTAssertEqual(block("choose", in: page)?.value("title"), "Change File")
        XCTAssertEqual(block("choose", in: page)?.value("shortcut"), "cmd+o")
        XCTAssertFalse(page.contains("grid=choose"), page)
        XCTAssertEqual(try calls().last, "spot choose openspot/import")
    }

    func testTheAnalogsPageOpensTheSpotsReadyToUseAndTicksTheSpotsToAdd() async throws {
        try showExtensions()

        let page = try await answer(["show"], page: "analogs")
        let hub = try await answer(["show"])

        XCTAssertEqual(rows(page), ["use:translate", "get:caffeinate"])
        XCTAssertEqual(block("use:translate", in: page)?.value("section"), "Ready to use")
        XCTAssertEqual(block("use:translate", in: page)?.value("detail"), "→ Translate")
        XCTAssertEqual(block("use:translate", in: page)?.value("spot"), "translate")
        XCTAssertEqual(block("use:translate", in: page)?.value("spot.title"), "Translate")
        XCTAssertEqual(block("get:caffeinate", in: page)?.value("section"), "To add · 1 of 1")
        XCTAssertEqual(block("get:caffeinate", in: page)?.value("value"), "true")
        XCTAssertEqual(block("get:caffeinate", in: page)?.value("open.title"), "Untick")
        XCTAssertEqual(block("use:translate", in: page)?.value("open.title"), "Open")

        XCTAssertEqual(block("preview", in: page)?.fields.first?.key, "view")
        XCTAssertEqual(block("add", in: page)?.value("title"), "Add Caffeinate")
        XCTAssertEqual(block("add", in: page)?.value("shortcut"), "cmd+return")
        XCTAssertNil(block("copy", in: page))
        XCTAssertEqual(block("analogs", in: hub)?.value("detail"), "1 ready to use · 1 to add")
        XCTAssertEqual(block("extensions", in: hub)?.value("detail"), "2 without an analog")
    }

    func testLearnMoreOpensTheStoreOnTheSpotOfTheRow() async throws {
        try showExtensions()

        let page = try await answer(["show"], page: "analogs")
        _ = try await answer(["learn", "get:caffeinate"], page: "analogs")
        let shown = try String(contentsOf: root.appendingPathComponent("data/openspot/store-show"), encoding: .utf8)

        XCTAssertEqual(block("learn", in: page)?.value("title"), "Learn More")
        XCTAssertEqual(block("learn", in: page)?.value("shortcut"), "cmd+i")
        XCTAssertNil(block("get:caffeinate", in: page)?.value("hides"))
        XCTAssertNil(block("use:translate", in: page)?.value("hides"))
        XCTAssertEqual(shown, "caffeinate")
        XCTAssertEqual(try calls().last, "spot open openspot/store")
    }

    func testAddGetsTheTickedAnalogs() async throws {
        try showExtensions()

        let added = try await answer(["add"], page: "analogs")
        _ = try await answer(["open", "get:caffeinate"], page: "analogs")
        let page = try await answer(["show"], page: "analogs")

        XCTAssertTrue(try calls().contains("store get caffeinate"))
        XCTAssertEqual(try toast(), "Added Caffeinate.")
        XCTAssertNotNil(block("add", in: added))
        XCTAssertEqual(block("get:caffeinate", in: page)?.value("value"), "false")
        XCTAssertEqual(block("get:caffeinate", in: page)?.value("open.title"), "Tick")
        XCTAssertNil(block("add", in: page))
    }

    func testTheMakePageTicksEachExtensionWithNoAnalogForOnePrompt() async throws {
        try showExtensions()

        let page = try await answer(["show"], page: "extensions")

        XCTAssertEqual(rows(page), ["make:jira", "make:linear"])
        XCTAssertEqual(block("make:linear", in: page)?.value("section"), "Without an analog · 2 of 2")
        XCTAssertEqual(block("make:linear", in: page)?.value("value"), "true")
        XCTAssertEqual(block("make:linear", in: page)?.value("hides"), "learn")
        XCTAssertNil(block("learn", in: page))
        XCTAssertEqual(block("copy", in: page)?.value("title"), "Copy prompt for 2 extensions")
        XCTAssertEqual(block("copy", in: page)?.value("shortcut"), "cmd+return")
        XCTAssertNil(block("add", in: page))
    }

    func testCopyPutsAPromptForTheTickedExtensionsOnTheClipboardAndFlashesCopied() async throws {
        try showExtensions()
        _ = try await answer(["open", "make:jira"], page: "extensions")

        let page = try await answer(["show"], page: "extensions")
        let frames = try await answer(["copy"], page: "extensions").components(separatedBy: "frame=extensions\n").filter { !$0.isEmpty }
        let prompt = try String(contentsOf: copied, encoding: .utf8)

        XCTAssertEqual(block("copy", in: page)?.value("title"), "Copy prompt for Linear")
        XCTAssertEqual(frames.count, 2)
        XCTAssertEqual(try toast(), "Prompt copied. Paste it into your agent.")
        XCTAssertEqual(block("copy", in: frames[0])?.value("title"), "✓ Copied")
        XCTAssertEqual(block("copy", in: frames.last ?? "")?.value("title"), "Copy prompt for Linear")
        XCTAssertTrue(prompt.hasPrefix("Turn this Raycast extension into an Openspot spot."), prompt)
        XCTAssertTrue(prompt.contains("Linear (\(extensions.appendingPathComponent("a1").path))"), prompt)
        XCTAssertFalse(prompt.contains("Jira"), prompt)
    }

    func testThePageSaysWhenRaycastKeepsNoExtensions() async throws {
        let page = try await answer(["show"], page: "extensions")

        XCTAssertEqual(block("where", in: page)?.value("title"), "No Raycast extensions on this Mac")
    }
}
