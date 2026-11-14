import XCTest
@testable import OpenspotCore

final class FocusLossTests: XCTestCase {
    func testALossWithNoPressClosesAtOnce() {
        let loss = FocusLoss(dragCount: 4)
        XCTAssertEqual(loss.step(isPressed: false, dragCount: 4, holdsFiles: false), .close)
    }

    func testAPressWithNoDragWaits() {
        let loss = FocusLoss(dragCount: 4)
        XCTAssertEqual(loss.step(isPressed: true, dragCount: 4, holdsFiles: false), .wait)
    }

    func test_D7_aPressThatEndsWithNoDragCloses() {
        let loss = FocusLoss(dragCount: 4)
        XCTAssertEqual(loss.step(isPressed: false, dragCount: 4, holdsFiles: true), .close)
    }

    func test_D7_aDragOfFilesThatThePressStartsKeepsThePanelForTheDrag() {
        let loss = FocusLoss(dragCount: 4)
        XCTAssertEqual(loss.step(isPressed: true, dragCount: 5, holdsFiles: true), .followDrag)
    }

    func testTheFilesOfAnEarlierDragDoNotKeepThePanel() {
        let loss = FocusLoss(dragCount: 4)
        XCTAssertEqual(loss.step(isPressed: true, dragCount: 4, holdsFiles: true), .wait)
    }

    func testADragOfNoFilesWaitsThenClosesAsThePressEnds() {
        let loss = FocusLoss(dragCount: 4)
        XCTAssertEqual(loss.step(isPressed: true, dragCount: 5, holdsFiles: false), .wait)
        XCTAssertEqual(loss.step(isPressed: false, dragCount: 5, holdsFiles: false), .close)
    }

    func testADragThatEndedBeforeItWasSeenCloses() {
        let loss = FocusLoss(dragCount: 4)
        XCTAssertEqual(loss.step(isPressed: false, dragCount: 5, holdsFiles: true), .close)
    }
}
