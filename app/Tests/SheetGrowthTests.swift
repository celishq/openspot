import XCTest
@testable import OpenspotCore

final class SheetGrowthTests: XCTestCase {
    private let growth = SheetGrowth(from: CGRect(x: 100, y: 100, width: 50, height: 50), to: CGRect(x: 0, y: 0, width: 300, height: 300))

    func testACardBesideTheOpenCardIsReachedEarly() {
        XCTAssertEqual(growth.reach(of: CGRect(x: 160, y: 100, width: 50, height: 50)), 1.0 / 15, accuracy: 0.001)
    }

    func testAFarCardIsReachedLate() {
        XCTAssertEqual(growth.reach(of: CGRect(x: 250, y: 100, width: 40, height: 50)), 2.0 / 3, accuracy: 0.001)
    }

    func testACardOffBothAxesWaitsForTheLaterEdge() {
        XCTAssertEqual(growth.reach(of: CGRect(x: 160, y: 250, width: 50, height: 40)), 2.0 / 3, accuracy: 0.001)
    }

    func testACardOutsideTheSheetIsReachedAtTheEnd() {
        XCTAssertEqual(growth.reach(of: CGRect(x: 400, y: 100, width: 50, height: 50)), 1)
    }

    func testTheOpenCardIsReachedAtOnce() {
        XCTAssertEqual(growth.reach(of: CGRect(x: 100, y: 100, width: 50, height: 50)), 0)
    }
}
