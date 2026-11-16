import XCTest
@testable import OpenspotCore

@MainActor
final class SpotSettingsSheetTests: XCTestCase {
    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: FakeHost!
    private var model: SpotsModel!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-settings-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        suite = "openspot-settings-\(UUID().uuidString)"
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

    private var log: URL {
        folder.appendingPathComponent("calls")
    }

    private var calls: [String] {
        ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    private func script(_ name: String, header: String) throws {
        let lines = header.split(separator: "\n", omittingEmptySubsequences: false).map { $0.isEmpty ? "#" : "# \($0)" }.joined(separator: "\n")
        try "#!/bin/sh\n\(lines)\necho \"$*\" >> '\(log.path)'\n[ \"$1\" = read ] && printf 'row=own\\ntitle=Own\\n'\nexit 0\n".writeScript(to: spots.spotFile(name))
    }

    private func show(selecting id: String, search: String = "") async throws {
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.query = search
        model.landSearch()
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == id })
    }

    func testCommandReturnOpensTheSettingsOfAListSpotFromItsCardAndNotItsOwnSheet() async throws {
        try script("draw", header: "title=Draw\non=sheet.open\noffers=card\noffers=float")
        try await show(selecting: "draw")
        let settings = SpotSettings.sheetID(of: "draw")

        XCTAssertEqual(model.hint, "⏎ Open   ⌘⏎ Settings")
        XCTAssertTrue(model.handleKey(ActionKey(name: "return", isCommand: true)))

        try await wait("the Settings sheet") { model.openSheetID == settings }
        try await wait("its rows") { model.openItems?.shown.map(\.run) == ["key:draw:open", "key:draw:float", "menubar:draw"] }
        XCTAssertEqual(model.openEntry?.id, settings)
        XCTAssertEqual(model.openEntry?.state.title, "Draw Settings")
        XCTAssertEqual(SpotSheetCard.of(model.openSheetID, in: model)?.id, "draw")
        XCTAssertFalse(calls.contains("read"))

        XCTAssertTrue(model.handleKey(ActionKey(name: "escape")))
        XCTAssertNil(model.openSheetID)
        model.runSelected()
        try await wait("its own sheet") { model.openItems?.shown.map(\.run) == ["own"] }
        XCTAssertEqual(model.openSheetID, "draw")
    }

    func testASpotWhoseReturnRunsItKeepsItsSettingsApartFromItsOwnSheet() async throws {
        try script("conf", header: "title=Confetti\non=sheet.open\npress=open\noffers=card\noffers=float")
        try await show(selecting: "conf")

        XCTAssertEqual(model.hint, "⏎ Run   ⌘⏎ Settings   ⌘K Actions")
        XCTAssertTrue(model.openSelectedSettings())
        try await wait("its settings") { model.openItems?.shown.map(\.run) == ["key:conf:open", "key:conf:float", "menubar:conf"] }
        XCTAssertEqual(model.openSheetID, SpotSettings.sheetID(of: "conf"))
        model.closeSheet(moving: false)

        model.pushFirst("conf", moving: false)
        try await wait("its own rows") { model.openItems?.shown.map(\.run) == ["own"] }
        XCTAssertFalse(calls.contains("open"))
    }

    func testTheSettingsActOfACardOpensItsSettingsSheet() async throws {
        try script("draw", header: "title=Draw\non=sheet.open")
        try await show(selecting: "draw")

        XCTAssertTrue(model.act(.settings, on: "draw"))

        try await wait("the Settings sheet") { model.openSheetID == SpotSettings.sheetID(of: "draw") }
        XCTAssertNil(model.menu)
    }

    func testACardWithNothingElseToSetHasSettingsWithItsPlaceInTheMenuBarAndEachValueItKeeps() async throws {
        try script("quit", header: "title=Quit")
        try script("lock", header: "title=Lock")
        try model.files.config.set(setting: "theme", of: "lock", to: "dark")
        try await show(selecting: "quit")

        XCTAssertEqual(model.hint, "⏎ Run   ⌘⏎ Settings")
        XCTAssertFalse(model.handleKey(ActionKey(name: "k", isCommand: true)))
        XCTAssertNil(model.menu)
        XCTAssertTrue(model.handleKey(ActionKey(name: "return", isCommand: true)))
        try await wait("its place in the menu bar") { model.openItems?.shown.map(\.run) == ["key:quit:open", "menubar:quit"] }
        XCTAssertEqual(model.openSheetID, SpotSettings.sheetID(of: "quit"))
        model.closeSheet(moving: false)

        try await show(selecting: "lock")
        XCTAssertTrue(model.openSelectedSettings())
        try await wait("the value") { model.openItems?.shown.map(\.run) == ["key:lock:open", "setting:lock:theme", "menubar:lock"] }
        XCTAssertEqual(model.openItems?.shown.first { $0.run == "setting:lock:theme" }?.subtitle, "dark")
        XCTAssertEqual(calls, [])
    }

    func testReturnOnAFieldRunsTheActionOfItsNameAndTheMenuBarRowTurnsItsPlaceOnAndOff() async throws {
        try script("cups", header: "title=Cups\non=sheet.open\non=clock.60\noffers=card\noffers=float\n\nfield=size")
        try await show(selecting: "cups", search: "cups")
        XCTAssertTrue(model.openSelectedSettings())
        try await wait("the rows") { model.openItems?.shown.map(\.run) == ["key:cups:open", "key:cups:float", "setting:cups:size", "menubar:cups"] }

        model.moveItemToEdge(last: true)
        model.runSelectedItem()
        try await wait("the menu bar in the file") { model.files.config.read().arrangement.menuBar == ["cups"] }
        try await wait("the switch") { model.openItems?.shown.first { $0.run == "menubar:cups" }?.isOn == true }
        XCTAssertEqual(model.openSheetID, SpotSettings.sheetID(of: "cups"))

        model.moveItemToEdge(last: false)
        model.moveItem(by: 2)
        model.runSelectedItem()
        try await wait("the action of the field") { calls.contains("size") }
    }
}
