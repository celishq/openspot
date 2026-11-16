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

    private func launch() async throws {
        await model.beginFirstLaunch()
        try await wait("the welcome sheet") { self.model.openSheetID == Self.welcome && self.keyField?.value == "ctrl+space" }
        try await wait("the focus on use") { self.model.openParts?.selectedPart?.id == "use" }
    }

    private func press(_ name: String) -> Bool {
        model.handleKey(ActionKey(name: name))
    }

    func testTheFirstLaunchShowsTheKeyThatOpensOpenspotChosenAndReturnKeepsIt() async throws {
        try await launch()
        XCTAssertNil(model.recording)

        XCTAssertTrue(press("return"))

        try await wait("the end of use") { self.hasEnded }
        try await wait("the grid") { self.model.openSheetID == nil }
        XCTAssertEqual(model.files.config.read().panelKey, .standard)
    }

    func testEscRecordsAndEscAgainBringsTheKeyBack() async throws {
        try await launch()

        XCTAssertTrue(press("escape"))
        XCTAssertEqual(model.recording, "key")
        XCTAssertTrue(press("escape"))
        await nextTurn()

        XCTAssertNil(model.recording)
        XCTAssertEqual(keyField?.value, "ctrl+space")
        XCTAssertEqual(model.openSheetID, Self.welcome)
        XCTAssertEqual(model.openParts?.selectedPart?.id, "use")
    }

    func testANewKeyIsSavedByReturnAndTheToastNamesIt() async throws {
        let key = try XCTUnwrap(Shortcut(text: "option+space"))
        try await launch()
        XCTAssertTrue(press("escape"))
        model.record(code: 49, modifiers: .option)
        try await wait("the kept key") { self.hasEnded && self.keyField?.value == "option+space" }
        XCTAssertEqual(model.openParts?.selectedPart?.id, "use")

        XCTAssertTrue(press("return"))

        try await wait("the end of use") { self.hasEnded }
        try await wait("the grid") { self.model.openSheetID == nil }
        XCTAssertEqual(model.files.config.read().panelKey, key)
        host.dismiss()
        XCTAssertEqual(host.confirms.last, key.openHint)
    }

    func testTheArrowsReachRecordAndSpacePressesIt() async throws {
        try await launch()

        XCTAssertTrue(press("down"))
        XCTAssertEqual(model.openParts?.selectedPart?.id, "record")
        XCTAssertTrue(press(" "))

        XCTAssertEqual(model.recording, "key")
    }

    private func nextTurn() async {
        await withCheckedContinuation { done in DispatchQueue.main.async { done.resume() } }
    }
}
