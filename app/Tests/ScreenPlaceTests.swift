import XCTest
@testable import OpenspotCore

final class ScreenPlaceTests: XCTestCase {
    private let main = ScreenPlace.Screen(frame: CGRect(x: 0, y: 0, width: 1496, height: 967), area: CGRect(x: 0, y: 86, width: 1496, height: 852))
    private let left = ScreenPlace.Screen(frame: CGRect(x: -2560, y: -288, width: 2560, height: 1440), area: CGRect(x: -2560, y: -288, width: 2560, height: 1410))
    private let size = CGSize(width: 640, height: 720)
    private let toast = CGSize(width: 200, height: 68)
    private let item = CGRect(x: 1000, y: 938, width: 33, height: 29)
    private let pointer = CGPoint(x: 10, y: 10)
    private let window = CGRect(x: -2000, y: 100, width: 800, height: 600)

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
        XCTAssertEqual(place.origin(ofToast: toast, inset: 16, under: item, window: nil, pointer: pointer), CGPoint(x: 916, y: 876))
    }

    func testAToastUnderAnItemNearTheEdgeStaysWholeOnTheScreen() {
        XCTAssertEqual(place.origin(ofToast: toast, inset: 16, under: CGRect(x: 1450, y: 938, width: 33, height: 29), window: nil, pointer: pointer), CGPoint(x: 1296, y: 876))
    }

    func testAToastWithNoItemToHangFromSitsAtTheTopCentreOfTheMainScreen() {
        XCTAssertEqual(place.origin(ofToast: toast, inset: 16, under: nil, window: nil, pointer: pointer), CGPoint(x: 648, y: 876))
    }

    func testAToastHangsUnderTheItemsPlaceInTheMenuBarOfTheFrontWindowsScreen() {
        XCTAssertEqual(place.origin(ofToast: toast, inset: 16, under: item, window: window, pointer: pointer), CGPoint(x: -580, y: 1060))
    }

    func testWithNoWindowAToastHangsInTheMenuBarOfThePointersScreen() {
        XCTAssertEqual(place.origin(ofToast: toast, inset: 16, under: item, window: nil, pointer: CGPoint(x: -1000, y: 10)), CGPoint(x: -580, y: 1060))
    }

    func testAToastWithNoItemSitsAtTheTopCentreOfTheFrontWindowsScreen() {
        XCTAssertEqual(place.origin(ofToast: toast, inset: 16, under: nil, window: window, pointer: pointer), CGPoint(x: -1380, y: 1060))
    }

    func testAToastShowsOverThePanelWhileItShows() {
        let panel = CGRect(x: -1600, y: 229, width: 640, height: 720)

        XCTAssertEqual(ScreenPlace.toastWindow(panel: panel, isPanelShown: true, isAppInFront: true, front: { self.item }), panel)
    }

    func testAToastShowsOverTheFrontWindowOnceThePanelCloses() {
        let panel = CGRect(x: 428, y: 185, width: 640, height: 720)

        XCTAssertEqual(ScreenPlace.toastWindow(panel: panel, isPanelShown: false, isAppInFront: false, front: { self.window }), window)
        XCTAssertEqual(ScreenPlace.toastWindow(panel: panel, isPanelShown: false, isAppInFront: true, front: { self.window }), window)
    }

    func testAToastShowsOverThePanelThatClosedWhileOpenspotIsInFrontWithNoWindow() {
        let panel = CGRect(x: -1600, y: 229, width: 640, height: 720)

        XCTAssertEqual(ScreenPlace.toastWindow(panel: panel, isPanelShown: false, isAppInFront: true, front: { nil }), panel)
        XCTAssertNil(ScreenPlace.toastWindow(panel: panel, isPanelShown: false, isAppInFront: false, front: { nil }))
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
}
