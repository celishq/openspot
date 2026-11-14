import XCTest
@testable import OpenspotCore

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

    func testATimedReadThatEndsWellLeavesNoRecordAndAPanelReadDoes() async throws {
        try script(header: "on=panel.open", "echo \"title=$OPENSPOT_REASON\"")
        let sheet = try sheet()

        sheet.read(reason: .clock(60))
        try await wait("the end of the timed read") { self.log().count == 1 && sheet.calls.isEmpty }
        time += 10
        sheet.read(reason: .panel)
        try await wait("the record of the panel read") { self.log.text(of: "script").contains("title=panel.open") }

        XCTAssertFalse(log.text(of: "script").contains("title=clock.60"))
    }

    func testATimedReadThatFailsLeavesARecord() async throws {
        try script(header: "on=panel.open", "echo 'The sensor is gone.' >&2; exit 2")
        let sheet = try sheet()

        sheet.read(reason: .clock(60))

        try await wait("the record") { self.log.text(of: "script").contains("The sensor is gone.") }
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

    func testACallKeepsOnlyTheFramesThatItsRecordShows() {
        let small = CallLog(folder: folder.appendingPathComponent("small"), limit: 2_000)
        var frames: [String] = []
        for number in 0..<100 {
            small.add("frame \(number) " + String(repeating: "x", count: 90), to: &frames)
        }
        small.write(CallLog.Record(spot: "many", arguments: ["read"], input: nil, frames: frames, errors: "", end: .exited(0), started: time, seconds: 0.1))

        let text = small.text(of: "many")

        XCTAssertLessThan(frames.count, 10)
        XCTAssertTrue(text.contains("frame 99 "))
        XCTAssertFalse(text.contains("frame 90 "))
    }

    func testARecordMarksTheCutWhenItDropsAnOlderFrame() {
        let small = CallLog(folder: folder.appendingPathComponent("small"), limit: 2_000)

        small.write(CallLog.Record(spot: "cut", arguments: ["read"], input: nil, frames: [String(repeating: "a", count: 10), String(repeating: "b", count: 500)], errors: "", end: .exited(0), started: time, seconds: 0.1))

        XCTAssertTrue(small.text(of: "cut").contains("stdout:\n…" + String(repeating: "b", count: 500)))
    }

    func testTheLogKeepsItsNewestCallsWhenItsFileHoldsMore() throws {
        let small = CallLog(folder: folder.appendingPathComponent("small"), limit: 2_000)
        for number in 0..<25 {
            small.write(CallLog.Record(spot: "big", arguments: ["run", "\(number)"], input: nil, frames: [String(repeating: "x", count: 100)], errors: "", end: .exited(0), started: time, seconds: 0.1))
        }

        let text = small.text(of: "big")
        let file = try Data(contentsOf: folder.appendingPathComponent("small/big.log"))

        XCTAssertLessThanOrEqual(file.count, 4_000)
        XCTAssertLessThanOrEqual(text.utf8.count, 2_000)
        XCTAssertTrue(text.contains("run 24"))
        XCTAssertTrue(text.hasPrefix(CallLog.mark))
    }
}
