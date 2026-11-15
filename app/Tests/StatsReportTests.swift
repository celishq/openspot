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
        let words = try StatsReport(days: usage.days(1, at: day), spot: nil).text(.text)

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
        bodies=2
        body=0.006000


        """)
        XCTAssertEqual(words, "Today\nCups today: 0 runs · 0 ms CPU · 0 B read · 0 B written · 0 wakeups · 2 bodies of its view, 3.00 ms each\n")
    }

    func testASpotWithNoViewHasNoBodyKeys() throws {
        let usage = SpotUsage(at: day)
        usage.called(Spot(id: "a", name: "Alpha", url: URL(fileURLWithPath: "/a.sh")), seconds: 1, isFailure: false, at: day)

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
