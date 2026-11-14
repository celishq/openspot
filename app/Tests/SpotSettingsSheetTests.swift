import XCTest
@testable import OpenspotCore

/// Proves where a person reaches a spot's Settings: ⌘ Return on its card and the Settings row of its actions menu open the
/// sheet that holds them, and the footer names the key.
@MainActor
final class SpotSettingsSheetTests: XCTestCase {
    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: TestHost!
    private var model: SpotsModel!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-settings-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        suite = "openspot-settings-\(UUID().uuidString)"
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

    private var log: URL {
        folder.appendingPathComponent("calls")
    }

    /// The calls that the scripts logged, each as its words.
    private var calls: [String] {
        ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    /// Writes a script that logs each call and prints one row on a read.
    private func script(_ name: String, header: String) throws {
        let lines = header.split(separator: "\n", omittingEmptySubsequences: false).map { $0.isEmpty ? "#" : "# \($0)" }.joined(separator: "\n")
        try "#!/bin/sh\n\(lines)\necho \"$*\" >> '\(log.path)'\n[ \"$1\" = read ] && printf 'row=own\\ntitle=Own\\n'\nexit 0\n".writeScript(to: spots.spotFile(name))
    }

    private func wait(_ what: String, until condition: () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited for \(what)")
    }

    /// Shows the panel with the card of a spot selected, which a search finds when the grid does not show it.
    private func show(selecting id: String, search: String = "") throws {
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.query = search
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == id })
    }

    func testCommandReturnOpensTheSettingsOfAListSpotFromItsCardAndNotItsOwnSheet() async throws {
        try script("draw", header: "title=Draw\non=sheet.open")
        try show(selecting: "draw")
        let settings = SpotSettings.sheetID(of: "draw")

        XCTAssertEqual(model.hint, "⏎ Open   ⌘⏎ Settings   ⌘K Actions")
        XCTAssertTrue(model.handleKey(ActionKey(name: "return", isCommand: true)))

        try await wait("the Settings sheet") { model.openList == settings }
        try await wait("its rows") { model.openItems?.shown.map(\.run) == ["float:draw", "menubar:draw"] }
        XCTAssertEqual(model.openEntry?.id, settings)
        XCTAssertEqual(model.openEntry?.state.title, "Draw Settings")
        XCTAssertEqual(SpotSheetCard.of(model.openList, in: model)?.id, "draw")
        XCTAssertFalse(calls.contains("read"))

        model.runSelectedItem()
        XCTAssertEqual(model.recording, "float:draw")
        model.record(code: 1, modifiers: [.control, .option])
        try await wait("the key in the file") { model.files.config.read().keys.map(\.act) == [.float] }
        try await wait("the key in its row") { model.openItems?.shown.first?.shortcut == "ctrl+option+s" }
        XCTAssertEqual(model.openList, settings)
        XCTAssertEqual(host.dismissals, 0)

        XCTAssertTrue(model.handleKey(ActionKey(name: "escape")))
        XCTAssertNil(model.openList)
        model.runSelected()
        try await wait("its own sheet") { model.openItems?.shown.map(\.run) == ["own"] }
        XCTAssertEqual(model.openList, "draw")
    }

    func testASpotWhoseReturnRunsItKeepsItsSettingsApartFromItsOwnSheet() async throws {
        try script("conf", header: "title=Confetti\non=sheet.open\npress=open")
        try show(selecting: "conf")

        XCTAssertEqual(model.hint, "⏎ Run   ⌘⏎ Settings   ⌘K Actions")
        XCTAssertTrue(model.openSelectedSettings())
        try await wait("its settings") { model.openItems?.shown.map(\.run) == ["float:conf", "menubar:conf"] }
        XCTAssertEqual(model.openList, SpotSettings.sheetID(of: "conf"))
        model.closeList(moving: false)

        model.open("conf", moving: false)
        try await wait("its own rows") { model.openItems?.shown.map(\.run) == ["own"] }
        XCTAssertFalse(calls.contains("open"))
    }

    func testAHotkeyFieldIsRecordedInTheSettingsAndGoesToTheSpotsActionOfItsName() async throws {
        try script("conf", header: "title=Confetti\non=sheet.open\npress=open\n\nfield=key\ntype=hotkey\ntitle=Shortcut")
        try model.files.config.set(setting: "key", of: "conf", to: "option+c")
        try show(selecting: "conf")
        XCTAssertTrue(model.openSelectedSettings())
        try await wait("its settings") { model.openItems?.shown.map(\.run) == ["setting:conf:key", "float:conf", "menubar:conf"] }
        let row = try XCTUnwrap(model.openItems?.shown.first)
        XCTAssertTrue(row.records)
        XCTAssertFalse(row.takesShake)
        XCTAssertEqual(row.shortcut, "option+c")

        model.moveItemToEdge(last: false)
        model.runSelectedItem()
        XCTAssertEqual(model.recording, "setting:conf:key")
        model.record(code: 1, modifiers: [.control, .option])

        try await wait("the action of the field") { calls.contains("key ctrl+option+s") }
        XCTAssertEqual(model.openList, SpotSettings.sheetID(of: "conf"))
        XCTAssertEqual(host.dismissals, 0)
    }

    func testRemoveOnAHotkeyFieldGoesToTheSpotsActionOfItsNameWithNoKeyAndTheSheetHasNoActionsMenu() async throws {
        try script("conf", header: "title=Confetti\non=sheet.open\n\nfield=key\ntype=hotkey\ntitle=Shortcut")
        try model.files.config.set(setting: "key", of: "conf", to: "option+c")
        try show(selecting: "conf")
        XCTAssertTrue(model.openSelectedSettings())
        try await wait("its settings") { model.openItems?.shown.map(\.run) == ["setting:conf:key", "float:conf", "menubar:conf"] }
        model.moveItemToEdge(last: false)

        XCTAssertEqual(model.hint, "⏎ Change   ⌘⌫ Remove")
        XCTAssertFalse(model.handleKey(ActionKey(name: "k", isCommand: true)))
        XCTAssertNil(model.menu)
        XCTAssertTrue(model.handleKey(ActionKey(name: "backspace", isCommand: true)))

        try await wait("the action of the field with no key") { calls.contains("key ") }
        XCTAssertEqual(model.openList, SpotSettings.sheetID(of: "conf"))
    }

    func testTheActionsMenuListsSettingsWithItsKeyAndOpensThem() async throws {
        try script("draw", header: "title=Draw\non=sheet.open")
        try show(selecting: "draw")

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        let menu = try XCTUnwrap(model.menu)
        let row = try XCTUnwrap(menu.rows.firstIndex { $0.title == "Settings" })
        XCTAssertEqual(menu.rows[row].keyLabel, "⌘⏎")
        XCTAssertEqual(menu.rows.map(\.title).first, "Open")
        model.pressMenu(row: row)

        try await wait("the Settings sheet") { model.openList == SpotSettings.sheetID(of: "draw") }
        XCTAssertNil(model.menu)
    }

    func testACardWithNothingElseToSetHasSettingsWithItsPlaceInTheMenuBarAndEachValueItKeeps() async throws {
        try script("quit", header: "title=Quit")
        try script("lock", header: "title=Lock")
        try model.files.config.set(setting: "theme", of: "lock", to: "dark")
        try show(selecting: "quit")

        XCTAssertEqual(model.hint, "⏎ Run   ⌘⏎ Settings   ⌘K Actions")
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        XCTAssertEqual(model.menu?.rows.filter { $0.action != nil }.map(\.title), ["Share", "Settings", "Delete"])
        model.closeMenu()
        XCTAssertTrue(model.handleKey(ActionKey(name: "return", isCommand: true)))
        try await wait("its place in the menu bar") { model.openItems?.shown.map(\.run) == ["menubar:quit"] }
        XCTAssertEqual(model.openList, SpotSettings.sheetID(of: "quit"))
        model.closeList(moving: false)

        try show(selecting: "lock")
        XCTAssertTrue(model.openSelectedSettings())
        try await wait("the value") { model.openItems?.shown.map(\.run) == ["setting:lock:theme", "menubar:lock"] }
        XCTAssertEqual(model.openItems?.shown.first?.subtitle, "dark")
        XCTAssertEqual(calls, [])
    }

    func testReturnOnAFieldRunsTheActionOfItsNameAndTheMenuBarRowTurnsItsPlaceOnAndOff() async throws {
        try script("cups", header: "title=Cups\non=sheet.open\non=clock.60\n\nfield=size")
        try show(selecting: "cups", search: "cups")
        XCTAssertTrue(model.openSelectedSettings())
        try await wait("the rows") { model.openItems?.shown.map(\.run) == ["setting:cups:size", "float:cups", "menubar:cups"] }

        model.moveItemToEdge(last: true)
        model.runSelectedItem()
        try await wait("the menu bar in the file") { model.files.config.read().arrangement.menuBar == ["cups"] }
        try await wait("the switch") { model.openItems?.shown.first { $0.run == "menubar:cups" }?.isOn == true }
        XCTAssertEqual(model.openList, SpotSettings.sheetID(of: "cups"))

        model.moveItemToEdge(last: false)
        model.runSelectedItem()
        try await wait("the action of the field") { calls.contains("size") }
    }
}
