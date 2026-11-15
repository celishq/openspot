import XCTest
@testable import OpenspotCore

@MainActor
final class FailureFixTests: SpotRunsCase {
    private struct Refusing: MacWindows {
        func frame() async throws -> WindowFrame {
            throw SpotError.failed(1, "No window.")
        }

        func move(_ move: WindowMove) async throws {
            throw SpotError.failedWithFix(1, "Openspot cannot move the window. Allow it in Accessibility, then press the key again.", URL(string: "x-apple.systempreferences:accessibility")!)
        }
    }

    private var config: URL!
    private var client: URL!
    private var socket: CommandSocket?
    private var told: [(text: String, fix: URL?)] = []

    override func setUp() async throws {
        try await super.setUp()
        config = FileManager.default.temporaryDirectory.appendingPathComponent("of-\(UUID().uuidString.prefix(8))", isDirectory: true)
        client = folder.appendingPathComponent("A.app/Contents/Helpers/openspot")
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: client)
        let api = CommandAPI(mac: Mac(windows: Refusing()), places: .test(["OPENSPOT_CONFIG": config.path]), app: FakeRunningApp(), runs: runs, rates: .offline)
        runs.api = api
        socket = try XCTUnwrap(CommandSocket(folder: config, api: api))
        runs.onReport = { [unowned self] _, report in
            switch report {
            case .failure(let text): told.append((text, nil))
            case .failureWithFix(let text, let fix): told.append((text, fix))
            default: break
            }
        }
    }

    override func tearDown() async throws {
        socket?.close()
        try? FileManager.default.removeItem(at: config)
        try await super.tearDown()
    }

    private func openspot(_ words: String) -> String {
        "OPENSPOT_CONFIG='\(config.path)' '\(client.path)' \(words)"
    }

    func testTheFixOfACallThatTheSpotMadeAndThatFailedJoinsTheFailureOfTheSpot() async throws {
        try script(header: "uses=screen", "\(openspot("window move 0 0 1 1")) > /dev/null || exit 1")
        _ = try scanned()

        try XCTUnwrap(runs.sheets["script"]).pressCard()

        try await wait("the failure") { !self.told.isEmpty }
        XCTAssertEqual(told.first?.text, "Openspot cannot move the window. Allow it in Accessibility, then press the key again.")
        XCTAssertEqual(told.first?.fix?.absoluteString, "x-apple.systempreferences:accessibility")
    }

    func testAFailureAfterALaterCallThatWorkedHasNoFix() async throws {
        try script(header: "uses=screen", "\(openspot("window move 0 0 1 1")) > /dev/null\n\(openspot("help")) > /dev/null\necho 'It broke.' >&2\nexit 1")
        _ = try scanned()

        try XCTUnwrap(runs.sheets["script"]).pressCard()

        try await wait("the failure") { !self.told.isEmpty }
        XCTAssertEqual(told.first?.text, "It broke.")
        XCTAssertNil(told.first?.fix)
    }
}
