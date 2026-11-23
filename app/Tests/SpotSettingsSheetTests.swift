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

    private func script(_ name: String, toml: String) throws {
        try "#!/bin/sh\necho \"$*\" >> '\(log.path)'\n[ \"$1\" = show ] && printf 'item=own\\ntitle=Own\\n'\nexit 0\n".writeScript(to: spots.spotFile(name), toml: toml)
    }

    private func show(selecting id: String, search: String = "") async throws {
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.query = search
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == id })
    }

    func testCommandReturnOpensTheSettingsOfAListSpotFromItsCardAndNotItsOwnSheet() async throws {
        try script("draw", toml: "title = 'Draw'")
        try await show(selecting: "draw")
        let settings = SpotSettings.sheetID(of: "draw")

        XCTAssertEqual(model.hint, "⏎ Open   ⌘⏎ Settings")
        XCTAssertTrue(model.handleKey(ActionKey(name: "return", isCommand: true)))

        try await wait("the Settings sheet") { model.openSheetID == settings }
        try await wait("its rows") { model.openItems?.shown.map(\.run) == ["key:draw:open", "key:draw:float", "menubar:draw", "window:draw"] }
        XCTAssertEqual(model.openEntry?.id, settings)
        XCTAssertEqual(model.openEntry?.state.title, "Draw Settings")
        XCTAssertEqual(SpotSheetCard.of(model.openSheetID, in: model)?.id, "draw")
        XCTAssertFalse(calls.contains("show"))

        XCTAssertTrue(model.handleKey(ActionKey(name: "escape")))
        XCTAssertNil(model.openSheetID)
        model.runSelected()
        try await wait("its own sheet") { model.openItems?.shown.map(\.run) == ["own"] }
        XCTAssertEqual(model.openSheetID, "draw")
    }

    func testTheSettingsActOfACardOpensItsSettingsSheet() async throws {
        try script("draw", toml: "title = 'Draw'")
        try await show(selecting: "draw")

        XCTAssertTrue(model.act(.settings, on: "draw"))

        try await wait("the Settings sheet") { model.openSheetID == SpotSettings.sheetID(of: "draw") }
        XCTAssertNil(model.menu)
    }

    func testACardWithNothingElseToSetHasSettingsWithItsPlaceInTheMenuBarAndEachValueItKeeps() async throws {
        try script("quit", toml: "title = 'Quit'")
        try script("lock", toml: "title = 'Lock'")
        try model.files.config.set(setting: "theme", of: "lock", to: "dark")
        try await show(selecting: "quit")

        XCTAssertEqual(model.hint, "⏎ Open   ⌘⏎ Settings")
        XCTAssertFalse(model.handleKey(ActionKey(name: "k", isCommand: true)))
        XCTAssertNil(model.menu)
        XCTAssertTrue(model.handleKey(ActionKey(name: "return", isCommand: true)))
        try await wait("its place in the menu bar") { model.openItems?.shown.map(\.run) == ["key:quit:open", "key:quit:float", "menubar:quit", "window:quit"] }
        XCTAssertEqual(model.openSheetID, SpotSettings.sheetID(of: "quit"))
        model.closeSheet(moving: false)

        try await show(selecting: "lock")
        XCTAssertTrue(model.openSelectedSettings())
        try await wait("the value") { model.openItems?.shown.map(\.run) == ["key:lock:open", "key:lock:float", "setting:lock:theme", "menubar:lock", "window:lock"] }
        XCTAssertEqual(model.openItems?.shown.first { $0.run == "setting:lock:theme" }?.subtitle, "dark")
        XCTAssertEqual(calls, [])
    }

    func testTheLookRowOfConfettiShowsTheKeptLookAndAsksForEachLook() async throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        try FileManager.default.copyItem(at: repo.appendingPathComponent("spots/confetti.spot"), to: spots.appendingPathComponent("confetti.spot"))
        try model.files.config.set(setting: "look", of: "confetti", to: "Gold")
        try await show(selecting: "confetti", search: "confetti")

        XCTAssertTrue(model.openSelectedSettings())
        try await wait("the look row") { model.openItems?.shown.contains { $0.run == "setting:confetti:look" } == true }
        let row = try XCTUnwrap(model.openItems?.shown.first { $0.run == "setting:confetti:look" })
        XCTAssertEqual(row.title, "Look")
        XCTAssertEqual(row.subtitle, "Gold")
        model.runItem(row)

        try await wait("the looks", seconds: 600) { model.form?.draft.form.soleChoice != nil }
        XCTAssertEqual(model.form?.draft.form.soleChoice?.options.map(\.id), ["colorful", "gold", "metallic"])
        XCTAssertEqual(model.form?.draft.form.soleChoice?.value, "gold")
    }

    func testReturnOnAFieldRunsTheActionOfItsNameAndTheMenuBarRowTurnsItsPlaceOnAndOff() async throws {
        try script("cups", toml: "title = 'Cups'\n[settings]\nsize = { type = 'text' }\n[on]\n\"sheet.open\" = true\nevery = 60")
        try await show(selecting: "cups", search: "cups")
        XCTAssertTrue(model.openSelectedSettings())
        try await wait("the rows") { model.openItems?.shown.map(\.run) == ["key:cups:open", "key:cups:float", "setting:cups:size", "menubar:cups", "window:cups"] }

        model.moveItemToEdge(last: true)
        model.moveItem(by: -1)
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
