import XCTest
@testable import OpenspotCore

final class SlashCommandTests: XCTestCase {
    private func parse(_ query: String) -> [String]? {
        SlashCommand(query).map { [$0.word, $0.text] }
    }

    func testAQueryGivesItsCommandAndItsText() {
        let table: [(String, [String]?)] = [
            ("/tr", ["tr", ""]),
            ("/translate hello world", ["translate", "hello world"]),
            ("hello world /translate", ["translate", "hello world"]),
            ("hello /translate world", ["translate", "hello world"]),
            ("  /notes   buy  milk  ", ["notes", "buy  milk"]),
            ("/my-spot.v2 x", ["my-spot.v2", "x"]),
            ("10/2", nil),
            ("and/or", nil),
            ("/Users/tony", nil),
            ("/", nil),
            ("/ hello", nil),
            ("/2", nil),
            ("hello world", nil),
            ("", nil),
        ]
        for (query, expected) in table {
            XCTAssertEqual(parse(query), expected, query)
        }
    }

    func testTheLeadAndTheTailAreTheTextAroundTheCommandWordAsTyped() {
        XCTAssertEqual(SlashCommand("hello  /tr x ")?.lead, "hello  ")
        XCTAssertEqual(SlashCommand("hello  /tr x ")?.tail, " x ")
        XCTAssertEqual(SlashCommand("/tr")?.lead, "")
        XCTAssertEqual(SlashCommand("/tr")?.tail, "")
    }

    func testTheFirstCommandWordIsTheCommandAndALaterOneIsText() {
        XCTAssertEqual(parse("/a /b c"), ["a", "/b c"])
    }
}
