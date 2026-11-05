import XCTest
@testable import OpenspotCore

final class ActionKeyTests: XCTestCase {
    func testReadsAKeyWithItsModifiers() {
        XCTAssertEqual(ActionKey(text: "cmd+shift+N"), ActionKey(name: "n", isCommand: true, isShift: true))
        XCTAssertEqual(ActionKey(text: "cmd+return"), ActionKey(name: "return", isCommand: true))
    }

    func testRefusesWhatItCannotRead() {
        XCTAssertNil(ActionKey(text: "ctrl+n"))
        XCTAssertNil(ActionKey(text: "cmd+space"))
        XCTAssertNil(ActionKey(text: ""))
    }

    func testWritesTheKeyAsTheMacDoes() {
        XCTAssertEqual(ActionKey(text: "cmd+return")?.label, "⌘⏎")
        XCTAssertEqual(ActionKey(text: "cmd+backspace")?.label, "⌘⌫")
        XCTAssertEqual(ActionKey(text: "cmd+shift+n")?.label, "⌘⇧N")
    }
}
