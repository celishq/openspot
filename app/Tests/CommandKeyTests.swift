import XCTest
@testable import OpenspotCore

final class CommandKeyTests: XCTestCase {
    func testALetterHasItsKeyCode() {
        XCTAssertEqual(CommandKey(name: "d")?.code, 2)
        XCTAssertEqual(CommandKey(name: "D")?.code, 2)
        XCTAssertEqual(CommandKey(name: "D")?.name, "d")
    }

    func testADigitHasItsKeyCode() {
        XCTAssertEqual(CommandKey(name: "0")?.code, 29)
    }

    func testAnythingElseIsNotAKey() {
        XCTAssertNil(CommandKey(name: "ctrl+d"))
        XCTAssertNil(CommandKey(name: ""))
        XCTAssertNil(CommandKey(name: "é"))
    }
}
