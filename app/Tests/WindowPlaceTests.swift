import XCTest
@testable import OpenspotCore

final class WindowPlaceTests: XCTestCase {
    private let area = CGRect(x: 0, y: 25, width: 1200, height: 900)

    func testAWindowThatTakesItsSizeStaysOnTheTarget() {
        let place = WindowPlace(target: CGRect(x: 210, y: 183, width: 780, height: 585), area: area)

        XCTAssertEqual(place.origin(for: CGSize(width: 780, height: 585)), CGPoint(x: 210, y: 183))
    }

    func testAWindowThatKeepsItsOwnSizeHoldsTheEdgeOfTheAreaItTouches() {
        let left = WindowPlace(target: CGRect(x: 0, y: 25, width: 600, height: 900), area: area)
        let right = WindowPlace(target: CGRect(x: 600, y: 25, width: 600, height: 900), area: area)
        let full = WindowPlace(target: area, area: area)

        XCTAssertEqual(left.origin(for: CGSize(width: 700, height: 800)), CGPoint(x: 0, y: 25))
        XCTAssertEqual(right.origin(for: CGSize(width: 700, height: 800)), CGPoint(x: 500, y: 25))
        XCTAssertEqual(full.origin(for: CGSize(width: 1000, height: 800)), CGPoint(x: 0, y: 25))
    }

    func testAWindowThatKeepsItsOwnSizeStaysCentredOnATargetThatTouchesNoEdge() {
        let place = WindowPlace(target: CGRect(x: 210, y: 183, width: 780, height: 585), area: area)

        XCTAssertEqual(place.origin(for: CGSize(width: 700, height: 500)), CGPoint(x: 250, y: 226))
    }
}
