import XCTest
@testable import OpenspotCore

final class StatsTests: XCTestCase {
    private var folder: URL!
    private let day = Date(timeIntervalSince1970: 1_794_394_800)
    private let view = "/spots/cups.spot/cups.swift"

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-stats-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private var cups: Spot {
        Spot(id: "cups", name: "Cups today", url: URL(fileURLWithPath: "/spots/cups.spot/cups.sh"), view: view)
    }

    func testTheBodyTimeOfAViewShowsInTheRowOfItsSpot() throws {
        let usage = SpotUsage(at: day)
        usage.take(views: [cups])
        usage.drew(view: view, seconds: 0.002)
        usage.drew(view: view, seconds: 0.004)
        usage.drew(view: "/spots/other.swift", seconds: 1)

        let frame = try Stats(days: usage.days(1, at: day), spot: nil).text(.frame)

        XCTAssertEqual(frame, """
        row=cups
        title=Cups today
        detail=0 ms CPU · 2 bodies of its view · 3.00 ms each
        runs=0
        failures=0
        cpu=0.000
        seconds=0.000
        read=0
        written=0
        wakeups=0
        acts=0
        days=0
        seen=1
        bodies=2
        body=0.006000


        """)
    }

    func testARowHoldsTheActsOfEachDayOldestFirstAndWhatTheSpotCostAndHowFastItAnswered() throws {
        let usage = SpotUsage(at: day)
        let alpha = Spot(id: "a", name: "Alpha", url: URL(fileURLWithPath: "/a.sh"))
        usage.acted(alpha, at: day.addingTimeInterval(-5))
        usage.acted(alpha, at: day)
        usage.called(alpha, CallOutcome(seconds: 0.3, answered: 0.07, reason: "sheet.open"), at: day)
        usage.called(alpha, CallOutcome(seconds: 9, answered: 2, failure: .timeout), at: day)
        usage.add(ProcessTime(cpu: 0.25, wakeups: 4, memory: 5_000_000), to: "a", at: day)
        usage.failed(alpha, fault: "Alpha took too long.", at: day)

        let frame = try Stats(days: usage.days(3, at: day), spot: nil).text(.frame)

        let stamp = ISO8601DateFormatter().string(from: day)
        XCTAssertEqual(frame, """
        row=a
        title=Alpha
        detail=250 ms CPU · 2 runs · 4.7 s each
        runs=2
        failures=1
        cpu=0.250
        seconds=9.300
        read=0
        written=0
        wakeups=4
        acts=2
        last=\(stamp)
        days=-
        days=-
        days=2
        seen=1
        reads.sheet.open=1
        hidden.cpu=0.250
        hidden.wakeups=4
        p50=0.100
        p95=3.200
        memory=5000000
        failures.timeout=1
        failed=\(stamp)
        fault=Alpha took too long.
        tone=bad


        """)
    }

    func testACardOfSpotsGetsARowThatNamesTheSpotsItShowsAndEachSpotNamesItsCards() throws {
        let usage = SpotUsage(at: day)
        usage.called(Spot(id: "a", name: "Alpha", url: URL(fileURLWithPath: "/a.sh")), CallOutcome(seconds: 1), at: day)
        let card = Spot(id: "system", name: "System", url: URL(fileURLWithPath: "/system.sh"), kind: .widget, places: ["a", "b"])

        let frame = try Stats(days: usage.days(1, at: day), spot: nil, cards: [card]).text(.frame)
        let rows = frame.components(separatedBy: "\n\n").map { $0 + "\n" }

        XCTAssertTrue(rows.contains { $0.hasPrefix("row=a\n") && $0.contains("\ncards=system\n") }, frame)
        XCTAssertTrue(rows.contains { $0.hasPrefix("row=system\ntitle=System\n") && $0.contains("\nshows=a\nshows=b\n") }, frame)
        XCTAssertFalse(try Stats(days: usage.days(1, at: day), spot: "a", cards: [card]).text(.frame).contains("row=system"))
    }

    func testARunThatOneSpotStartsOfAnotherShowsOnBoth() throws {
        let usage = SpotUsage(at: day)
        usage.ran(Spot(id: "a", name: "Alpha", url: URL(fileURLWithPath: "/a.sh")), by: "b", CallOutcome(seconds: 1), at: day)
        usage.called(Spot(id: "b", name: "Beta", url: URL(fileURLWithPath: "/b.sh")), CallOutcome(seconds: 1), at: day)

        let rows = try Stats(days: usage.days(1, at: day), spot: nil).text(.frame).components(separatedBy: "\n\n").map { $0 + "\n" }

        XCTAssertTrue(rows.contains { $0.hasPrefix("row=a\n") && $0.contains("\nruns.by.b=1\n") }, rows.joined())
        XCTAssertTrue(rows.contains { $0.hasPrefix("row=b\n") && $0.contains("\nran.a=1\n") }, rows.joined())
        XCTAssertTrue(try Stats(days: usage.days(1, at: day), spot: "b").text(.frame).contains("\nran.a=1\n"))
    }

    func testASpotWithNoViewHasNoBodyKeys() throws {
        let usage = SpotUsage(at: day)
        usage.called(Spot(id: "a", name: "Alpha", url: URL(fileURLWithPath: "/a.sh")), CallOutcome(seconds: 1), at: day)

        let frame = try Stats(days: usage.days(1, at: day), spot: nil).text(.frame)

        XCTAssertFalse(frame.contains("bod"), frame)
    }

    func testTheBodyTimeAddsUpOverTheDaysAndADayKeptBeforeItStillReads() throws {
        let stats = folder.appendingPathComponent("stats", isDirectory: true)
        try FileManager.default.createDirectory(at: stats, withIntermediateDirectories: true)
        try #"{"day":"2026-11-09","spots":{"cups":{"calls":{},"cpu":0,"failures":0,"name":"Cups today","network":false,"read":0,"runs":3,"seconds":1,"wakeups":0,"written":0}},"told":[],"uses":[]}"#
            .write(to: stats.appendingPathComponent("2026-11-09.json"), atomically: true, encoding: .utf8)
        let before = SpotUsage(folder: stats, at: day.addingTimeInterval(-86_400), pause: 60)
        before.take(views: [cups])
        before.drew(view: view, seconds: 0.001)
        before.flush()
        let usage = SpotUsage(folder: stats, at: day, pause: 60)
        usage.take(views: [cups])
        usage.drew(view: view, seconds: 0.003)

        let frame = try Stats(days: usage.days(3, at: day), spot: "cups").text(.frame)

        XCTAssertTrue(frame.contains("runs=3\n"), frame)
        XCTAssertTrue(frame.contains("bodies=2\nbody=0.004000\n"), frame)
    }

    func testByVersionARowOfEachVersionOfASpotTellsItsCountsOldestFirst() throws {
        let usage = SpotUsage(at: day)
        let alpha = Spot(id: "a", name: "Alpha", url: URL(fileURLWithPath: "/a.sh"))
        usage.take(versions: ["a": "v1"])
        usage.called(alpha, CallOutcome(seconds: 1, failure: .exit), at: day)
        usage.take(versions: ["a": "v2"])
        usage.called(alpha, CallOutcome(seconds: 1), at: day.addingTimeInterval(60))
        usage.called(alpha, CallOutcome(seconds: 1), at: day.addingTimeInterval(61))

        let frame = try Stats(days: usage.days(1, at: day), spot: nil, byVersion: true).text(.frame)

        let blocks = frame.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        XCTAssertEqual(blocks.count, 2, frame)
        XCTAssertTrue(blocks[0].hasPrefix("row=a\nversion=v1\nsince=\(ISO8601DateFormatter().string(from: day))\n"), frame)
        XCTAssertTrue(blocks[0].contains("\nruns=1\nfailures=1\n"), frame)
        XCTAssertTrue(blocks[1].hasPrefix("row=a\nversion=v2\nsince=\(ISO8601DateFormatter().string(from: day.addingTimeInterval(60)))\n"), frame)
        XCTAssertTrue(blocks[1].contains("\nruns=2\nfailures=0\n"), frame)
        XCTAssertTrue(try Stats(days: usage.days(1, at: day), spot: nil, byVersion: true).text(.json).contains("\"versions\":{\"a\":{\"v1\""))
    }

    func testOpenMetricsPrintsEachCounterOfASpotWithItsLabels() throws {
        let usage = SpotUsage(at: day)
        let alpha = Spot(id: "a", name: "Alpha", url: URL(fileURLWithPath: "/a.sh"))
        usage.panel(shown: true)
        usage.acted(alpha, at: day)
        usage.called(alpha, CallOutcome(seconds: 0.5, answered: 0.07, reason: "sheet.open"), at: day)
        usage.called(alpha, CallOutcome(seconds: 2, answered: 2, failure: .timeout), at: day)
        usage.add(ProcessTime(cpu: 0.25, wakeups: 4, read: 10, written: 20, memory: 5_000), to: "a", at: day)
        usage.panel(shown: false)
        usage.add(ProcessTime(cpu: 0.1, wakeups: 1), to: "a", at: day)

        let text = try Stats(days: usage.days(1, at: day), spot: nil).text(.metrics)

        XCTAssertEqual(text, """
        # TYPE openspot_spot_acts counter
        openspot_spot_acts_total{spot="a"} 1
        # TYPE openspot_spot_runs counter
        openspot_spot_runs_total{spot="a"} 2
        # TYPE openspot_spot_failures counter
        openspot_spot_failures_total{spot="a",kind="timeout"} 1
        # TYPE openspot_spot_call_seconds counter
        openspot_spot_call_seconds_total{spot="a"} 2.5
        # TYPE process_cpu_time_seconds counter
        process_cpu_time_seconds_total{spot="a",hidden="false"} 0.25
        process_cpu_time_seconds_total{spot="a",hidden="true"} 0.1
        # TYPE openspot_spot_wakeups counter
        openspot_spot_wakeups_total{spot="a",hidden="false"} 4
        openspot_spot_wakeups_total{spot="a",hidden="true"} 1
        # TYPE process_disk_io_bytes counter
        process_disk_io_bytes_total{spot="a",direction="read"} 10
        process_disk_io_bytes_total{spot="a",direction="write"} 20
        # TYPE openspot_spot_memory_peak_bytes gauge
        openspot_spot_memory_peak_bytes{spot="a"} 5000
        # TYPE openspot_spot_answer_seconds histogram
        openspot_spot_answer_seconds_bucket{spot="a",le="0.05"} 0
        openspot_spot_answer_seconds_bucket{spot="a",le="0.1"} 1
        openspot_spot_answer_seconds_bucket{spot="a",le="0.2"} 1
        openspot_spot_answer_seconds_bucket{spot="a",le="0.4"} 1
        openspot_spot_answer_seconds_bucket{spot="a",le="0.8"} 1
        openspot_spot_answer_seconds_bucket{spot="a",le="1.6"} 1
        openspot_spot_answer_seconds_bucket{spot="a",le="3.2"} 2
        openspot_spot_answer_seconds_bucket{spot="a",le="6.4"} 2
        openspot_spot_answer_seconds_bucket{spot="a",le="+Inf"} 2
        # TYPE openspot_spot_reads counter
        openspot_spot_reads_total{spot="a",reason="sheet.open"} 1
        # EOF

        """)
    }

    func testOpenMetricsByVersionLabelsEachCounterWithItsVersionAndEscapesALabel() throws {
        let usage = SpotUsage(at: day)
        let alpha = Spot(id: "a\"b", name: "Alpha", url: URL(fileURLWithPath: "/a.sh"))
        usage.take(versions: ["a\"b": "v1"])
        usage.called(alpha, CallOutcome(seconds: 1), at: day)

        let text = try Stats(days: usage.days(1, at: day), spot: nil, byVersion: true).text(.metrics)

        XCTAssertTrue(text.contains("openspot_spot_runs_total{spot=\"a\\\"b\",version=\"v1\"} 1\n"), text)
    }
}
