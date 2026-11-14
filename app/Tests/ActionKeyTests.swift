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

    func test_A17_aCommandKeyOnANonLatinLayoutGoesByTheLatinLetterOfTheSameKey() {
        let latin = KeyLayout(keys: [14: "e", 45: "n"])
        XCTAssertEqual(ActionKey(typed: "у", code: 14, isCommand: true, isShift: false, latin: latin), ActionKey(name: "e", isCommand: true))
        XCTAssertEqual(ActionKey(typed: "Т", code: 45, isCommand: true, isShift: true, latin: latin), ActionKey(name: "n", isCommand: true, isShift: true))
    }

    func testACommandKeyOnALatinLayoutKeepsItsOwnLetter() {
        let latin = KeyLayout(keys: [12: "q"])
        XCTAssertEqual(ActionKey(typed: "a", code: 12, isCommand: true, isShift: false, latin: latin), ActionKey(name: "a", isCommand: true))
    }

    func testAKeyWithNoCommandTypesItsOwnLetter() {
        let latin = KeyLayout(keys: [17: "t"])
        XCTAssertEqual(ActionKey(typed: "е", code: 17, isCommand: false, isShift: false, latin: latin), ActionKey(name: "е"))
    }

    func testACommandKeyWithNoLatinLayoutKeepsItsOwnLetter() {
        XCTAssertEqual(ActionKey(typed: "у", code: 14, isCommand: true, isShift: false, latin: nil), ActionKey(name: "у", isCommand: true))
    }

    func testWritesTheKeyAsTheMacDoes() {
        XCTAssertEqual(ActionKey(text: "cmd+return")?.label, "⌘⏎")
        XCTAssertEqual(ActionKey(text: "cmd+backspace")?.label, "⌘⌫")
        XCTAssertEqual(ActionKey(text: "cmd+shift+n")?.label, "⌘⇧N")
    }
}
