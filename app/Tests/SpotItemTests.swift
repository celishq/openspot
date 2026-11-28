import XCTest
@testable import OpenspotCore

final class SpotItemTests: XCTestCase {
    func testAPlainRowTakesAFewWords() {
        XCTAssertLessThanOrEqual(MemoryLayout<SpotItem>.stride, 144, "a row is \(MemoryLayout<SpotItem>.stride) bytes")
    }

    func testARowKeepsItsRareFields() {
        let field = TextBlock.Field(key: "price", value: "3")
        let item = SpotItem(title: "Tea", run: "tea", hides: ["drink"], shortcut: "cmd+t", records: true, file: "/tmp/tea", fields: [field], openTitle: "Brew", section: "Hot", peek: [TextBlock(fields: [field])])

        XCTAssertEqual(item.hides, ["drink"])
        XCTAssertEqual(item.shortcut, "cmd+t")
        XCTAssertEqual(item.file, "/tmp/tea")
        XCTAssertEqual(item.fields, [field])
        XCTAssertEqual(item.openTitle, "Brew")
        XCTAssertEqual(item.section, "Hot")
        XCTAssertEqual(item.peek, [TextBlock(fields: [field])])
        XCTAssertNil(item.card)
        XCTAssertNil(item.number)
        XCTAssertNotEqual(item, SpotItem(title: "Tea", run: "tea"))
    }
}
