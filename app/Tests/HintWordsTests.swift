import XCTest
@testable import OpenspotCore

final class HintWordsTests: XCTestCase {
    private func groups(_ text: String) -> [String] {
        HintWords(text).groups.map { group in
            [group.key.map { "[\($0)]" }, group.words.isEmpty ? nil : group.words].compactMap { $0 }.joined(separator: " ")
        }
    }

    func testAKeyStaysWithItsWords() {
        XCTAssertEqual(groups("Esc Close"), ["[Esc] Close"])
        XCTAssertEqual(groups("⌘K Actions"), ["[⌘K] Actions"])
        XCTAssertEqual(groups("⌘N New plugin"), ["[⌘N] New plugin"])
    }

    func testEachGroupHasItsOwnKey() {
        XCTAssertEqual(groups("↩ Open   ⌘K Actions   Esc Close"), ["[↩] Open", "[⌘K] Actions", "[Esc] Close"])
    }

    func testTheTitleOfASpotIsAGroupWithNoKey() {
        XCTAssertEqual(groups("Translate  ↩ Open"), ["Translate", "[↩] Open"])
    }

    func testASingleLetterIsAKeyOnlyWithWordsAfterIt() {
        XCTAssertEqual(groups("S Size   H Hide"), ["[S] Size", "[H] Hide"])
        XCTAssertEqual(groups("X  Esc Close"), ["X", "[Esc] Close"])
    }

    func testASentenceThatEndsInAKeyStaysWords() {
        XCTAssertEqual(groups("Nothing runs until you press ⌘⏎"), ["Nothing runs until you press ⌘⏎"])
    }

    func testNoTextHasNoGroups() {
        XCTAssertEqual(groups(""), [])
    }
}
