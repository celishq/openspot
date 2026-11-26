import XCTest
@testable import OpenspotCore

final class StoreCarryTests: XCTestCase {
    func testTheCardCentresOnThePointerAndLandsOnlyInsideTheTarget() {
        var carry = StoreCarry(id: "clock", size: .wide, point: CGPoint(x: 100, y: 100))
        let target = CGRect(x: 0, y: 0, width: 200, height: 40)

        carry.move(to: CGPoint(x: 300, y: 200))
        XCTAssertEqual(carry.frame.midX, 300)
        XCTAssertEqual(carry.frame.midY, 200)
        XCTAssertEqual(carry.frame.size, CGSize(width: SpotTokens.width(columns: SpotSize.wide.columns), height: SpotTokens.height(rows: SpotSize.wide.rows)))
        XCTAssertFalse(carry.lands(on: target))
        carry.move(to: CGPoint(x: 20, y: 20))

        XCTAssertTrue(carry.lands(on: target))
        XCTAssertFalse(carry.lands(on: nil))
    }

    func testTheCardKeepsThePointOfItWhereItWasGrabbed() {
        let carry = StoreCarry(id: "clock", size: .wide, point: CGPoint(x: 300, y: 200), grab: CGPoint(x: 0.25, y: 0.75))

        XCTAssertEqual(carry.frame.minX + carry.frame.width / 4, 300)
        XCTAssertEqual(carry.frame.minY + carry.frame.height * 3 / 4, 200)
    }
}
