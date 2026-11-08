import XCTest
@testable import OpenspotCore

final class SheetTransitionTests: XCTestCase {
    func testAMovingOpenLiesOnItsCardFirstThenOpens() {
        var transition = SheetTransition()
        transition.show("a", moves: true)
        XCTAssertEqual(transition.id, "a")
        XCTAssertEqual(transition.phase, .ready)
        XCTAssertFalse(transition.isOpen)
        transition.start()
        XCTAssertEqual(transition.phase, .opening)
        XCTAssertTrue(transition.isOpen)
        transition.finish(.opening)
        XCTAssertEqual(transition.phase, .open)
    }

    func testAStillOpenAndCloseHappenAtOnce() {
        var transition = SheetTransition()
        transition.show("a", moves: false)
        XCTAssertEqual(transition.phase, .open)
        transition.hide(moves: false)
        XCTAssertEqual(transition.phase, .closed)
        XCTAssertNil(transition.id)
    }

    func testAClosedSheetIsDroppedOnlyWhenItsCloseEnds() {
        var transition = SheetTransition()
        transition.show("a", moves: false)
        transition.hide(moves: true)
        XCTAssertEqual(transition.phase, .closing)
        XCTAssertEqual(transition.id, "a")
        transition.finish(.closing)
        XCTAssertEqual(transition.phase, .closed)
        XCTAssertNil(transition.id)
    }

    func testTheEndOfAnOldMotionChangesNothing() {
        var transition = SheetTransition()
        transition.show("a", moves: false)
        transition.hide(moves: true)
        transition.show("a", moves: true)
        transition.start()
        transition.finish(.closing)
        XCTAssertEqual(transition.phase, .opening)
        XCTAssertEqual(transition.id, "a")
    }

    func testAnotherSheetTakesThePlaceOfTheOpenOne() {
        var transition = SheetTransition()
        transition.show("a", moves: false)
        transition.show("b", moves: true)
        XCTAssertEqual(transition.id, "b")
        XCTAssertTrue(transition.isOpen)
    }

    func testAStartWithNothingReadyChangesNothing() {
        var transition = SheetTransition()
        transition.start()
        XCTAssertEqual(transition.phase, .closed)
    }
}
