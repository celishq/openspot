import XCTest
@testable import OpenspotCore

final class HexColorTests: XCTestCase {
    func testWritesTwoDigitsForEachPart() {
        XCTAssertEqual(HexColor(red: 0, green: 0.5, blue: 1).text, "#0080FF")
        XCTAssertEqual(HexColor(red: 0.04, green: 0, blue: 0).text, "#0A0000")
    }

    func testAPartOutsideTheRangeStopsAtItsEnd() {
        XCTAssertEqual(HexColor(red: -1, green: 2, blue: 0).text, "#00FF00")
    }
}
