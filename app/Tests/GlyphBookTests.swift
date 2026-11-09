import XCTest
@testable import OpenspotCore

final class GlyphBookTests: XCTestCase {
    func testATileTakesFourBytesForEachPixelAtTwiceItsSide() {
        let book = GlyphBook(glyphs: ["😀", "🐱", "🐶"], side: 24, fontSize: 19.2)

        XCTAssertEqual(book.pixels, 48)
        XCTAssertEqual(book.tileBytes, 48 * 48 * 4)
        XCTAssertEqual(book.offset(of: "😀"), 0)
        XCTAssertEqual(book.offset(of: "🐶"), 2 * 48 * 48 * 4)
        XCTAssertNil(book.offset(of: "🦊"))
        XCTAssertEqual(book.fileBytes, 3 * 48 * 48 * 4)
    }

    func testABookKeepsEachGlyphOnceInItsFirstPlace() {
        XCTAssertEqual(GlyphBook(glyphs: ["😀", "🐱", "😀"], side: 24, fontSize: 19.2).glyphs, ["😀", "🐱"])
    }

    func testABookIsNamedByItsGlyphsItsSizesAndTheSystem() {
        let book = GlyphBook(glyphs: ["😀", "🐱"], side: 24, fontSize: 19.2)
        let name = book.name(system: "26.1")

        XCTAssertEqual(name, GlyphBook(glyphs: ["😀", "🐱"], side: 24, fontSize: 19.2).name(system: "26.1"))
        XCTAssertNotEqual(name, GlyphBook(glyphs: ["🐱", "😀"], side: 24, fontSize: 19.2).name(system: "26.1"))
        XCTAssertNotEqual(name, GlyphBook(glyphs: ["😀", "🐱"], side: 36, fontSize: 19.2).name(system: "26.1"))
        XCTAssertNotEqual(name, GlyphBook(glyphs: ["😀", "🐱"], side: 24, fontSize: 20).name(system: "26.1"))
        XCTAssertNotEqual(name, book.name(system: "26.2"))
        XCTAssertTrue(name.hasSuffix(GlyphBook.fileExtension))
    }

    func testBooksLiveInTheCacheOfTheApp() {
        let home = URL(fileURLWithPath: "/home")

        XCTAssertEqual(GlyphBook.folder(environment: ["OPENSPOT_CONFIG": "/tmp/debug"], home: home, devState: nil).path, "/tmp/debug/glyphs")
        XCTAssertEqual(GlyphBook.folder(environment: [:], home: home, devState: nil).path, "/home/Library/Caches/openspot/glyphs")
    }
}
