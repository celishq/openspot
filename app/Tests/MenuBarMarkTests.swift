import XCTest
@testable import OpenspotCore

final class MenuBarMarkTests: XCTestCase {
    private func mark(_ value: MetricValue?, label: String = "Label") -> MenuBarMark? {
        MenuBarMark(reading: MetricReading(label: label, value: value))
    }

    func testRowsCountEachToneWithTheWorstFirstAndNoEmptyCount() {
        let rows: [MetricValue.Row] = [
            .init(title: "a", tone: .good), .init(title: "b", tone: .bad), .init(title: "c"),
            .init(title: "d", tone: .good)
        ]

        let shown = mark(MetricValue(title: "4", symbol: "star", rows: rows))

        XCTAssertEqual(shown?.symbol, "star")
        XCTAssertEqual(shown?.content, .counts([.init(tone: .bad, count: 1), .init(tone: .good, count: 2), .init(tone: nil, count: 1)]))
    }

    func testEachOtherKindShowsItsOwnMark() {
        XCTAssertEqual(mark(MetricValue(title: "3"))?.content, .text("3"))
        XCTAssertEqual(mark(MetricValue(title: "50%", value: 0.5))?.content, .ring(fill: 0.5, title: "50%"))
        XCTAssertEqual(mark(MetricValue(title: "Up", tone: .good))?.content, .status("Up"))
        XCTAssertEqual(mark(MetricValue(title: "Up", tone: .good))?.tone, .good)
    }

    func testATrendKeepsItsNewestBarsScaledFromZero() {
        let points = (1...10).map(Double.init)

        XCTAssertEqual(mark(MetricValue(title: "10", points: points))?.content, .bars(Array(points.suffix(MenuBarMark.barCount)).map { $0 / 10 }, title: "10"))
    }

    func testNothingShowsBeforeTheFirstValueOrWhenTheMetricHidesIt() {
        XCTAssertNil(mark(nil))
        XCTAssertNil(mark(MetricValue(title: "0", isHidden: true)))
    }

    func testAFailedReadKeepsTheMarkAndDimsIt() {
        var reading = MetricReading(label: "L", value: MetricValue(title: "3"))
        XCTAssertEqual(MenuBarMark(reading: reading)?.isStale, false)

        reading.markStale()

        XCTAssertEqual(MenuBarMark(reading: reading)?.isStale, true)
    }

    func testRunningWorkIsARingOrASpinnerAndCountsOnlyMoreThanOne() {
        XCTAssertEqual(MenuBarMark(workFill: 0.5, count: 1, name: "Encode").content, .work(fill: 0.5, count: nil))
        XCTAssertEqual(MenuBarMark(workFill: nil, count: 1, name: "Encode").content, .work(fill: nil, count: nil))
        XCTAssertEqual(MenuBarMark(workFill: nil, count: 3, name: "Encode").content, .work(fill: nil, count: 3))
    }

    func testTheSummaryOfWorkNamesTheOldestCallAndHowManyRun() {
        XCTAssertEqual(MenuBarMark(workFill: nil, count: 1, name: "Encode").summary, "Encode is running")
        XCTAssertEqual(MenuBarMark(workFill: nil, count: 3, name: "Encode").summary, "3 running. Encode is the oldest")
    }

    func testTheSummaryNamesTheMetricAndItsValue() {
        XCTAssertEqual(mark(MetricValue(title: "3 open"), label: "Pull requests")?.summary, "Pull requests: 3 open")
    }
}
