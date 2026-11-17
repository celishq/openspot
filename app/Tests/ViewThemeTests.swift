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

        let numbers = ViewTheme(sizes: SpotSizes(theme.layout), motion: theme.layout.motion, corner: 30).numbers

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
        XCTAssertEqual(ViewTheme(sizes: SpotSizes(Theme.Layout()), motion: Theme.Motion(), corner: 8).numbers["inner"], 0)
    }
}
