import XCTest
@testable import OpenspotCore

final class WorkFillTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    private func at(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    func testAFillWithNoReportStartsAtZeroAndGrowsWithTime() {
        let fill = WorkFill(base: 0, since: start)

        XCTAssertEqual(fill.value(at: start), 0)
        XCTAssertGreaterThan(fill.value(at: at(1)), 0)
        XCTAssertGreaterThan(fill.value(at: at(10)), fill.value(at: at(5)))
        XCTAssertGreaterThan(fill.value(at: at(60)), fill.value(at: at(30)))
    }

    func testAFillNeverPassesItsCeiling() {
        let fill = WorkFill(base: 0.5, since: start)

        XCTAssertLessThanOrEqual(fill.value(at: at(1_000_000)), 0.5 + 0.5 * MotionTokens.workCeiling)
        XCTAssertLessThan(fill.value(at: at(1_000_000)), 1)
    }

    func testANewerHigherReportJumpsTheFill() {
        let fill = WorkFill(base: 0, since: start).taking(0.7, at: at(1))

        XCTAssertEqual(fill.value(at: at(1)), 0.7)
        XCTAssertGreaterThan(fill.value(at: at(2)), 0.7)
    }

    func testALowerReportNeverTakesTheFillBack() {
        let fill = WorkFill(base: 0, since: start).taking(0.6, at: at(1))
        let shown = fill.value(at: at(20))

        let lower = fill.taking(0.2, at: at(20))

        XCTAssertEqual(lower.value(at: at(20)), shown)
        XCTAssertGreaterThanOrEqual(lower.value(at: at(21)), fill.value(at: at(20)))
    }
}
