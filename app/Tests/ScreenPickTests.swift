import XCTest
@testable import OpenspotCore

final class ScreenPickTests: XCTestCase {
    private let displays = [
        ScreenPick.Item(id: 1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982)),
        ScreenPick.Item(id: 2, frame: CGRect(x: 1512, y: 0, width: 1920, height: 1080))
    ]
    private let windows = [
        ScreenPick.Item(id: 40, frame: CGRect(x: 100, y: 100, width: 400, height: 300)),
        ScreenPick.Item(id: 41, frame: CGRect(x: 50, y: 50, width: 900, height: 700))
    ]

    private func pick(_ source: ScreenSource) -> ScreenPick {
        ScreenPick(source: source, displays: displays, windows: windows)!
    }

    func testOnlyASourceWithNoValueIsPicked() {
        XCTAssertNotNil(ScreenPick(source: .any, displays: displays, windows: windows))
        XCTAssertNil(ScreenPick(source: .display(1), displays: displays, windows: windows))
        XCTAssertNil(ScreenPick(source: .window(.front), displays: displays, windows: windows))
    }

    func testAClickPicksTheFrontWindowUnderThePointer() {
        XCTAssertEqual(pick(.any).target(from: CGPoint(x: 200, y: 200), to: CGPoint(x: 201, y: 202)), .window(40))
        XCTAssertEqual(pick(.window(nil)).target(from: CGPoint(x: 60, y: 60), to: CGPoint(x: 60, y: 60)), .window(41))
        XCTAssertEqual(pick(.any).hover(at: CGPoint(x: 200, y: 200)), windows[0].frame)
    }

    func testAClickWhereNoWindowIsPicksTheDisplay() {
        XCTAssertEqual(pick(.any).target(from: CGPoint(x: 1300, y: 900), to: CGPoint(x: 1300, y: 900)), .display(1))
        XCTAssertEqual(pick(.display(nil)).target(from: CGPoint(x: 200, y: 200), to: CGPoint(x: 200, y: 200)), .display(1))
        XCTAssertEqual(pick(.display(nil)).hover(at: CGPoint(x: 2000, y: 10)), displays[1].frame)
        XCTAssertNil(pick(.window(nil)).target(from: CGPoint(x: 1300, y: 900), to: CGPoint(x: 1300, y: 900)))
    }

    func testADragPicksAnAreaOfWholePointsInEitherDirection() {
        XCTAssertEqual(pick(.any).target(from: CGPoint(x: 10.4, y: 20), to: CGPoint(x: 310.6, y: 220)), .area(CGRect(x: 10, y: 20, width: 301, height: 200)))
        XCTAssertEqual(pick(.area(nil)).target(from: CGPoint(x: 310, y: 220), to: CGPoint(x: 10, y: 20)), .area(CGRect(x: 10, y: 20, width: 300, height: 200)))
        XCTAssertEqual(pick(.area(nil)).area(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 310, y: 220)), CGRect(x: 10, y: 20, width: 300, height: 200))
    }

    func testADragStaysOnTheDisplayWhereItStarted() {
        XCTAssertEqual(pick(.area(nil)).target(from: CGPoint(x: 1400, y: 500), to: CGPoint(x: 1700, y: 1200)), .area(CGRect(x: 1400, y: 500, width: 112, height: 482)))
    }

    func testAClickInAnAreaPickOrADragInAWindowPickPicksNothing() {
        XCTAssertNil(pick(.area(nil)).target(from: CGPoint(x: 200, y: 200), to: CGPoint(x: 201, y: 200)))
        XCTAssertNil(pick(.window(nil)).target(from: CGPoint(x: 200, y: 200), to: CGPoint(x: 400, y: 300)))
        XCTAssertNil(pick(.window(nil)).area(from: CGPoint(x: 200, y: 200), to: CGPoint(x: 400, y: 300)))
    }
}
