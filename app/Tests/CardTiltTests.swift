import XCTest
@testable import OpenspotCore

final class CardTiltTests: XCTestCase {
    func testTheTiltEasesTowardThePointerAndNeverPassesIt() {
        let tilt = CardTilt()
        var last = CGPoint.zero

        for _ in 0..<200 { last = tilt.next(toward: CGPoint(x: 1, y: -1), at: 0) }

        XCTAssertEqual(last.x, 1, accuracy: 0.001)
        XCTAssertEqual(last.y, -1, accuracy: 0.001)
    }

    func testWithNoPointerTheSwayStaysWithinItsReach() {
        let tilt = CardTilt()

        let swayed = (0..<600).map { tilt.next(toward: nil, at: Double($0) / 60) }

        XCTAssertLessThanOrEqual(swayed.map { abs($0.x) }.max() ?? 0, MotionTokens.cardSwayReach.x)
        XCTAssertLessThanOrEqual(swayed.map { abs($0.y) }.max() ?? 0, MotionTokens.cardSwayReach.y)
    }
}
