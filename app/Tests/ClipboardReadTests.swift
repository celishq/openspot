import XCTest
@testable import OpenspotCore

@MainActor
final class ClipboardReadTests: XCTestCase {
    private let clock = FakeClock()
    private let board = FakeClipboard()
    private var folder: URL!
    private var runs: SpotRuns!
    private var api: CommandAPI!

    override func setUp() async throws {
        folder = try temporaryFolder()
        runs = SpotRuns(clock: clock.value)
        runs.listen(to: board)
        api = CommandAPI(mac: Mac(clipboard: board), places: .test(["OPENSPOT_CONFIG": folder.path]), runs: runs)
    }

    private func call(_ arguments: [String]) async throws -> CommandAnswer {
        let request = CommandRequest(arguments: ["clipboard", "read"] + arguments, folder: folder.path)
        let work = try XCTUnwrap(api.work(for: try XCTUnwrap(api.call(of: request)), request: request, input: { "" }))
        return await work()
    }

    func testNewerPrintsACopyOnlyUntilItIsOlderThanTheSecondsSinceOpenspotFirstSawIt() async throws {
        board.copy("https://a.com/x\n")
        let fresh = try await call(["--newer", "120"])
        clock.advance(by: 119)
        let late = try await call(["--newer", "120"])
        clock.advance(by: 1)
        let old = try await call(["--newer", "120"])
        let plain = try await call([])
        board.copy("two\nlines")
        let next = try await call(["--newer", "120"])

        XCTAssertEqual([fresh.output, late.output, old.output, plain.output, next.output], ["https://a.com/x\n", "https://a.com/x\n", "", "https://a.com/x\n", "two\nlines"])
        XCTAssertEqual([fresh.code, old.code], [0, 0])
    }

    func testNewerTakesOnlyAWholeNumberOfSecondsAboveZero() {
        for words in [["--newer"], ["--newer", "0"], ["--newer", "soon"], ["--newer", "5", "x"]] {
            XCTAssertNil(CommandLineCall(arguments: ["clipboard", "read"] + words)?.value as? ClipboardCall, words.joined(separator: " "))
        }
        XCTAssertEqual(CommandLineCall(arguments: ["clipboard", "read", "--newer", "120"])?.value as? ClipboardCall, .read(newer: 120))
    }
}
