import XCTest
@testable import OpenspotCore

@MainActor
final class SoleCommandTests: XCTestCase {
    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: FakeHost!
    private var model: SpotsModel!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-sole-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        suite = "openspot-sole-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        host = FakeHost()
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

    private func entry(_ id: String) throws -> SpotsModel.Entry {
        try XCTUnwrap(model.entries.first { $0.id == id })
    }

    func testTheFirstReturnRecordsTheKeyAndTheNextReturnRunsTheCommand() async throws {
        try script("dictate", header: "title=Dictate\n\nbutton=dictate\ntitle=Dictate")
        await model.reload()
        model.isShown = true
        model.panelWillShow()

        model.query = "dictate"
        model.landSearch()
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "dictate" })
        XCTAssertEqual(model.hint, "⏎ Set key   ⌘⏎ Settings   ⌘K Actions")
        model.run(try entry("dictate"))

        XCTAssertEqual(model.recording, "key:dictate:dictate")
        try await wait("the key row") { model.openItems?.shown.contains { $0.run == "key:dictate:dictate" } == true }
        XCTAssertEqual(model.openSheetID, SpotSettings.sheetID(of: "dictate"))
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
        XCTAssertEqual(model.openSheetID, SpotSettings.sheetID(of: "dictate"))
        XCTAssertEqual(host.dismissals, 0)

        model.closeSheet(moving: false)
        model.query = "dictate"
        model.landSearch()
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "dictate" })
        try await wait("the key in the footer") { model.hint == "⏎ Dictate   ⌘⏎ Settings   ⌘K Actions" }
        XCTAssertTrue(model.openSelectedSettings())
        try await wait("the key row again") { model.openSheetID == SpotSettings.sheetID(of: "dictate") }
        XCTAssertNil(model.recording)
        model.closeSheet(moving: false)
        model.run(try entry("dictate"))

        try await wait("the command") { host.confirms == ["Ran dictate"] }
        XCTAssertNil(model.recording)
    }

    func testACommandWithConfirmAsksForASecondPressOfItsCard() async throws {
        try script("wipe", header: "title=Wipe\n\nbutton=wipe\ntitle=Wipe\nconfirm=Press again to wipe")
        _ = try model.files.config.change { $0.assign(.tap(.option), to: "wipe", act: .command("wipe")) }
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.query = "wipe"
        model.landSearch()
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "wipe" })

        model.run(try entry("wipe"))

        XCTAssertEqual(model.hint, "⏎ Press again to wipe   ⌘⏎ Settings   ⌘K Actions")
        XCTAssertEqual(host.dismissals, 0)
        model.run(try entry("wipe"))
        try await wait("the command") { host.confirms == ["Ran wipe"] }
        XCTAssertEqual(model.hint, "⏎ Wipe   ⌘⏎ Settings   ⌘K Actions")
    }

    func testAGlobalKeyOfACommandWithConfirmShowsItsCardAskingAndReturnRunsIt() async throws {
        try script("wipe", header: "title=Wipe\n\nbutton=wipe\ntitle=Wipe\nconfirm=Press again to wipe")
        try script("other", header: "title=Other\n\nbutton=other\ntitle=Other")
        _ = try model.files.config.change { $0.assign(.tap(.option), to: "wipe", act: .command("wipe")) }
        await model.reload()
        let key = try XCTUnwrap(model.assignedKeys.first { $0.spot == "wipe" })

        model.press(key)

        XCTAssertEqual(model.selectedEntry?.id, "wipe")
        XCTAssertEqual(model.hint, "⏎ Press again to wipe   ⌘⏎ Settings   ⌘K Actions")
        XCTAssertEqual(host.shows, 1)
        try await wait("the panel") { self.model.isShown }
        XCTAssertTrue(model.handleSearchKey(ActionKey(name: "return")))
        try await wait("the command") { self.host.confirms == ["Ran wipe"] }
        XCTAssertEqual(host.dismissals, 1)
    }

    func testACommandWithConfirmAsksForASecondPressInTheMenu() async throws {
        try script("wipe", header: "title=Wipe\non=sheet.open\n\nbutton=wipe\ntitle=Wipe\nconfirm=Press again to wipe\n\nbutton=keep\ntitle=Keep")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.query = "wipe"
        model.landSearch()
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "wipe" })

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        let menu = try XCTUnwrap(model.menu)

        XCTAssertEqual(menu.rows.first { $0.title == "Wipe" }?.action?.confirm, "Press again to wipe")
    }

    func testTheFooterOfASpotWithOneCommandAndNoSheetNamesWhatReturnDoes() async throws {
        try script("party", header: "title=Party\non=panel.open\n\nbutton=play\ntitle=Play")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.query = "party"
        model.landSearch()
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "party" })

        XCTAssertEqual(try entry("party").kind, .launch)
        XCTAssertFalse(model.hint.contains("Set key"), model.hint)
        model.run(try entry("party"))

        try await wait("the press of the card") { host.confirms.contains("Ran open") }
        XCTAssertNil(model.recording)
    }

    func testReturnOnASpotWithTwoCommandsOnlyOpensTheirKeys() async throws {
        try script("windows", header: "title=Windows\n\nbutton=left\ntitle=Left\n\nbutton=right\ntitle=Right")
        await model.reload()
        model.isShown = true
        model.panelWillShow()

        model.run(try entry("windows"))

        try await wait("the key rows") { model.openSheetID == SpotSettings.sheetID(of: "windows") }
        try await wait("their rows") { model.openItems?.shown.map(\.run) == ["key:windows:left", "key:windows:right", "menubar:windows"] }
        XCTAssertNil(model.recording)
    }

    func testReturnRunsTheOneCommandOfASpotWithRowsAndCommandYOpensTheRowsAsHistory() async throws {
        let lines = ["title=Dictate", "on=sheet.open", "on=app.update", "", "button=dictate", "title=Dictate"].map { $0.isEmpty ? "#" : "# \($0)" }
        try "#!/bin/sh\n\(lines.joined(separator: "\n"))\ncase \"$1\" in read) printf 'row=one\\ntitle=Hello there\\n\\nrow=two\\ntitle=Second\\n' ;; esac\n"
            .writeScript(to: spots.appendingPathComponent("dictate.sh"))
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.query = "dictate"
        model.landSearch()
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "dictate" })

        XCTAssertEqual(try entry("dictate").spot.soleCommand, "dictate")
        XCTAssertFalse(try entry("dictate").spot.opensOnReturn)
        XCTAssertEqual(model.hint, "⏎ Set key   ⌘⏎ Settings   ⌘K Actions")
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        let menu = try XCTUnwrap(model.menu)
        XCTAssertEqual(menu.rows.map(\.title), ["Dictate", "History"])
        XCTAssertEqual(menu.rows.first { $0.title == "History" }?.keyLabel, "⌘Y")
        model.closeMenu()

        XCTAssertTrue(model.handleKey(ActionKey(name: "y", isCommand: true)))
        try await wait("its History with a search typed") { model.openSheetID == "dictate" }
        model.closeSheet(moving: false)

        model.run(.history, on: SpotsModel.Target(entry: try entry("dictate"), item: nil))
        try await wait("its own rows") { model.openItems?.shown.map(\.run) == ["one", "two"] }
        XCTAssertEqual(model.openSheetID, "dictate")
        model.closeSheet(moving: false)

        model.runSelected()
        try await wait("its settings, recording its key") {
            model.recording == SpotSettings.keyRun(spot: "dictate", command: "dictate") && model.openSheetID == SpotSettings.sheetID(of: "dictate")
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
        await model.reload()
        model.isShown = true
        model.panelWillShow()
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
        await model.reload()
        model.isShown = true
        model.panelWillShow()

        model.run(.history, on: SpotsModel.Target(entry: try entry("dictate"), item: nil))

        try await wait("the rows") { model.openItems?.shown.count == 1 }
        XCTAssertEqual(model.openItems?.shown.map(\.run), ["whisper"])
        XCTAssertEqual(model.openItems?.search, .off)
        XCTAssertEqual(model.sheets["dictate"]?.shape.hasField, false)
    }

    func testAClickOnTheMenuBarIconOfASpotThatReturnRunsDoesWhatReturnDoes() async throws {
        let lines = ["title=Pen", "icon=pencil.tip", "", "button=draw", "title=Draw on screen"].map { $0.isEmpty ? "#" : "# \($0)" }
        try "#!/bin/sh\n\(lines.joined(separator: "\n"))\nexit 0\n".writeScript(to: spots.appendingPathComponent("pen.sh"))
        await model.reload()

        model.openFromMenuBar("pen")

        try await wait("its key, as the first Return records it") {
            model.recording == SpotSettings.keyRun(spot: "pen", command: "draw") && model.openSheetID == SpotSettings.sheetID(of: "pen")
        }
        XCTAssertGreaterThan(host.shows, 0)
    }

    func testAnOpenKeyOfASpotWithOneCommandRecordsItsKeyAndThenRunsTheCommand() async throws {
        try script("dictate", header: "title=Dictate\n\nbutton=dictate\ntitle=Dictate")
        await model.reload()
        let open = GlobalKey(spot: "dictate", act: .open, trigger: .key(try XCTUnwrap(Shortcut(text: "ctrl+option+d"))))

        model.press(open)
        XCTAssertEqual(host.shows, 1)
        XCTAssertEqual(model.recording, "key:dictate:dictate")
        model.stopRecording()
        _ = try model.files.config.change { $0.assign(.tap(.option), to: "dictate", act: .command("dictate")) }
        await model.reload()
        model.press(open)

        XCTAssertEqual(host.shows, 1)
        try await wait("the command") { host.confirms == ["Ran dictate"] }
    }
}
