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
        try await wait("the welcome sheet") { self.model.openSheetID == Self.welcome && self.keyField != nil }
        try await wait("the recording") { self.model.recording == "key" }
    }

    func testEscWhileItRecordsKeepsTheKeyAndShowsTheGrid() async throws {
        try await launch()

        XCTAssertTrue(model.handleKey(ActionKey(name: "escape")))

        try await wait("the end of keep") { self.hasEnded }
        try await wait("the grid") { self.model.openSheetID == nil }
        XCTAssertNil(model.recording)
        XCTAssertEqual(model.files.config.read().panelKey, .standard)
    }

    func testReturnSavesTheRecordedKeyShowsTheGridAndTheToastNamesIt() async throws {
        let key = try XCTUnwrap(Shortcut(text: "option+space"))
        try await launch()
        model.record(code: 49, modifiers: .option)
        try await wait("the kept key") { self.hasEnded }
        XCTAssertEqual(keyField?.value, "option+space")

        XCTAssertTrue(model.handleKey(ActionKey(name: "return")))

        try await wait("the end of use") { self.hasEnded }
        try await wait("the grid") { self.model.openSheetID == nil }
        XCTAssertEqual(model.files.config.read().panelKey, key)
        host.dismiss()
        XCTAssertEqual(host.confirms.last, key.openHint)
    }

    func testEscAfterAKeyEmptiesTheFieldAndRecordsAgain() async throws {
        try await launch()
        model.record(code: 49, modifiers: .option)
        try await wait("the kept key") { self.hasEnded }
        XCTAssertNil(model.recording)

        XCTAssertTrue(model.handleKey(ActionKey(name: "escape")))

        try await wait("the empty field") { self.keyField?.value == "" }
        try await wait("the recording again") { self.model.recording == "key" }
        XCTAssertEqual(model.openSheetID, Self.welcome)
    }
}
