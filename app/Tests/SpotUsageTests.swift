import XCTest
@testable import OpenspotCore

/// Proves what the app counts for each spot, day by day: its runs and failures, their time, the CPU time and the disk bytes
/// of its processes, each call that needs a use and its last fault, and how each day goes to a file of its own (G1, G5, Z10).
@MainActor
final class SpotUsageTests: SpotRunsCase {
    private static let busyLoop = "i=0; while [ $i -lt 50000 ]; do i=$((i + 1)); done"

    func testABusyScriptCountsItsCPUTime() async throws {
        try script(header: "read=sheet", "\(Self.busyLoop)\nprintf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()

        runs.panelOpened()
        sheet.open {}
        try await wait("the end of the call") { self.runs.usage.counts["script"]?.runs == 1 }

        let count = try XCTUnwrap(runs.usage.counts["script"])
        XCTAssertGreaterThan(count.cpu, 0.01)
        XCTAssertGreaterThan(count.seconds, 0)
    }

    func testAStayingScriptCountsItsCPUTimeWhileItRuns() async throws {
        try script(header: "mode=stay\nread=sheet", """
        \(Self.busyLoop)
        touch '\(path("busy"))'
        while IFS= read -r line; do
          case "$line" in call=*) call=${line#call=} ;; esac
          [ -n "$line" ] || printf 'end=%s\\n\\nrow=a\\ntitle=A\\n---\\n' "$call"
        done
        """)
        let sheet = try sheet()

        runs.panelOpened()
        sheet.open {}
        try await wait("the busy loop") { self.exists("busy") }
        let pid = try await pid("pids")

        let cpu = runs.usage.counts["script"]?.cpu ?? 0
        XCTAssertEqual(kill(pid, 0), 0, "the script still runs")
        XCTAssertGreaterThan(cpu, 0.01)
    }

    func testAStayingProcessPutsItsCPUTimeOnTheDayItWasSpent() async throws {
        runs.quit()
        runs = SpotRuns(now: { [unowned self] in self.time }, stopPause: 0.2, tickPause: .milliseconds(50), stats: folder.appendingPathComponent("stats"))
        try script(header: "mode=stay\nread=sheet", """
        \(Self.busyLoop)
        touch '\(path("busy"))'
        \(untilRelease)
        \(Self.busyLoop)
        touch '\(path("busy again"))'
        while IFS= read -r line; do
          case "$line" in call=*) call=${line#call=} ;; esac
          [ -n "$line" ] || printf 'end=%s\\n\\nrow=a\\ntitle=A\\n---\\n' "$call"
        done
        """)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the first busy loop") { self.exists("busy") }
        time += 24 * 60 * 60
        runs.usage.flush()

        openGate()
        try await wait("the second busy loop") { self.exists("busy again") }
        runs.usage.flush()

        let days = runs.usage.days(2, at: time)
        XCTAssertEqual(days.count, 2)
        XCTAssertGreaterThan(days.last?.spots["script"]?.cpu ?? 0, 0.01, "the day before")
        XCTAssertGreaterThan(days.first?.spots["script"]?.cpu ?? 0, 0.01, "today")
    }

    func testAFailedCallIsTheLastFaultAndAFailure() async throws {
        try script(header: "read=sheet", "echo 'No network.' >&2\nexit 3")
        let sheet = try sheet()

        runs.panelOpened()
        sheet.open {}
        try await wait("the fault") { self.runs.usage.counts["script"]?.fault != nil }

        XCTAssertEqual(runs.usage.counts["script"]?.fault, "No network.")
        try await wait("the failure") { self.runs.usage.counts["script"]?.failures == 1 }
        XCTAssertEqual(runs.usage.counts["script"]?.runs, 1)
    }

    private let day = Date(timeIntervalSince1970: 1_794_394_800)

    private func spot(_ id: String, _ name: String, uses: Set<SpotUse> = []) -> Spot {
        Spot(id: id, name: name, url: URL(fileURLWithPath: "/\(id).sh"), uses: uses)
    }

    private var stats: URL {
        folder.appendingPathComponent("stats", isDirectory: true)
    }

    private func file(_ day: String) -> URL {
        stats.appendingPathComponent("\(day).json")
    }

    func testTodayGoesToItsFileAfterAPauseAndANewStartReadsItAgain() async throws {
        let usage = SpotUsage(folder: stats, at: day, pause: 0.05)

        usage.called(spot("a", "Alpha"), seconds: 1, isFailure: false, at: day)

        try await wait("the file of the day") { FileManager.default.fileExists(atPath: self.file("2026-11-11").path) }
        XCTAssertEqual(SpotUsage(folder: stats, at: day).counts["a"]?.runs, 1)
    }

    func testACallWritesNoFileAtOnce() throws {
        let usage = SpotUsage(folder: stats, at: day, pause: 60)

        usage.called(spot("a", "Alpha"), seconds: 1, isFailure: false, at: day)

        XCTAssertFalse(FileManager.default.fileExists(atPath: file("2026-11-11").path))
        usage.flush()
        XCTAssertTrue(FileManager.default.fileExists(atPath: file("2026-11-11").path))
    }

    func testANewDayStartsANewFile() throws {
        let usage = SpotUsage(folder: stats, at: day, pause: 60)
        usage.called(spot("a", "Alpha"), seconds: 1, isFailure: false, at: day)

        usage.called(spot("a", "Alpha"), seconds: 1, isFailure: true, at: day.addingTimeInterval(86_400))

        XCTAssertEqual(SpotUsage(folder: stats, at: day).counts["a"]?.runs, 1)
        XCTAssertEqual(usage.counts["a"]?.failures, 1)
        XCTAssertEqual(usage.counts["a"]?.runs, 1)
    }

    func testADayOlderThan90DaysIsDropped() throws {
        try FileManager.default.createDirectory(at: stats, withIntermediateDirectories: true)
        for name in ["2026-08-13", "2026-08-14", "2026-11-10"] {
            try Data("{}".utf8).write(to: file(name))
        }

        _ = SpotUsage(folder: stats, at: day)

        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: stats.path).sorted(), ["2026-08-14.json", "2026-11-10.json"])
    }

    func testACallThatNeedsAUseIsCountedAndLoggedAndToldOnceADayAcrossAStart() throws {
        let usage = SpotUsage(folder: stats, at: day, pause: 60)
        let caller = CallerTokens.Caller(id: "a", name: "Alpha", uses: [.network])
        let quit = try XCTUnwrap(SpotUseCall(arguments: ["app", "quit"], of: "a"))

        XCTAssertTrue(usage.used(quit, by: caller, at: day))
        XCTAssertFalse(usage.used(quit, by: caller, at: day))
        usage.flush()

        let again = SpotUsage(folder: stats, at: day)
        XCTAssertFalse(again.used(quit, by: caller, at: day))
        XCTAssertEqual(again.counts["a"]?.calls, ["app.quit": 3])
        XCTAssertEqual(again.counts["a"]?.network, true)
        XCTAssertEqual(again.days(1, at: day).first?.uses.map(\.declared), [false, false, false])
        XCTAssertEqual(again.days(1, at: day).first?.uses.first?.call, "app.quit")
    }

    func testAProcessReadsItsDiskBytes() throws {
        let time = try XCTUnwrap(ProcessTime(of: getpid()))

        XCTAssertGreaterThan(time.read + time.written, 0)
    }

    func testTheFrameIsARowForEachSpotWithTheMostCPUTimeFirstThenEachUse() throws {
        let usage = SpotUsage(at: day)
        usage.called(spot("a", "Alpha"), seconds: 2, isFailure: true, at: day)
        usage.add(ProcessTime(cpu: 0.04, wakeups: 0, read: 2048, written: 0), to: "a", at: day)
        usage.failed(spot("a", "Alpha"), fault: "Alpha failed.\nIt stopped.", at: day)
        usage.called(spot("b", "Beta", uses: [.network]), seconds: 0.25, isFailure: false, at: day)
        usage.called(spot("b", "Beta", uses: [.network]), seconds: 0.25, isFailure: false, at: day)
        usage.add(ProcessTime(cpu: 1.5, wakeups: 7, read: 0, written: 10), to: "b", at: day)
        _ = usage.used(try XCTUnwrap(SpotUseCall(arguments: ["screen", "shot"], of: "b")), by: .init(id: "b", name: "Beta", uses: [.network]), at: day.addingTimeInterval(60))

        let text = try StatsReport(days: usage.days(1, at: day), spot: nil).text(.frame)

        XCTAssertEqual(text, """
        row=b
        title=Beta
        detail=1.5 s CPU · 2 runs · 250 ms each
        runs=2
        failures=0
        cpu=1.500
        seconds=0.500
        read=0
        written=10
        wakeups=7
        call.screen.shot=1
        network=declared

        row=a
        title=Alpha
        detail=40 ms CPU · 1 run · 2.0 s each
        runs=1
        failures=1
        cpu=0.040
        seconds=2.000
        read=2048
        written=0
        wakeups=0
        fault=Alpha failed.\\nIt stopped.
        tone=bad

        use=1
        time=\(ISO8601DateFormatter().string(from: day.addingTimeInterval(60)))
        spot=b
        call=screen.shot
        declared=false


        """)
    }

    func testADayFileOfAnOlderFormKeepsItsCounts() throws {
        try FileManager.default.createDirectory(at: stats, withIntermediateDirectories: true)
        try #"{"day":"2026-11-11","powers":[],"spots":{"a":{"cpu":1.5,"failures":0,"network":false,"read":0,"runs":3,"seconds":1,"uses":{"screen.shot":2},"wakeups":0,"written":0}},"told":[]}"#
            .write(to: stats.appendingPathComponent("2026-11-11.json"), atomically: true, encoding: .utf8)

        let usage = SpotUsage(folder: stats, at: day, pause: 60)

        XCTAssertEqual(usage.counts["a"]?.runs, 3)
        XCTAssertEqual(usage.counts["a"]?.cpu, 1.5)
    }

    func testTheDaysSumAndOneSpotCanBeKept() throws {
        try FileManager.default.createDirectory(at: stats, withIntermediateDirectories: true)
        let before = SpotUsage(folder: stats, at: day.addingTimeInterval(-86_400), pause: 60)
        before.called(spot("a", "Alpha"), seconds: 1, isFailure: false, at: day.addingTimeInterval(-86_400))
        before.flush()
        let usage = SpotUsage(folder: stats, at: day, pause: 60)
        usage.called(spot("a", "Alpha"), seconds: 1, isFailure: false, at: day)
        usage.called(spot("b", "Beta"), seconds: 1, isFailure: false, at: day)

        let one = try StatsReport(days: usage.days(1, at: day), spot: "a").text(.frame)
        let two = try StatsReport(days: usage.days(2, at: day), spot: "a").text(.frame)

        XCTAssertTrue(one.contains("row=a\ntitle=Alpha\ndetail=0 ms CPU · 1 run · 1.0 s each\nruns=1\n"), one)
        XCTAssertFalse(one.contains("row=b"), one)
        XCTAssertTrue(two.contains("runs=2\n"), two)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(StatsReport(days: usage.days(2, at: day), spot: nil).text(.json).utf8)) as? [[String: Any]])
        XCTAssertEqual(json.map { $0["day"] as? String }, ["2026-11-11", "2026-11-10"])
        XCTAssertNil(json.first?["told"])
    }
}
