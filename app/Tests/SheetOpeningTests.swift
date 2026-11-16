import XCTest
@testable import OpenspotCore

@MainActor
final class SheetOpeningTests: XCTestCase {
    func testTheHeldContentWaitsForASlowMotionTurnedOnWhileTheAppRuns() {
        let opening = SheetOpening()
        let normal = opening.motionLength
        MotionTokens.toggleSlowMotion()
        defer { MotionTokens.toggleSlowMotion() }

        XCTAssertEqual(opening.motionLength, normal * MotionTokens.slowMotion, accuracy: 0.001)
    }
}
