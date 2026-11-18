import XCTest
@testable import OpenspotCore

@MainActor
final class WelcomeLaunchTests: XCTestCase {
    private static let welcome = "openspot/welcome"

    private var root: URL!
    private var suite = ""
    private var host: FakeHost!
    private var model: SpotsModel!
    private var socket: CommandSocket?

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("wl-\(UUID().uuidString.prefix(8))")
        let spots = root.appendingPathComponent("spots", isDirectory: true)
        let core = root.appendingPathComponent("core", isDirectory: true)
        let tools = root.appendingPathComponent("tools", isDirectory: true)
        let config = root.appendingPathComponent("config", isDirectory: true)
        for folder in [spots, core.appendingPathComponent("openspot.spot"), tools, config] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        try FileManager.default.createSymbolicLink(at: core.spotFile(Self.welcome), withDestinationURL: repoSpots.spotFile(Self.welcome))
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: tools.appendingPathComponent("openspot"))
        let environment = ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": config.path, "OPENSPOT_CORE": core.path]
        suite = "openspot-welcome-\(UUID().uuidString)"
        let files = AppPlaces(environment: environment, home: root, defaults: try XCTUnwrap(UserDefaults(suiteName: suite)))
        let base = ProcessInfo.processInfo.environment.merging(environment.merging(["PATH": "\(tools.path):/usr/bin:/bin"]) { _, new in new }) { _, new in new }
        host = FakeHost()
        model = SpotsModel(host: host, files: files, runs: SpotRuns(environment: base, stopPause: 0.2))
        host.model = model
        socket = CommandSocket(folder: config, api: CommandAPI(mac: Mac(), places: files, app: ModelApp(model: model), runs: model.runs, rates: .offline))
    }

    override func tearDown() async throws {
        socket?.close()
        model.quit()
        UserDefaults().removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }

    private var repoSpots: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("spots")
    }

    private var keyField: SpotPart? {
        model.openParts?.parts.first { $0.id == "key" }
    }

    private var hasEnded: Bool {
        model.sheets[Self.welcome]?.calls.isEmpty == true
    }

    private var focus: String? {
        model.openParts?.selectedPart?.id
    }

    private var shownPages: [String?] {
        model.flow.pages.map(\.page)
    }

    private func launch() async throws {
        await model.beginFirstLaunch()
        try await wait("the welcome") { self.model.openSheetID == Self.welcome && self.model.openParts?.parts.first { $0.id == "head" }?.title == "Everything is a disposable spot" }
        try await wait("the focus on continue") { self.focus == "next" }
    }

    private func toKeyPage() async throws {
        XCTAssertTrue(press("return"))
        try await wait("the key page") { self.keyField?.value == "ctrl+space" && self.focus == "use" && self.shownPages == [nil, "key"] }
    }

    private func toLastPage() async throws {
        XCTAssertTrue(press("return"))
        try await wait("the last page") { self.hasEnded && self.model.openParts?.parts.contains { $0.id == "done" } == true }
    }

    private func recordOptionSpace() async throws {
        XCTAssertTrue(press("escape"))
        try await wait("the recording") { self.model.recording == "key" }
        model.record(code: 49, modifiers: .option)
        try await wait("the kept key") { self.hasEnded && self.keyField?.value == "option+space" }
    }

    private func press(_ name: String) -> Bool {
        model.handleKey(ActionKey(name: name))
    }

    func testThreeReturnsWalkThePagesToTheGridAndKeepTheKey() async throws {
        try await launch()
        try await toKeyPage()
        try await toLastPage()

        XCTAssertEqual(shownPages, [nil, "key", "agent"])
        XCTAssertEqual(model.flow.pages.dropLast().map { model.title(of: $0) }, ["Welcome spot", "Choose your key"])
        XCTAssertTrue(press("return"))

        try await wait("the grid") { self.model.openSheetID == nil }
        XCTAssertEqual(model.files.config.read().panelKey, .standard)
    }

    func testEscOnTheWelcomeShowsTheGridAndKeepsTheKey() async throws {
        try await launch()

        XCTAssertTrue(press("escape"))

        try await wait("the grid") { self.model.openSheetID == nil }
        XCTAssertEqual(model.files.config.read().panelKey, .standard)
    }

    func testEscRecordsAndEscAgainStopsWithTheKeyKept() async throws {
        try await launch()
        try await toKeyPage()

        XCTAssertTrue(press("escape"))
        try await wait("the recording") { self.model.recording == "key" }
        XCTAssertEqual(model.hint, "Esc Cancel")
        XCTAssertTrue(press("escape"))

        XCTAssertNil(model.recording)
        XCTAssertEqual(model.flow.index, 1)
        XCTAssertEqual(keyField?.value, "ctrl+space")
        XCTAssertEqual(model.files.config.read().panelKey, .standard)
    }

    func testANewKeyIsSavedByReturnAndTheToastNamesIt() async throws {
        let key = try XCTUnwrap(Shortcut(text: "option+space"))
        try await launch()
        try await toKeyPage()
        try await recordOptionSpace()
        XCTAssertEqual(focus, "use")

        try await toLastPage()
        XCTAssertEqual(model.files.config.read().panelKey, key)
        XCTAssertTrue(press("return"))

        try await wait("the grid") { self.model.openSheetID == nil && self.host.confirms.last == key.openHint }
    }

    func testTheArrowsReachRecordAndSpacePressesIt() async throws {
        try await launch()
        try await toKeyPage()

        XCTAssertTrue(press("down"))
        XCTAssertEqual(focus, "record")
        XCTAssertTrue(press(" "))

        try await wait("the recording") { self.model.recording == "key" }
    }

    func testBackFromTheLastPageShowsTheSavedKeyAndReturnComesBack() async throws {
        try await launch()
        try await toKeyPage()
        try await recordOptionSpace()
        try await toLastPage()

        XCTAssertTrue(model.handleKey(ActionKey(name: "[", isCommand: true)))

        try await wait("the key page again") { self.hasEnded && self.keyField?.value == "option+space" && self.model.flow.index == 1 }
        XCTAssertTrue(press("return"))
        try await wait("the last page again") { self.hasEnded && self.model.openParts?.parts.contains { $0.id == "done" } == true }
        XCTAssertEqual(shownPages, [nil, "key", "agent"])
    }

    func testEscOnTheLastPageGoesBackToTheKeyPage() async throws {
        try await launch()
        try await toKeyPage()
        try await toLastPage()

        XCTAssertTrue(press("escape"))

        try await wait("the key page again") { self.model.flow.index == 1 && self.focus == "use" }
        XCTAssertEqual(model.openSheetID, Self.welcome)
    }

    func testClosingThePanelBeforeUseKeepsTheOldKey() async throws {
        try await launch()
        try await toKeyPage()
        try await recordOptionSpace()

        host.dismiss()

        XCTAssertEqual(model.files.config.read().panelKey, .standard)
    }

    private func nextTurn() async {
        await withCheckedContinuation { done in DispatchQueue.main.async { done.resume() } }
    }
}
