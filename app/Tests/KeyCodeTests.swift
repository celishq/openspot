import XCTest
@testable import OpenspotCore

final class KeyCodeTests: XCTestCase {
    func testALetterHasItsKeyCode() {
        XCTAssertEqual(KeyCode(name: "d")?.code, 2)
        XCTAssertEqual(KeyCode(name: "D")?.code, 2)
        XCTAssertEqual(KeyCode(name: "D")?.name, "d")
    }

    func testADigitHasItsKeyCode() {
        XCTAssertEqual(KeyCode(name: "0")?.code, 29)
    }

    func testAnythingElseIsNotAKey() {
        XCTAssertNil(KeyCode(name: "ctrl+d"))
        XCTAssertNil(KeyCode(name: ""))
        XCTAssertNil(KeyCode(name: "é"))
    }
}
