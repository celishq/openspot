import XCTest
@testable import OpenspotCore

/// Proves the table of the flow's keys: ⌘[ goes back, ⌘] forward and ⌘Esc to the grid, and no other key moves the flow.
final class FlowKeyTests: XCTestCase {
    func testEachKeyOfTheFlowHasOneMove() {
        XCTAssertEqual(FlowKey(ActionKey(name: "[", isCommand: true)), .back)
        XCTAssertEqual(FlowKey(ActionKey(name: "]", isCommand: true)), .forward)
        XCTAssertEqual(FlowKey(ActionKey(name: "escape", isCommand: true)), .grid)
        XCTAssertNil(FlowKey(ActionKey(name: "[")))
        XCTAssertNil(FlowKey(ActionKey(name: "escape")))
    }
}
