import XCTest
@testable import OpenspotCore

/// Proves what the panel does when another app takes the focus (D7): it closes at once with no press, waits while a press
/// lasts, closes as the press ends, and stays for a drag of files that the press starts.
final class FocusLossTests: XCTestCase {
    func testALossWithNoPressClosesAtOnce() {
        let loss = FocusLoss(dragCount: 4)
        XCTAssertEqual(loss.step(isPressed: false, dragCount: 4, holdsFiles: false), .close)
    }

    func testAPressWithNoDragWaits() {
        let loss = FocusLoss(dragCount: 4)
        XCTAssertEqual(loss.step(isPressed: true, dragCount: 4, holdsFiles: false), .wait)
    }

    func testAPressThatEndsWithNoDragCloses() {
        let loss = FocusLoss(dragCount: 4)
        XCTAssertEqual(loss.step(isPressed: false, dragCount: 4, holdsFiles: true), .close)
    }

    func testADragOfFilesThatThePressStartsKeepsThePanelForTheDrag() {
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
