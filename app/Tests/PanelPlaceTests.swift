import XCTest
@testable import OpenspotCore

/// Proves where the panel opens (A18), with the screens of a Mac whose second screen lies to the left of the main one.
final class PanelPlaceTests: XCTestCase {
    private let main = PanelPlace.Screen(frame: CGRect(x: 0, y: 0, width: 1496, height: 967), area: CGRect(x: 0, y: 86, width: 1496, height: 852))
    private let left = PanelPlace.Screen(frame: CGRect(x: -2560, y: -288, width: 2560, height: 1440), area: CGRect(x: -2560, y: -288, width: 2560, height: 1410))
    private let size = CGSize(width: 640, height: 720)

    private var place: PanelPlace {
        PanelPlace(screens: [main, left])
    }

    func testAFloatCentresOnThePointerAndStaysWholeOnItsScreen() {
        let float = CGSize(width: 289, height: 200)

        XCTAssertEqual(place.origin(of: float, under: CGPoint(x: 700, y: 500)), CGPoint(x: 555, y: 400))
        XCTAssertEqual(place.origin(of: float, under: CGPoint(x: 1490, y: 960)), CGPoint(x: 1207, y: 738))
        XCTAssertEqual(place.origin(of: float, under: CGPoint(x: -2550, y: -280)), CGPoint(x: -2560, y: -288))
    }

    func testThePanelSitsAsACentredWindowSits() {
        XCTAssertEqual(PanelPlace(screens: [main]).origin(of: size, window: nil, pointer: CGPoint(x: 10, y: 10)), CGPoint(x: 428, y: 185))
    }

    func testThePanelOpensOnTheScreenOfTheFrontWindow() {
        let window = CGRect(x: -2000, y: 100, width: 800, height: 600)

        XCTAssertEqual(place.origin(of: size, window: window, pointer: CGPoint(x: 10, y: 10)), CGPoint(x: -1600, y: 229))
    }

    func testAWindowOnTwoScreensTakesTheScreenThatHoldsMoreOfIt() {
        let window = CGRect(x: -300, y: 100, width: 1000, height: 600)

        XCTAssertEqual(place.origin(of: size, window: window, pointer: CGPoint(x: -1000, y: 10)), CGPoint(x: 428, y: 185))
    }

    func testWithNoWindowThePanelOpensOnTheScreenOfThePointer() {
        XCTAssertEqual(place.origin(of: size, window: nil, pointer: CGPoint(x: -1000, y: 10)), CGPoint(x: -1600, y: 229))
    }

    func testAPointerOffEveryScreenTakesTheMainScreen() {
        XCTAssertEqual(place.origin(of: size, window: nil, pointer: CGPoint(x: 9000, y: 9000)), CGPoint(x: 428, y: 185))
    }

    func testAWindowFrameCountsFromTheBottomLeftOfTheMainScreen() {
        let bounds = CGRect(x: -2000, y: 100, width: 800, height: 600)

        XCTAssertEqual(PanelPlace.frame(ofBounds: bounds, mainHeight: 967), CGRect(x: -2000, y: 267, width: 800, height: 600))
    }
}
