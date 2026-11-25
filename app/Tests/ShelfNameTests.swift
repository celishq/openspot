import XCTest
@testable import OpenspotCore

final class ShelfNameTests: XCTestCase {
    func testANameBreaksOnlyBetweenWordsWithTheLongestFirstLineFirst() {
        let name = ShelfName("Paste latest screenshot")

        XCTAssertEqual(name.breaks, [ShelfName.Break(first: "Paste latest", rest: "screenshot"), ShelfName.Break(first: "Paste", rest: "latest screenshot")])
    }

    func testAOneWordNameHasNoBreak() {
        XCTAssertEqual(ShelfName("Caffeinate").breaks, [])
        XCTAssertEqual(ShelfName("Emojis  &   Symbols").breaks.map(\.first), ["Emojis &", "Emojis"])
    }
}
