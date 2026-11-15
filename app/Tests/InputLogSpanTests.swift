import XCTest
@testable import OpenspotCore

final class InputLogSpanTests: XCTestCase {
    func testAnEventBeforeTheFirstFrameHasNoTime() {
        let span = InputLogSpan()

        XCTAssertNil(span.seconds(at: 10))
    }

    func testTimeCountsFromTheFirstFrame() {
        var span = InputLogSpan()

        span.begin(at: 10)
        span.begin(at: 12)

        XCTAssertEqual(span.seconds(at: 13.5), 3.5)
        XCTAssertNil(span.seconds(at: 9))
    }

    func testTheLogTakesNoLineOnceItHoldsItsLimit() {
        var span = InputLogSpan(limit: 100)

        XCTAssertTrue(span.admits(60))
        XCTAssertFalse(span.isFull)
        XCTAssertFalse(span.admits(60))
        XCTAssertFalse(span.admits(40))
        XCTAssertTrue(span.isFull)
    }
}
