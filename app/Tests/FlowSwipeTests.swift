import XCTest
@testable import OpenspotCore

final class FlowSwipeTests: XCTestCase {
    func testASwipeToTheRightGoesBackOnceWhenItGoesFarEnough() {
        var swipe = FlowSwipe()

        XCTAssertNil(swipe.take(dx: 20, dy: 1, phase: .began))
        XCTAssertEqual(swipe.take(dx: SpotTokens.swipeDistance, dy: 2, phase: .changed), .back)
        XCTAssertNil(swipe.take(dx: 80, dy: 0, phase: .changed))
        XCTAssertNil(swipe.take(dx: 0, dy: 0, phase: .ended))
    }

    func testASwipeToTheLeftGoesForward() {
        var swipe = FlowSwipe()

        _ = swipe.take(dx: -20, dy: 0, phase: .began)

        XCTAssertEqual(swipe.take(dx: -SpotTokens.swipeDistance, dy: 0, phase: .changed), .forward)
    }

    func testAMostlyVerticalScrollGoesNowhere() {
        var swipe = FlowSwipe()

        _ = swipe.take(dx: 4, dy: 30, phase: .began)

        XCTAssertNil(swipe.take(dx: SpotTokens.swipeDistance, dy: 10, phase: .changed))
    }

    func testANewSwipeCanStepAgainAfterTheLastOneEnded() {
        var swipe = FlowSwipe()
        _ = swipe.take(dx: 20, dy: 0, phase: .began)
        _ = swipe.take(dx: SpotTokens.swipeDistance, dy: 0, phase: .changed)
        _ = swipe.take(dx: 0, dy: 0, phase: .ended)

        _ = swipe.take(dx: 20, dy: 0, phase: .began)

        XCTAssertEqual(swipe.take(dx: SpotTokens.swipeDistance, dy: 0, phase: .changed), .back)
    }
}
