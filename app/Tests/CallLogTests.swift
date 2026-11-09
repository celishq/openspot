import XCTest
@testable import OpenspotCore

/// Proves that the log keeps what each call of a spot got and gave, so that a person or an agent can see what happened.
@MainActor
final class CallLogTests: SpotRunsCase {
    private var log: CallLog!

    override func setUp() async throws {
        try await super.setUp()
        log = CallLog(folder: folder.appendingPathComponent("logs"))
        runs = SpotRuns(now: { [unowned self] in self.time }, stopPause: 0.2, tickPause: .milliseconds(50), log: log)
    }

    func testACallLeavesItsArgumentsItsInputItsFramesItsErrorsAndItsExit() async throws {
        try script(body: "cat > /dev/null; printf 'title=Half\\n---\\ntitle=Done\\n'; echo 'The server did not answer.' >&2; exit 3")
        let sheet = try sheet()

        sheet.run(CommandAction(id: "send", title: "Send"), item: SpotItem(title: "Home", run: "home"))
        try await wait("the record") { self.log.text(of: "script").contains("exit 3") }

        let text = log.text(of: "script")
        XCTAssertTrue(text.contains("send home"))
        XCTAssertTrue(text.contains("title=Half"))
        XCTAssertTrue(text.contains("title=Done"))
        XCTAssertTrue(text.contains("The server did not answer."))
    }

    func testTheLogOfOneSpotHoldsNoCallOfAnother() async throws {
        try script("one", "echo one")
        try script("two", "echo two")
        _ = try scanned()

        runs.sheets["one"]?.pressCard()
        try await wait("the record of one") { self.log.text(of: "one").contains("exit 0") }

        XCTAssertEqual(log.text(of: "two"), "")
    }

    func testTheLogKeepsItsNewestCallsWithinItsLimit() async throws {
        let small = CallLog(folder: folder.appendingPathComponent("small"), limit: 2_000)
        for number in 0..<40 {
            small.write(CallLog.Record(spot: "big", arguments: ["run", "\(number)"], input: nil, frames: [String(repeating: "x", count: 100)], errors: "", end: .exited(0), started: time, seconds: 0.1))
        }

        let text = small.text(of: "big")

        XCTAssertLessThanOrEqual(text.utf8.count, 2_000)
        XCTAssertTrue(text.contains("run 39"))
        XCTAssertFalse(text.contains("run 0\n"))
        XCTAssertTrue(text.hasPrefix(CallLog.mark))
    }
}
