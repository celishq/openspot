import XCTest
@testable import OpenspotCore

final class CardPushTests: XCTestCase {
    func testAFadeRunsFromTheFirstPlaceToTheCentreCrossingTheBounds() {
        let push = CardPush(from: CGRect(x: 0, y: 0, width: 100, height: 50), by: CGSize(width: 200, height: 0))
        XCTAssertEqual(push.fade(within: CGRect(x: -500, y: -500, width: 650, height: 1000)), 0...0.5)
    }

    func testACardThatStaysInsideTheBoundsHasNoFade() {
        let push = CardPush(from: CGRect(x: 0, y: 0, width: 100, height: 50), by: CGSize(width: 20, height: 0))
        XCTAssertNil(push.fade(within: CGRect(x: -500, y: -500, width: 1000, height: 1000)))
    }
}
