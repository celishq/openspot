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

    func testWritesTheHeldModifiersAndTheKeyApart() {
        XCTAssertEqual(Shortcut.Modifiers([.command, .option, .control]).marks, "⌃⌥⌘")
        XCTAssertEqual(Shortcut.Modifiers.shift.marks, "⇧")
        XCTAssertEqual(Shortcut.Modifiers().marks, "")
        XCTAssertEqual(Shortcut(text: "option+space")?.keyLabel, "Space")
        XCTAssertEqual(Shortcut(text: "ctrl+return")?.keyLabel, "⏎")
        XCTAssertEqual(Shortcut(text: "cmd+shift+k")?.keyLabel, "K")
    }

    func testReadsAPressByItsPlaceOnTheKeyboard() {
        XCTAssertEqual(Shortcut(code: 49, modifiers: [.option]), Shortcut(text: "option+space"))
        XCTAssertEqual(Shortcut(code: 17, modifiers: [.command, .shift]), Shortcut(text: "cmd+shift+t"))
        XCTAssertNil(Shortcut(code: 49, modifiers: [.shift]))
        XCTAssertNil(Shortcut(code: 999, modifiers: [.control]))
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

    func testAKeyIsFoundByItsCode() {
        XCTAssertEqual(KeyCode(code: 17)?.name, "t")
        XCTAssertNil(KeyCode(code: 49))
    }

    func testEachSignKeyMakesAShortcutByItsPlaceOnTheKeyboard() throws {
        let signs: [(code: UInt32, name: String)] = [
            (27, "-"), (24, "="), (33, "["), (30, "]"), (41, ";"), (39, "'"), (43, ","), (47, "."), (44, "/"), (42, "\\"), (50, "`")
        ]
        for sign in signs {
            let shortcut = try XCTUnwrap(Shortcut(code: sign.code, modifiers: .option), sign.name)
            XCTAssertEqual(shortcut.text, "option+\(sign.name)")
            XCTAssertEqual(shortcut.label, "⌥\(sign.name)")
            XCTAssertEqual(Shortcut(text: "option+\(sign.name)"), shortcut)
            XCTAssertEqual(Shortcut.keyLabel(of: sign.code), sign.name)
        }
        XCTAssertNil(Shortcut(code: 27, modifiers: .shift))
    }

    func testASignKeyIsKeptInTheConfigAndReadBack() throws {
        for text in ["ctrl+option+-", "option+/", "ctrl+\\", "option+,"] {
            let config = Config(text: "panel-key = \(ConfigDocument.Value.string(text).text)\n")
            XCTAssertEqual(config.panelKey, Shortcut(text: text), text)
            XCTAssertEqual(config.faults, [], text)
        }
    }
}
