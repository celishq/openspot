import XCTest
@testable import OpenspotCore

@MainActor
final class StatsLogTests: SpotRunsCase {
    private static let busyLoop = "i=0; while [ $i -lt 50000 ]; do i=$((i + 1)); done"

    func testABusyScriptCountsItsCPUTime() async throws {
        try script(header: "on=sheet.open", "\(Self.busyLoop)\nprintf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()

        runs.panelOpened()
        sheet.open {}
        try await wait("the end of the call") { self.runs.usage.counts["script"]?.runs == 1 }

        let count = try XCTUnwrap(runs.usage.counts["script"])
        XCTAssertGreaterThan(count.cost.cpu, 0.01)
        XCTAssertGreaterThan(count.seconds, 0)
    }

    func testAStayingScriptCountsItsCPUTimeWhileItRuns() async throws {
        try script(header: "mode=stay\non=sheet.open\noffers=card\noffers=menubar", """
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

        let cpu = runs.usage.counts["script"]?.cost.cpu ?? 0
        XCTAssertEqual(kill(pid, 0), 0, "the script still runs")
        XCTAssertGreaterThan(cpu, 0.01)
    }

    func testAStayingProcessPutsItsCPUTimeOnTheDayItWasSpent() async throws {
        runs.quit()
        runs = SpotRuns(clock: clock.value, stopPause: 0.2, stats: folder.appendingPathComponent("stats"))
        try script(header: "mode=stay\non=sheet.open\noffers=card\noffers=menubar", """
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
        XCTAssertGreaterThan(days.last?.spots["script"]?.cost.cpu ?? 0, 0.01, "the day before")
        XCTAssertGreaterThan(days.first?.spots["script"]?.cost.cpu ?? 0, 0.01, "today")
    }

    func testAFailedCallIsTheLastFaultAndAFailure() async throws {
        try script(header: "on=sheet.open", "echo 'No network.' >&2\nexit 3")
        let sheet = try sheet()

        runs.panelOpened()
        sheet.open {}
        try await wait("the fault") { self.runs.usage.counts["script"]?.fault != nil }

        XCTAssertEqual(runs.usage.counts["script"]?.fault, "No network.")
        try await wait("the failure") { self.runs.usage.counts["script"]?.failures.count == 1 }
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
        let usage = StatsLog(folder: stats, at: day, pause: 0.05)

        usage.called(spot("a", "Alpha"), CallOutcome(seconds: 1), at: day)

        try await wait("the file of the day") { FileManager.default.fileExists(atPath: self.file("2026-11-11").path) }
        XCTAssertEqual(StatsLog(folder: stats, at: day).counts["a"]?.runs, 1)
    }

    func testAChangeIsNotWrittenBeforeItsPauseOfAMinute() async throws {
        let usual = StatsLog(folder: stats, at: day)
        let other = folder.appendingPathComponent("other", isDirectory: true)
        let sooner = StatsLog(folder: other, at: day, pause: 5.5)

        usual.called(spot("a", "Alpha"), CallOutcome(seconds: 1), at: day)
        sooner.called(spot("a", "Alpha"), CallOutcome(seconds: 1), at: day)

        for _ in 0..<1_000 where !FileManager.default.fileExists(atPath: other.appendingPathComponent("2026-11-11.json").path) {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: other.appendingPathComponent("2026-11-11.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file("2026-11-11").path))
    }

    func testTheCountsJustAfterANewDayHoldTheDayThatEnded() {
        let usage = StatsLog(folder: stats, at: day, pause: 60)
        usage.called(spot("a", "Alpha"), CallOutcome(seconds: 1), at: day)
        let next = day.addingTimeInterval(86_400)
        usage.called(spot("a", "Alpha"), CallOutcome(seconds: 1), at: next)

        let days = usage.days(2, at: next)

        XCTAssertEqual(days.map(\.day), ["2026-11-12", "2026-11-11"])
        XCTAssertEqual(days.last?.spots["a"]?.runs, 1)
    }

    func testTheMacGoingToSleepWritesTheDay() throws {
        runs = SpotRuns(clock: clock.value, stats: stats)
        runs.usage.called(spot("a", "Alpha"), CallOutcome(seconds: 1), at: time)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stats.path))

        runs.raise(.sleep)

        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: stats.path).count, 1)
    }

    func testACallWritesNoFileAtOnce() throws {
        let usage = StatsLog(folder: stats, at: day, pause: 60)

        usage.called(spot("a", "Alpha"), CallOutcome(seconds: 1), at: day)

        XCTAssertFalse(FileManager.default.fileExists(atPath: file("2026-11-11").path))
        usage.flush()
        XCTAssertTrue(FileManager.default.fileExists(atPath: file("2026-11-11").path))
    }

    func testANewDayStartsANewFile() async throws {
        let usage = StatsLog(folder: stats, at: day, pause: 60)
        usage.called(spot("a", "Alpha"), CallOutcome(seconds: 1), at: day)

        usage.called(spot("a", "Alpha"), CallOutcome(seconds: 1, failure: .exit), at: day.addingTimeInterval(86_400))

        try await wait("the file of the day that ended") { FileManager.default.fileExists(atPath: self.file("2026-11-11").path) }

        XCTAssertEqual(StatsLog(folder: stats, at: day).counts["a"]?.runs, 1)
        XCTAssertEqual(usage.counts["a"]?.failures.count, 1)
        XCTAssertEqual(usage.counts["a"]?.runs, 1)
    }

    func testADayOlderThan90DaysIsDropped() throws {
        try FileManager.default.createDirectory(at: stats, withIntermediateDirectories: true)
        for name in ["2026-08-13", "2026-08-14", "2026-11-10"] {
            try Data("{}".utf8).write(to: file(name))
        }

        _ = StatsLog(folder: stats, at: day)

        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: stats.path).sorted(), ["2026-08-14.json", "2026-11-10.json"])
    }

    func testACallThatNeedsAUseIsCountedAndLoggedAndToldOnceADayAcrossAStart() throws {
        let usage = StatsLog(folder: stats, at: day, pause: 60)
        let caller = CallerTokens.Caller(id: "a", name: "Alpha", uses: [.network])
        let quit = try XCTUnwrap(SpotUseCall(arguments: ["app", "quit"], of: "a"))

        XCTAssertTrue(usage.used(quit, by: caller, at: day))
        XCTAssertFalse(usage.used(quit, by: caller, at: day))
        usage.flush()

        let again = StatsLog(folder: stats, at: day)
        XCTAssertFalse(again.used(quit, by: caller, at: day))
        XCTAssertEqual(again.counts["a"]?.calls, ["app.quit": 3])
        XCTAssertEqual(again.counts["a"]?.network, true)
        XCTAssertEqual(again.days(1, at: day).first?.uses.map(\.declared), [false, false, false])
        XCTAssertEqual(again.days(1, at: day).first?.uses.first?.call, "app.quit")
    }

    func testTheRunsTellTheUsageWhichSpotOwnsEachView() throws {
        try script(header: "on=sheet.open\nview=cups.swift", "printf 'view=cups\n'")
        let view = try XCTUnwrap(try scanned().scripts.first?.view)

        runs.usage.drew(view: view, seconds: 0.5)

        XCTAssertEqual(runs.usage.counts["script"]?.view, StatsLog.ViewTime(bodies: 1, seconds: 0.5))
        XCTAssertEqual(runs.usage.counts["script"]?.name, "Script")
    }

    func testOpeningASheetAndPickingARowAtOnceIsOneActAndTheReadIsCountedByItsReason() async throws {
        try script(header: "on=sheet.open", "printf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()

        runs.panelOpened()
        sheet.open {}
        try await wait("the read") { self.runs.usage.counts["script"]?.runs == 1 }
        sheet.pick(SpotItem(title: "A", run: "a"))
        try await wait("the pick") { self.runs.usage.counts["script"]?.runs == 2 }

        let count = try XCTUnwrap(runs.usage.counts["script"])
        XCTAssertEqual(count.acts, 1)
        XCTAssertNotNil(count.last)
        XCTAssertEqual(count.reads, ["sheet.open": 1])
        XCTAssertEqual(count.answers.total, 1)
    }

    func testTwoActsOnASpotWithinTwoSecondsAreOne() {
        let usage = StatsLog(at: day)

        usage.acted(spot("a", "Alpha"), at: day)
        usage.acted(spot("a", "Alpha"), at: day.addingTimeInterval(1))
        usage.acted(spot("a", "Alpha"), at: day.addingTimeInterval(4))

        XCTAssertEqual(usage.counts["a"]?.acts, 2)
    }

    func testOnlyACallThatAsksTimesTheAnswer() {
        let usage = StatsLog(at: day)

        usage.called(spot("a", "Alpha"), CallOutcome(seconds: 30, answered: nil), at: day)
        usage.called(spot("a", "Alpha"), CallOutcome(seconds: 0.3, answered: 0.07), at: day)

        XCTAssertEqual(usage.counts["a"]?.runs, 2)
        XCTAssertEqual(usage.counts["a"]?.answers.total, 1)
    }

    func testTodayCountsActsBeforeItsFirstChange() {
        let usage = StatsLog(at: day)

        let days = usage.days(2, at: day.addingTimeInterval(86_400))

        XCTAssertEqual(days.map(\.countsActs), [true, true])
    }

    func testCostWhileThePanelIsHiddenIsKeptApart() {
        let usage = StatsLog(at: day)

        usage.add(ProcessTime(cpu: 1, wakeups: 2), to: "a", at: day)
        usage.panel(shown: true)
        usage.add(ProcessTime(cpu: 0.5, wakeups: 3), to: "a", at: day)

        XCTAssertEqual(usage.counts["a"]?.cost.cpu, 1.5)
        XCTAssertEqual(usage.counts["a"]?.hidden.cpu, 1)
        XCTAssertEqual(usage.counts["a"]?.hidden.wakeups, 2)
    }

    func testTheMemoryIsThePeakOfItsProcesses() {
        let usage = StatsLog(at: day)

        usage.add(ProcessTime(cpu: 0, wakeups: 0, memory: 3_000), to: "a", at: day)
        usage.add(ProcessTime(cpu: 0, wakeups: 0, memory: 2_000), to: "a", at: day)

        XCTAssertEqual(usage.counts["a"]?.cost.memory, 3_000)
    }

    func testAFailureIsCountedByItsKindWithItsTime() {
        let usage = StatsLog(at: day)

        usage.called(spot("a", "Alpha"), CallOutcome(seconds: 5, failure: StatsLog.Failure(SpotError.timedOut)), at: day)
        usage.called(spot("a", "Alpha"), CallOutcome(seconds: 1, failure: StatsLog.Failure(SpotError.failed(2, ""))), at: day)
        usage.failedRun(spot("a", "Alpha"), failure: StatsLog.Failure(SpotError.badState), at: day)
        usage.failed(spot("a", "Alpha"), fault: "It stopped.", at: day)

        XCTAssertEqual(usage.counts["a"]?.failures.count, 3)
        XCTAssertEqual(usage.counts["a"]?.failures.kinds, ["timeout": 1, "exit": 1, "output": 1])
        XCTAssertEqual(usage.counts["a"]?.failures.last, day)
    }

    func testOnlyAUseThatItsHeaderDoesNotDeclareIsLogged() throws {
        let usage = StatsLog(at: day)
        let quit = try XCTUnwrap(SpotUseCall(arguments: ["app", "quit"], of: "a"))

        _ = usage.used(quit, by: .init(id: "a", name: "Alpha", uses: [.app]), at: day)
        _ = usage.used(quit, by: .init(id: "b", name: "Beta", uses: []), at: day)

        XCTAssertEqual(usage.days(1, at: day).first?.uses.map(\.spot), ["b"])
        XCTAssertEqual(usage.counts["a"]?.calls, ["app.quit": 1])
    }

    func testADayWithNoFileOrKeptBeforeActsWereCountedHasNoCountOfActs() throws {
        try FileManager.default.createDirectory(at: stats, withIntermediateDirectories: true)
        try #"{"day":"2026-11-10","spots":{},"told":[],"uses":[]}"#.write(to: file("2026-11-10"), atomically: true, encoding: .utf8)
        let usage = StatsLog(folder: stats, at: day, pause: 60)

        let days = usage.days(3, at: day)

        XCTAssertEqual(days.map(\.day), ["2026-11-11", "2026-11-10", "2026-11-09"])
        XCTAssertEqual(days.map(\.countsActs), [true, false, false])
    }

    func testAProcessReadsItsDiskBytes() throws {
        let time = try XCTUnwrap(ProcessTime(of: getpid()))

        XCTAssertGreaterThan(time.read + time.written, 0)
    }

    func testTheFrameIsARowForEachSpotWithTheMostCPUTimeFirstThenEachUse() throws {
        let usage = StatsLog(at: day)
        usage.called(spot("a", "Alpha"), CallOutcome(seconds: 2, failure: .exit), at: day)
        usage.add(ProcessTime(cpu: 0.04, wakeups: 0, read: 2048, written: 0), to: "a", at: day)
        usage.failed(spot("a", "Alpha"), fault: "Alpha failed.\nIt stopped.", at: day)
        usage.called(spot("b", "Beta", uses: [.network]), CallOutcome(seconds: 0.25), at: day)
        usage.called(spot("b", "Beta", uses: [.network]), CallOutcome(seconds: 0.25), at: day)
        usage.add(ProcessTime(cpu: 1.5, wakeups: 7, read: 0, written: 10), to: "b", at: day)
        _ = usage.used(try XCTUnwrap(SpotUseCall(arguments: ["screen", "shot"], of: "b")), by: .init(id: "b", name: "Beta", uses: [.network]), at: day.addingTimeInterval(60))

        let text = try Stats(days: usage.days(1, at: day), spot: nil).text(.frame)

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
        acts=0
        days=0
        seen=1
        hidden.cpu=1.500
        hidden.wakeups=7
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
        acts=0
        days=0
        seen=1
        hidden.cpu=0.040
        hidden.wakeups=0
        failures.exit=1
        failed=\(ISO8601DateFormatter().string(from: day))
        fault=Alpha failed.\\nIt stopped.
        tone=bad

        use=1
        time=\(ISO8601DateFormatter().string(from: day.addingTimeInterval(60)))
        spot=b
        call=screen.shot
        declared=false


        """)
    }

    func testTheDaysSumAndOneSpotCanBeKept() throws {
        try FileManager.default.createDirectory(at: stats, withIntermediateDirectories: true)
        let before = StatsLog(folder: stats, at: day.addingTimeInterval(-86_400), pause: 60)
        before.called(spot("a", "Alpha"), CallOutcome(seconds: 1), at: day.addingTimeInterval(-86_400))
        before.flush()
        let usage = StatsLog(folder: stats, at: day, pause: 60)
        usage.called(spot("a", "Alpha"), CallOutcome(seconds: 1), at: day)
        usage.called(spot("b", "Beta"), CallOutcome(seconds: 1), at: day)

        let one = try Stats(days: usage.days(1, at: day), spot: "a").text(.frame)
        let two = try Stats(days: usage.days(2, at: day), spot: "a").text(.frame)

        XCTAssertTrue(one.contains("row=a\ntitle=Alpha\ndetail=0 ms CPU · 1 run · 1.0 s each\nruns=1\n"), one)
        XCTAssertFalse(one.contains("row=b"), one)
        XCTAssertTrue(two.contains("runs=2\n"), two)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(Stats(days: usage.days(2, at: day), spot: nil).text(.json).utf8)) as? [[String: Any]])
        XCTAssertEqual(json.map { $0["day"] as? String }, ["2026-11-11", "2026-11-10"])
        XCTAssertNil(json.first?["told"])
    }

    func testTheCountOfEachVersionOfASpotIsKeptAcrossAStart() {
        let usage = StatsLog(folder: stats, at: day, pause: 60, now: { self.day })
        usage.take(versions: ["a": "v1"])

        usage.called(spot("a", "Alpha"), CallOutcome(seconds: 1), at: day)
        usage.flush()

        let version = StatsLog(folder: stats, at: day).days(1, at: day).first?.versions["a"]?["v1"]
        XCTAssertEqual(version?.count.runs, 1)
        XCTAssertEqual(version?.first, day)
    }

    func testADayKeptBeforeVersionsReadsItsCountsAsOneUnknownVersion() throws {
        try FileManager.default.createDirectory(at: stats, withIntermediateDirectories: true)
        try Data(#"{"day":"2026-11-11","spots":{"a":{"runs":2}}}"#.utf8).write(to: file("2026-11-11"))

        let kept = StatsLog(folder: stats, at: day).days(1, at: day).first

        XCTAssertEqual(kept?.spots["a"]?.runs, 2)
        XCTAssertEqual(kept?.versions["a"]?["-"]?.count.runs, 2)
    }

    func testASpotIsTheSumOfItsVersionsWithTheFaultOfTheNewest() {
        let usage = StatsLog(at: day)
        usage.take(versions: ["a": "v1"])
        usage.failed(spot("a", "Alpha"), fault: "old", at: day)
        usage.called(spot("a", "Alpha"), CallOutcome(seconds: 1), at: day)
        usage.take(versions: ["a": "v2"])
        usage.failed(spot("a", "Alpha"), fault: "new", at: day.addingTimeInterval(60))
        usage.called(spot("a", "Alpha"), CallOutcome(seconds: 1), at: day.addingTimeInterval(60))

        XCTAssertEqual(usage.counts["a"]?.runs, 2)
        XCTAssertEqual(usage.counts["a"]?.fault, "new")
    }
}
