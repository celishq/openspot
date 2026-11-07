import XCTest
@testable import OpenspotCore

final class ShortcutTests: XCTestCase {
    func testReadsAKeyWithItsModifiers() throws {
        let shortcut = try XCTUnwrap(Shortcut(text: "Option+Shift+Space"))

        XCTAssertEqual(shortcut.modifiers, [.option, .shift])
        XCTAssertEqual(shortcut.name, "space")
        XCTAssertEqual(shortcut.code, 49)
    }

    func testRefusesAKeyThatWouldTakeOverTyping() {
        XCTAssertNil(Shortcut(text: "k"))
        XCTAssertNil(Shortcut(text: "shift+k"))
        XCTAssertNil(Shortcut(text: "space"))
    }

    func testRefusesWhatItCannotRead() {
        XCTAssertNil(Shortcut(text: ""))
        XCTAssertNil(Shortcut(text: "ctrl+"))
        XCTAssertNil(Shortcut(text: "ctrl"))
        XCTAssertNil(Shortcut(text: "hyper+k"))
        XCTAssertNil(Shortcut(text: "ctrl+wave"))
    }

    func testWritesOneTextForEachOrderOfModifiers() {
        XCTAssertEqual(Shortcut(text: "shift+ctrl+K")?.text, "ctrl+shift+k")
        XCTAssertEqual(Shortcut(text: "shift+ctrl+K"), Shortcut(text: "ctrl+shift+k"))
    }

    func testWritesTheKeyAsTheMacDoes() {
        XCTAssertEqual(Shortcut(text: "ctrl+space")?.label, "⌃Space")
        XCTAssertEqual(Shortcut(text: "cmd+option+shift+ctrl+k")?.label, "⌃⌥⇧⌘K")
    }

    func testReadsAPressByItsPlaceOnTheKeyboard() {
        XCTAssertEqual(Shortcut(code: 49, modifiers: [.option]), Shortcut(text: "option+space"))
        XCTAssertEqual(Shortcut(code: 17, modifiers: [.command, .shift]), Shortcut(text: "cmd+shift+t"))
        XCTAssertNil(Shortcut(code: 49, modifiers: [.shift]))
        XCTAssertNil(Shortcut(code: 999, modifiers: [.control]))
    }

    func testAChainHoldsTheSameModifiersAndPressesTheLetterOfASpot() throws {
        let entry = try XCTUnwrap(Shortcut(text: "option+space"))
        let letter = try XCTUnwrap(CommandKey(name: "t"))

        XCTAssertTrue(entry.chains(to: letter, code: 17, modifiers: [.option]))
        XCTAssertFalse(entry.chains(to: letter, code: 17, modifiers: [.control]))
        XCTAssertFalse(entry.chains(to: letter, code: 17, modifiers: [.option, .shift]))
        XCTAssertFalse(entry.chains(to: letter, code: 17, modifiers: []))
        XCTAssertFalse(entry.chains(to: letter, code: 0, modifiers: [.option]))
    }

    func testReadsAnArrowKey() throws {
        let shortcut = try XCTUnwrap(Shortcut(text: "ctrl+option+left"))

        XCTAssertEqual(shortcut.code, 123)
        XCTAssertEqual(Shortcut(text: "ctrl+right")?.code, 124)
        XCTAssertEqual(Shortcut(text: "ctrl+down")?.code, 125)
        XCTAssertEqual(Shortcut(text: "ctrl+up")?.code, 126)
        XCTAssertEqual(shortcut.label, "⌃⌥Left")
        XCTAssertEqual(Shortcut(code: 126, modifiers: [.control]), Shortcut(text: "ctrl+up"))
    }

    func testTheEntryKeyStartsAsControlSpace() {
        XCTAssertEqual(Shortcut.standard.text, "ctrl+space")
    }

    func testAKeyIsFoundByItsCode() {
        XCTAssertEqual(CommandKey(code: 17)?.name, "t")
        XCTAssertNil(CommandKey(code: 49))
    }
}
