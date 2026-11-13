import XCTest
@testable import OpenspotCore

/// Proves where the panel and a float open (A18, W4), with the screens of a Mac whose second screen lies to the left of the main one.
final class ScreenPlaceTests: XCTestCase {
    private let main = ScreenPlace.Screen(frame: CGRect(x: 0, y: 0, width: 1496, height: 967), area: CGRect(x: 0, y: 86, width: 1496, height: 852))
    private let left = ScreenPlace.Screen(frame: CGRect(x: -2560, y: -288, width: 2560, height: 1440), area: CGRect(x: -2560, y: -288, width: 2560, height: 1410))
    private let size = CGSize(width: 640, height: 720)

    private var place: ScreenPlace {
        ScreenPlace(screens: [main, left])
    }

    func testAFloatCentresOnThePointerAndStaysWholeOnItsScreen() {
        let float = CGSize(width: 289, height: 200)

        XCTAssertEqual(place.origin(of: float, under: CGPoint(x: 700, y: 500)), CGPoint(x: 555, y: 400))
        XCTAssertEqual(place.origin(of: float, under: CGPoint(x: 1490, y: 960)), CGPoint(x: 1207, y: 738))
        XCTAssertEqual(place.origin(of: float, under: CGPoint(x: -2550, y: -280)), CGPoint(x: -2560, y: -288))
    }

    func testAToastHangsCentredUnderTheMenuBarItemAsHighAsTheSystemHUD() {
        let toast = CGSize(width: 200, height: 68)

        XCTAssertEqual(place.origin(ofToast: toast, inset: 16, under: CGRect(x: 1000, y: 938, width: 33, height: 29)), CGPoint(x: 916, y: 876))
    }

    func testAToastUnderAnItemNearTheEdgeStaysWholeOnTheScreen() {
        let toast = CGSize(width: 200, height: 68)

        XCTAssertEqual(place.origin(ofToast: toast, inset: 16, under: CGRect(x: 1450, y: 938, width: 33, height: 29)), CGPoint(x: 1296, y: 876))
    }

    func testAToastWithNoItemToHangFromSitsAtTheTopCentreOfTheMainScreen() {
        let toast = CGSize(width: 200, height: 68)

        XCTAssertEqual(place.origin(ofToast: toast, inset: 16, under: nil), CGPoint(x: 648, y: 876))
    }

    func testThePanelSitsAsACentredWindowSits() {
        XCTAssertEqual(ScreenPlace(screens: [main]).origin(of: size, window: nil, pointer: CGPoint(x: 10, y: 10)), CGPoint(x: 428, y: 185))
    }

    func testWithOneScreenThePanelOpensThereWhereverTheWindowIs() {
        let one = ScreenPlace(screens: [main])
        let alone = one.origin(of: size, window: nil, pointer: CGPoint(x: 10, y: 10))

        XCTAssertEqual(one.origin(of: size, window: CGRect(x: 100, y: 100, width: 800, height: 600), pointer: CGPoint(x: 10, y: 10)), alone)
        XCTAssertEqual(one.origin(of: size, window: CGRect(x: -2000, y: 100, width: 800, height: 600), pointer: CGPoint(x: 9000, y: 9000)), alone)
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

        XCTAssertEqual(ScreenPlace.frame(ofBounds: bounds, mainHeight: 967), CGRect(x: -2000, y: 267, width: 800, height: 600))
    }

    func testEditSpotsLiftsThePanelToTheTopAndTheStoreFillsTheAreaUnderIt() {
        let area = CGRect(x: 0, y: 0, width: 1440, height: 875)
        let panel = CGRect(x: 575, y: 400, width: 289, height: 385)

        let place = ScreenPlace.edit(under: panel, in: area)

        XCTAssertEqual(place.lift, 90)
        XCTAssertEqual(place.dock, CGRect(x: 262, y: 20, width: SpotTokens.dockWidth, height: 490 - 40))
    }

    func testTheStoreKeepsOneLineOfRowsUnderATallPanel() {
        let area = CGRect(x: 0, y: 0, width: 1440, height: 875)

        XCTAssertEqual(ScreenPlace.edit(under: CGRect(x: 575, y: 50, width: 289, height: 825), in: area).dock.height, SpotTokens.dockHeight(rows: 1))
    }

    func testTheStoreStaysWholeOnItsScreen() {
        let panel = CGRect(x: 690, y: 400, width: 289, height: 300)

        XCTAssertEqual(ScreenPlace.edit(under: panel, in: CGRect(x: 0, y: 0, width: 1000, height: 800)).dock.minX, 65)
    }
}
