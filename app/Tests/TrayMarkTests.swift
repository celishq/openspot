import XCTest
@testable import OpenspotCore

final class TrayMarkTests: XCTestCase {
    private func mark(_ kind: MetricKind, _ value: MetricValue?, label: String = "Label") -> TrayMark? {
        TrayMark(reading: MetricReading(kind: kind, label: label, value: value))
    }

    func testRowsCountEachToneWithTheWorstFirstAndNoEmptyCount() {
        let rows: [MetricValue.Row] = [
            .init(title: "a", tone: .good), .init(title: "b", tone: .bad), .init(title: "c"),
            .init(title: "d", tone: .good)
        ]

        let shown = mark(.rows, MetricValue(title: "4", symbol: "star", rows: rows))

        XCTAssertEqual(shown?.symbol, "star")
        XCTAssertEqual(shown?.content, .counts([.init(tone: .bad, count: 1), .init(tone: .good, count: 2), .init(tone: nil, count: 1)]))
    }

    func testRowsWithNoLinesShowTheTitle() {
        XCTAssertEqual(mark(.rows, MetricValue(title: "None"))?.content, .text("None"))
    }

    func testEachOtherKindShowsItsOwnMark() {
        XCTAssertEqual(mark(.value, MetricValue(title: "3"))?.content, .text("3"))
        XCTAssertEqual(mark(.gauge, MetricValue(title: "50%", value: 0.5))?.content, .ring(fill: 0.5, title: "50%"))
        XCTAssertEqual(mark(.status, MetricValue(title: "Up", tone: .good))?.content, .status("Up"))
        XCTAssertEqual(mark(.status, MetricValue(title: "Up", tone: .good))?.tone, .good)
    }

    func testATrendKeepsItsNewestBarsScaledFromZero() {
        let points = (1...10).map(Double.init)

        XCTAssertEqual(mark(.trend, MetricValue(title: "10", points: points))?.content, .bars(Array(points.suffix(TrayMark.barCount)).map { $0 / 10 }, title: "10"))
    }

    func testNothingShowsBeforeTheFirstValueOrWhenTheMetricHidesIt() {
        XCTAssertNil(mark(.value, nil))
        XCTAssertNil(mark(.value, MetricValue(title: "0", isHidden: true)))
    }

    func testAFailedReadKeepsTheMarkAndDimsIt() {
        var reading = MetricReading(kind: .value, label: "L", value: MetricValue(title: "3"))
        XCTAssertEqual(TrayMark(reading: reading)?.isStale, false)

        reading.markStale()

        XCTAssertEqual(TrayMark(reading: reading)?.isStale, true)
    }

    func testTheSummaryNamesTheMetricAndItsValue() {
        XCTAssertEqual(mark(.value, MetricValue(title: "3 open"), label: "Pull requests")?.summary, "Pull requests: 3 open")
    }

    func testAMetricCanSayItIsHidden() throws {
        let block = try XCTUnwrap(TextBlock.blocks(in: "title=0\nhidden=true").first)

        XCTAssertEqual(MetricValue(block: block)?.isHidden, true)
    }
}
