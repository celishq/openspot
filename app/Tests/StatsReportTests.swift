import XCTest
@testable import OpenspotCore

final class StatsReportTests: XCTestCase {
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

        let frame = try StatsReport(days: usage.days(1, at: day), spot: nil).text(.frame)

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

        let frame = try StatsReport(days: usage.days(3, at: day), spot: nil).text(.frame)

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

        let frame = try StatsReport(days: usage.days(1, at: day), spot: nil, cards: [card]).text(.frame)
        let rows = frame.components(separatedBy: "\n\n").map { $0 + "\n" }

        XCTAssertTrue(rows.contains { $0.hasPrefix("row=a\n") && $0.contains("\ncards=system\n") }, frame)
        XCTAssertTrue(rows.contains { $0.hasPrefix("row=system\ntitle=System\n") && $0.contains("\nshows=a\nshows=b\n") }, frame)
        XCTAssertFalse(try StatsReport(days: usage.days(1, at: day), spot: "a", cards: [card]).text(.frame).contains("row=system"))
    }

    func testASpotWithNoViewHasNoBodyKeys() throws {
        let usage = SpotUsage(at: day)
        usage.called(Spot(id: "a", name: "Alpha", url: URL(fileURLWithPath: "/a.sh")), CallOutcome(seconds: 1), at: day)

        let frame = try StatsReport(days: usage.days(1, at: day), spot: nil).text(.frame)

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

        let frame = try StatsReport(days: usage.days(3, at: day), spot: "cups").text(.frame)

        XCTAssertTrue(frame.contains("runs=3\n"), frame)
        XCTAssertTrue(frame.contains("bodies=2\nbody=0.004000\n"), frame)
    }
}
