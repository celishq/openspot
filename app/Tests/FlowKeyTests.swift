import XCTest
@testable import OpenspotCore

final class FlowKeyTests: XCTestCase {
    func testEachKeyOfTheFlowHasOneMove() {
        XCTAssertEqual(FlowKey(ActionKey(name: "[", isCommand: true)), .back)
        XCTAssertEqual(FlowKey(ActionKey(name: "]", isCommand: true)), .forward)
        XCTAssertEqual(FlowKey(ActionKey(name: "escape", isCommand: true)), .grid)
        XCTAssertNil(FlowKey(ActionKey(name: "[")))
        XCTAssertNil(FlowKey(ActionKey(name: "escape")))
    }
}
