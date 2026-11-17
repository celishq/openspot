import XCTest
@testable import OpenspotCore

final class ViewThemeTests: XCTestCase {
    func testAViewTakesTheSpaceRadiiAndPressOfItsTheme() {
        let theme = Theme(text: """
        [look]
        corner = 30

        [advanced]
        cell = 70
        column-gap = 10
        padding = 20
        list-row = 44
        media-corner = 9
        press = 0.3
        press-bounce = 0.4
        """)

        let numbers = self.numbers(of: theme, corner: 30)

        XCTAssertEqual(numbers["padding"], 20)
        XCTAssertEqual(numbers["columnGap"], 10)
        XCTAssertEqual(numbers["rowGap"], 12)
        XCTAssertEqual(numbers["listRow"], 44)
        XCTAssertEqual(numbers["listRowGap"], 6)
        XCTAssertEqual(numbers["glyph"], 36)
        XCTAssertEqual(numbers["cell"], 70)
        XCTAssertEqual(numbers["gridWidth"], 4 * 70 + 3 * 10)
        XCTAssertEqual(numbers["card"], 30)
        XCTAssertEqual(numbers["media"], 9)
        XCTAssertEqual(numbers["inner"], 10)
        XCTAssertEqual(numbers["press"], 0.3)
        XCTAssertEqual(numbers["pressBounce"], 0.4)
    }

    func testAPartInsideARoundCornerTakesNoRadiusBelowZero() {
        XCTAssertEqual(numbers(of: Theme(), corner: 8)["inner"], 0)
    }

    func testThePreludeReadsEachKeyOfTheThemeAndNoOther() throws {
        let prelude = ViewLibrary.prelude
        let start = try XCTUnwrap(prelude.range(of: "public struct SpotTheme {"))
        let end = try XCTUnwrap(prelude.range(of: "public enum SpotCard", range: start.upperBound..<prelude.endIndex))
        let reads = String(prelude[start.upperBound..<end.lowerBound])
        let pattern = try NSRegularExpression(pattern: #"(?:number|strength|color|font)\("([A-Za-z]+)"\)"#)
        let read = pattern.matches(in: reads, range: NSRange(reads.startIndex..., in: reads)).compactMap { Range($0.range(at: 1), in: reads).map { String(reads[$0]) } }

        XCTAssertEqual(read.count, Set(read).count)
        XCTAssertEqual(Set(read), Set(theme(of: Theme(), corner: 20).keys))
    }

    private func theme(of theme: Theme, corner: CGFloat) -> [String: Any] {
        ViewTheme(layout: theme.layout, look: theme.colours.dark, corner: corner, colour: { $0 }, face: { $0 }).values
    }

    private func numbers(of theme: Theme, corner: CGFloat) -> [String: CGFloat] {
        self.theme(of: theme, corner: corner).compactMapValues { $0 as? CGFloat }
    }
}
