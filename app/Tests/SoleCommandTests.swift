import XCTest
@testable import OpenspotCore

/// Proves Return on a spot with one command: with no key yet it records one, and with a key it runs the command.
@MainActor
final class SoleCommandTests: XCTestCase {
    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: TestHost!
    private var model: SpotsModel!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-sole-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        suite = "openspot-sole-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        host = TestHost()
        let files = SpotFiles(
            environment: ["OPENSPOT_SPOTS": plugins.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path],
            home: folder,
            defaults: defaults
        )
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2))
        host.model = model
    }

    override func tearDown() async throws {
        model.quit()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: folder)
    }

    private var plugins: URL {
        folder.appendingPathComponent("plugins", isDirectory: true)
    }

    private func script(_ name: String, header: String) throws {
        let lines = header.split(separator: "\n", omittingEmptySubsequences: false).map { $0.isEmpty ? "#" : "# \($0)" }.joined(separator: "\n")
        try "#!/bin/sh\n\(lines)\nprintf 'toast=Ran %s\\n' \"$1\"\n".writeScript(to: plugins.appendingPathComponent("\(name).sh"))
    }

    private func wait(_ what: String, until condition: () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited for \(what)")
    }

    private func entry(_ id: String) throws -> SpotsModel.Entry {
        try XCTUnwrap(model.entries.first { $0.id == id })
    }

    func testTheFirstReturnRecordsTheKeyAndTheNextReturnRunsTheCommand() async throws {
        try script("dictate", header: "title=Dictate\n\nbutton=dictate\ntitle=Dictate")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])

        model.query = "dictate"
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "dictate" })
        XCTAssertEqual(model.hint, "⏎ Set key   ⌘⏎ Settings   ⌘K Actions")
        model.run(try entry("dictate"))

        XCTAssertEqual(model.recording, "key:dictate:dictate")
        try await wait("the key row") { model.openItems?.shown.contains { $0.run == "key:dictate:dictate" } == true }
        XCTAssertEqual(model.openList, "dictate")
        XCTAssertEqual(model.recordingWords, "Press keys or shake")
        model.record(code: 125, modifiers: .command)
        XCTAssertEqual(model.recording, "key:dictate:dictate")
        XCTAssertEqual(host.notes.last, "`⌘Down` belongs to the apps on the Mac. Hold `⌥` or `⌃` with a key, or tap one key such as `⌥`.")
        XCTAssertEqual(model.openItems?.shown.first?.title, "Dictate shortcut")
        XCTAssertEqual(model.openItems?.shown.first?.subtitle, "Press ⏎ to set")
        model.recordTap(.option)
        try await wait("the tap in the file") {
            model.files.config.read().keys == [GlobalKey(spot: "dictate", act: .command("dictate"), trigger: .tap(.option))]
        }
        try await wait("the new key in its row") { model.openItems?.shown.first?.shortcut == "option" }
        XCTAssertEqual(model.openItems?.shown.first?.subtitle, "Press ⌘↓ to select")
        XCTAssertEqual(model.openItems?.shown.first?.focusSubtitle, "Press ⏎ to change")
        XCTAssertNil(model.recording)
        XCTAssertEqual(model.openList, "dictate")
        XCTAssertEqual(host.dismissals, 0)

        model.closeList(moving: false)
        model.query = "dictate"
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "dictate" })
        try await wait("the key in the footer") { model.hint == "⏎ Dictate   ⌘⏎ Settings   ⌘K Actions" }
        XCTAssertTrue(model.openSoleSettings())
        try await wait("the key row again") { model.openList == "dictate" }
        XCTAssertNil(model.recording)
        model.closeList(moving: false)
        model.run(try entry("dictate"))

        try await wait("the command") { host.confirms == ["Ran dictate"] }
        XCTAssertNil(model.recording)
    }

    func testReturnOnASpotWithTwoCommandsOnlyOpensTheirKeys() async throws {
        try script("windows", header: "title=Windows\n\nbutton=left\ntitle=Left\n\nbutton=right\ntitle=Right")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])

        model.run(try entry("windows"))

        try await wait("the key rows") { model.openList == "windows" }
        XCTAssertNil(model.recording)
    }

    func testCommandReturnOpensTheSpotsOwnRowsAboveItsPinnedKey() async throws {
        let lines = ["title=Dictate", "on=sheet.open", "", "button=dictate", "title=Dictate"].map { $0.isEmpty ? "#" : "# \($0)" }
        try "#!/bin/sh\n\(lines.joined(separator: "\n"))\ncase \"$1\" in read) printf 'row=one\\ntitle=Hello there\\n\\nrow=two\\ntitle=Second\\n' ;; esac\n"
            .writeScript(to: plugins.appendingPathComponent("dictate.sh"))
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.query = "dictate"
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "dictate" })

        XCTAssertTrue(model.openSoleSettings())

        try await wait("the key and the rows") { model.openItems?.shown.count == 3 }
        XCTAssertEqual(model.openItems?.shown.map(\.run), ["key:dictate:dictate", "one", "two"])
        XCTAssertEqual(model.sheets["dictate"]?.shape.setsApart, false)
        model.searchText = "zzz"
        XCTAssertEqual(model.openItems?.shown.map(\.run), ["key:dictate:dictate"])
        model.searchText = ""
        model.moveItemToEdge(last: true)
        XCTAssertEqual(model.openItems?.selectedItem?.run, "two")
        model.moveItemToEdge(last: false)
        XCTAssertEqual(model.openItems?.selectedItem?.run, "key:dictate:dictate")
        XCTAssertNil(model.recording)
    }

    func testEachRowOfTheJoinedSheetKeepsOnlyItsOwnActions() {
        let keys = "button=open\ntitle=Change\n\nbutton=clear\ntitle=Remove\nshortcut=cmd+backspace\n\nrow=key:d:d\ntitle=Dictate\ntype=hotkey\nshortcut=option\n"
        let own = "button=open\ntitle=Copy\n\nbutton=delete\ntitle=Delete\nshortcut=cmd+backspace\n\nrow=1\ntitle=Hello\n"

        let blocks = TextBlock.blocks(in: SpotRuns.joined(keys: keys, own: own))
        let output = SpotOutput(text: SpotRuns.joined(keys: keys, own: own))
        let key = try? XCTUnwrap(output.items.first { $0.run == "key:d:d" })
        let text = try? XCTUnwrap(output.items.first { $0.run == "1" })

        XCTAssertEqual(blocks.filter { $0.fields.first?.key == "button" }.compactMap { $0.value("title") }, ["Copy", "Delete", "Remove"])
        XCTAssertEqual(key?.hides, ["open", "delete"])
        XCTAssertEqual(key?.isPinned, true)
        XCTAssertEqual(text?.isPinned, false)
        XCTAssertEqual(ItemList(items: output.items).shown.map(\.run), ["1", "key:d:d"])
        XCTAssertTrue(ItemList(items: output.items).setsApart)
        let unset = SpotOutput(text: SpotRuns.joined(keys: keys.replacingOccurrences(of: "shortcut=option", with: "shortcut=\(KeyList.unset)"), own: own))
        XCTAssertEqual(ItemList(items: unset.items).shown.map(\.run), ["key:d:d", "1"])
        XCTAssertFalse(ItemList(items: unset.items).setsApart)
        let unsetKey = unset.items.first { $0.run == "key:d:d" }
        XCTAssertEqual(ActionMenu(spot: Spot(id: "d", name: "d", url: URL(fileURLWithPath: "/d.sh")), item: unsetKey)?.rows.first?.title, "Set")
        XCTAssertEqual(text?.hides, ["clear"])
        XCTAssertEqual(ActionMenu(spot: Spot(id: "d", name: "d", url: URL(fileURLWithPath: "/d.sh")), item: key)?.rows.first?.title, "Change")
    }

    func testARowThatSaysCloseFalseNamesItsEnterAndKeepsThePanelOpen() async throws {
        let lines = ["title=Get", "on=sheet.open"].map { "# \($0)" }
        try "#!/bin/sh\n\(lines.joined(separator: "\n"))\ncase \"$1\" in read) printf 'button=open\\ntitle=Copy\\n\\nrow=model\\ntitle=Download\\nopen=Download\\nclose=false\\n\\nrow=text\\ntitle=Hello\\n' ;; esac\n"
            .writeScript(to: plugins.appendingPathComponent("get.sh"))
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.run(try entry("get"))
        try await wait("the rows") { model.openItems?.shown.count == 2 }

        XCTAssertEqual(model.hint.components(separatedBy: "   ").first, "⏎ Download")
        model.runSelectedItem()

        XCTAssertEqual(host.dismissals, 0)
        model.moveItemLine(by: 1)
        XCTAssertEqual(model.hint.components(separatedBy: "   ").first, "⏎ Copy")
        model.runSelectedItem()
        XCTAssertEqual(host.dismissals, 1)
    }

    func testASheetWithSearchOffHasNoFieldAndItsSetupRowFirst() async throws {
        let lines = ["title=Dictate", "on=sheet.open", "", "button=dictate", "title=Dictate"].map { $0.isEmpty ? "#" : "# \($0)" }
        try "#!/bin/sh\n\(lines.joined(separator: "\n"))\ncase \"$1\" in read) printf 'row=whisper\\ntitle=Download\\npin=top\\n\\nsearch=off\\n' ;; esac\n"
            .writeScript(to: plugins.appendingPathComponent("dictate.sh"))
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.query = "dictate"
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "dictate" })

        XCTAssertTrue(model.openSoleSettings())

        try await wait("the rows") { model.openItems?.shown.count == 2 }
        XCTAssertEqual(model.openItems?.shown.map(\.run), ["whisper", "key:dictate:dictate"])
        XCTAssertEqual(model.openItems?.selectedItem?.run, "whisper")
        XCTAssertEqual(model.openItems?.search, .off)
        XCTAssertEqual(model.sheets["dictate"]?.shape.setsApart, false)
        XCTAssertEqual(model.sheets["dictate"]?.shape.hasField, false)
    }
}
