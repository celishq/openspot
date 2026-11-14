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
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        suite = "openspot-sole-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        host = TestHost()
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path],
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

    private var spots: URL {
        folder.appendingPathComponent("spots", isDirectory: true)
    }

    private func script(_ name: String, header: String) throws {
        let lines = header.split(separator: "\n", omittingEmptySubsequences: false).map { $0.isEmpty ? "#" : "# \($0)" }.joined(separator: "\n")
        try "#!/bin/sh\n\(lines)\nprintf 'toast=Ran %s\\n' \"$1\"\n".writeScript(to: spots.appendingPathComponent("\(name).sh"))
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
        XCTAssertEqual(model.openList, SpotSettings.sheetID(of: "dictate"))
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
        XCTAssertEqual(model.openList, SpotSettings.sheetID(of: "dictate"))
        XCTAssertEqual(host.dismissals, 0)

        model.closeList(moving: false)
        model.query = "dictate"
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "dictate" })
        try await wait("the key in the footer") { model.hint == "⏎ Dictate   ⌘⏎ Settings   ⌘K Actions" }
        XCTAssertTrue(model.openSelectedSettings())
        try await wait("the key row again") { model.openList == SpotSettings.sheetID(of: "dictate") }
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

        try await wait("the key rows") { model.openList == SpotSettings.sheetID(of: "windows") }
        try await wait("their rows") { model.openItems?.shown.map(\.run) == ["key:windows:left", "key:windows:right", "menubar:windows"] }
        XCTAssertNil(model.recording)
    }

    func testReturnRunsTheOneCommandOfASpotWithRowsAndCommandYOpensTheRowsAsHistory() async throws {
        let lines = ["title=Dictate", "on=sheet.open", "on=app.update", "", "button=dictate", "title=Dictate"].map { $0.isEmpty ? "#" : "# \($0)" }
        try "#!/bin/sh\n\(lines.joined(separator: "\n"))\ncase \"$1\" in read) printf 'row=one\\ntitle=Hello there\\n\\nrow=two\\ntitle=Second\\n' ;; esac\n"
            .writeScript(to: spots.appendingPathComponent("dictate.sh"))
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.query = "dictate"
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "dictate" })

        XCTAssertEqual(try entry("dictate").spot.soleCommand, "dictate")
        XCTAssertFalse(try entry("dictate").spot.opensOnReturn)
        XCTAssertEqual(model.hint, "⏎ Set key   ⌘⏎ Settings   ⌘K Actions")
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        let menu = try XCTUnwrap(model.menu)
        XCTAssertEqual(menu.rows.map(\.title), ["Dictate", "History", "Share", "Settings", "Delete"])
        XCTAssertEqual(menu.rows.filter { $0.title == "Dictate" }.count, 1)
        XCTAssertEqual(menu.rows.first { $0.title == "History" }?.keyLabel, "⌘Y")
        XCTAssertEqual(menu.rows.last?.isDestructive, true)
        XCTAssertEqual(menu.rows.filter(\.isDestructive).count, 1)
        model.closeMenu()

        XCTAssertTrue(model.handleKey(ActionKey(name: "y", isCommand: true)))
        try await wait("its History with a search typed") { model.openList == "dictate" }
        model.closeList(moving: false)

        model.run(.history, on: SpotsModel.Target(entry: try entry("dictate"), item: nil))
        try await wait("its own rows") { model.openItems?.shown.map(\.run) == ["one", "two"] }
        XCTAssertEqual(model.openList, "dictate")
        model.closeList(moving: false)

        model.runSelected()
        try await wait("its settings, recording its key") {
            model.recording == SpotSettings.keyRun(spot: "dictate", command: "dictate") && model.openList == SpotSettings.sheetID(of: "dictate")
        }
    }

    func testAKeyRowSaysSetUntilItHasAKeyAndChangeAfter() {
        let spot = Spot(id: "d", name: "d", url: URL(fileURLWithPath: "/d.sh"))
        let unset = SpotOutput(text: "row=key:d:d\ntitle=Dictate\ntype=hotkey\nshortcut=\(SpotSettings.unset)\n").items.first
        let set = SpotOutput(text: "row=key:d:d\ntitle=Dictate\ntype=hotkey\nshortcut=option\n").items.first

        XCTAssertEqual(ActionMenu(spot: spot, item: unset)?.rows.first?.title, "Set")
        XCTAssertEqual(ActionMenu(spot: spot, item: set)?.rows.first?.title, "Change")
    }

    func testARowThatSaysCloseFalseNamesItsEnterAndKeepsThePanelOpen() async throws {
        let lines = ["title=Get", "on=sheet.open"].map { "# \($0)" }
        try "#!/bin/sh\n\(lines.joined(separator: "\n"))\ncase \"$1\" in read) printf 'button=open\\ntitle=Copy\\n\\nrow=model\\ntitle=Download\\nopen=Download\\nclose=false\\n\\nrow=text\\ntitle=Hello\\n' ;; esac\n"
            .writeScript(to: spots.appendingPathComponent("get.sh"))
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

    func testASheetWithSearchOffShowsOnlyItsOwnRowsAsItsHistory() async throws {
        let lines = ["title=Dictate", "on=sheet.open", "", "button=dictate", "title=Dictate"].map { $0.isEmpty ? "#" : "# \($0)" }
        try "#!/bin/sh\n\(lines.joined(separator: "\n"))\ncase \"$1\" in read) printf 'row=whisper\\ntitle=Download\\npin=top\\n\\nsearch=off\\n' ;; esac\n"
            .writeScript(to: spots.appendingPathComponent("dictate.sh"))
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])

        model.run(.history, on: SpotsModel.Target(entry: try entry("dictate"), item: nil))

        try await wait("the rows") { model.openItems?.shown.count == 1 }
        XCTAssertEqual(model.openItems?.shown.map(\.run), ["whisper"])
        XCTAssertEqual(model.openItems?.search, .off)
        XCTAssertEqual(model.sheets["dictate"]?.shape.hasField, false)
    }

    func testAClickOnTheMenuBarIconOfASpotThatReturnRunsDoesWhatReturnDoes() async throws {
        let lines = ["title=Pen", "icon=pencil.tip", "", "button=draw", "title=Draw on screen"].map { $0.isEmpty ? "#" : "# \($0)" }
        try "#!/bin/sh\n\(lines.joined(separator: "\n"))\nexit 0\n".writeScript(to: spots.appendingPathComponent("pen.sh"))
        model.reload()

        model.openFromMenuBar("pen")

        try await wait("its key, as the first Return records it") {
            model.recording == SpotSettings.keyRun(spot: "pen", command: "draw") && model.openList == SpotSettings.sheetID(of: "pen")
        }
        XCTAssertGreaterThan(host.shows, 0)
    }
}
