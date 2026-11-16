import XCTest
@testable import OpenspotCore

@MainActor
final class MotionTokensTests: XCTestCase {
    func testSlowMotionMakesEachDurationTenTimesLongerUntilItIsTurnedOff() {
        let grow = MotionTokens.grow
        let fadeOut = MotionTokens.fadeOut

        XCTAssertTrue(MotionTokens.toggleSlowMotion())
        XCTAssertEqual(MotionTokens.grow, grow * 10, accuracy: 0.0001)
        XCTAssertEqual(MotionTokens.fadeOut, fadeOut * 10, accuracy: 0.0001)

        XCTAssertFalse(MotionTokens.toggleSlowMotion())
        XCTAssertEqual(MotionTokens.grow, grow, accuracy: 0.0001)
    }
}
