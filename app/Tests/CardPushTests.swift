import XCTest
@testable import OpenspotCore

final class CardPushTests: XCTestCase {
    private let bounds = CGRect(x: 0, y: 0, width: 300, height: 300)

    func testACardPushedRightLeavesWhenItsFarEdgeCrosses() {
        let push = CardPush(from: CGRect(x: 200, y: 100, width: 50, height: 50), by: CGSize(width: 100, height: 0))
        XCTAssertEqual(push.exit(from: bounds), 0.5, accuracy: 0.001)
    }

    func testACardPushedUpLeavesAtTheTop() {
        let push = CardPush(from: CGRect(x: 100, y: 40, width: 50, height: 50), by: CGSize(width: 0, height: -80))
        XCTAssertEqual(push.exit(from: bounds), 0.5, accuracy: 0.001)
    }

    func testACardThatStaysInsideNeverLeaves() {
        let push = CardPush(from: CGRect(x: 100, y: 100, width: 50, height: 50), by: CGSize(width: 40, height: 0))
        XCTAssertEqual(push.exit(from: bounds), 1)
    }

    func testACardThatStartsOutsideHasLeftAtOnce() {
        let push = CardPush(from: CGRect(x: 100, y: 280, width: 50, height: 50), by: CGSize(width: 0, height: 40))
        XCTAssertEqual(push.exit(from: bounds), 0)
    }

    func testAFadeRunsFromTheLeadingEdgeToTheCentreCrossingTheBounds() {
        let push = CardPush(from: CGRect(x: 0, y: 0, width: 100, height: 50), by: CGSize(width: 200, height: 0))
        XCTAssertEqual(push.fade(within: CGRect(x: -500, y: -500, width: 650, height: 1000)), 0.25...0.5)
    }

    func testACardThatStaysInsideTheBoundsHasNoFade() {
        let push = CardPush(from: CGRect(x: 0, y: 0, width: 100, height: 50), by: CGSize(width: 20, height: 0))
        XCTAssertNil(push.fade(within: CGRect(x: -500, y: -500, width: 1000, height: 1000)))
    }
}
