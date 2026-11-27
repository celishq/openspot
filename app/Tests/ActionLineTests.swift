import XCTest
@testable import OpenspotCore

final class ActionLineTests: XCTestCase {
    func testALineSplitsIntoWordsByShellQuoting() {
        let lines = [
            "clipboard copy --text 'rgb(255 0 0)'",
            "clipboard copy --text \"say \\\"hi\\\"\"",
            "toast it\\'s  done",
            "run colors/rename",
            "clipboard copy --text 'it'\\''s'",
            "toast 'open",
            "   ",
        ]

        XCTAssertEqual(lines.map { ActionLine(text: $0)?.words }, [
            ["clipboard", "copy", "--text", "rgb(255 0 0)"],
            ["clipboard", "copy", "--text", "say \"hi\""],
            ["toast", "it's", "done"],
            ["run", "colors/rename"],
            ["clipboard", "copy", "--text", "it's"],
            nil,
            nil,
        ])
    }

    func testAWordQuotedForALineReadsBackTheSame() {
        let words = ["clipboard", "copy", "--text", "it's \"a\" \\ test"]

        XCTAssertEqual(ActionLine(text: ActionLine.text(of: words))?.words, words)
    }
}
