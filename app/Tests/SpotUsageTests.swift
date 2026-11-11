import XCTest
@testable import OpenspotCore

/// Proves what the app counts for each spot: its calls, their time, the CPU time of its processes and its last fault (G1).
@MainActor
final class SpotUsageTests: SpotRunsCase {
    private static let busyLoop = "i=0; while [ $i -lt 50000 ]; do i=$((i + 1)); done"

    func testABusyScriptCountsItsCPUTime() async throws {
        try script(header: "read=sheet", "\(Self.busyLoop)\nprintf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()

        runs.panelOpened()
        sheet.open {}
        try await wait("the end of the call") { self.runs.usage.counts["script"]?.calls == 1 }

        let count = try XCTUnwrap(runs.usage.counts["script"])
        XCTAssertGreaterThan(count.cpu, 0.01)
        XCTAssertGreaterThan(count.seconds, 0)
    }

    func testAStayingScriptCountsItsCPUTimeWhileItRuns() async throws {
        try script(header: "stay=true\nread=sheet", """
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

    func testAFailedCallIsTheLastFault() async throws {
        try script(header: "read=sheet", "echo 'No network.' >&2\nexit 3")
        let sheet = try sheet()

        runs.panelOpened()
        sheet.open {}
        try await wait("the fault") { self.runs.usage.counts["script"]?.fault != nil }

        XCTAssertEqual(runs.usage.counts["script"]?.fault, "No network.")
    }

    func testTheStatsAreARowForEachSpotWithTheMostCPUTimeFirst() {
        let usage = SpotUsage()
        usage.called("a", name: "Alpha", seconds: 2)
        usage.add(ProcessTime(cpu: 0.04, wakeups: 0), to: "a")
        usage.failed("a", name: "Alpha", fault: "Alpha failed.\nIt stopped.")
        usage.called("b", name: "Beta", seconds: 0.25)
        usage.called("b", name: "Beta", seconds: 0.25)
        usage.add(ProcessTime(cpu: 1.5, wakeups: 7), to: "b")

        XCTAssertEqual(usage.text, """
        row=b
        title=Beta
        detail=1.5 s CPU · 2 calls · 250 ms each
        cpu=1.500
        calls=2
        seconds=0.500
        wakeups=7

        row=a
        title=Alpha
        detail=40 ms CPU · 1 call · 2.0 s each
        cpu=0.040
        calls=1
        seconds=2.000
        wakeups=0
        fault=Alpha failed.\\nIt stopped.
        tone=bad


        """)
    }
}
