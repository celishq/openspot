import XCTest
@testable import OpenspotCore

@MainActor
final class KeptSheetsTests: XCTestCase {
    func testASheetOverTheLimitIsNotKept() {
        let sheets = KeptSheets(folder: nil)
        let small = "frame=\ntitle=Small\n"
        let large = "frame=\ntitle=" + String(repeating: "x", count: KeptSheets.byteLimit) + "\n"

        sheets.keep(small, frame: Frame(text: small), of: "a")
        sheets.keep(large, frame: Frame(text: large), of: "b")

        XCTAssertNotNil(sheets.frame(of: "a"))
        XCTAssertNil(sheets.frame(of: "b"))
    }

    func testASheetThatGrowsOverTheLimitDropsItsKeptCopy() {
        let sheets = KeptSheets(folder: nil)
        let small = "frame=\ntitle=Small\n"
        let large = "frame=\ntitle=" + String(repeating: "x", count: KeptSheets.byteLimit) + "\n"

        sheets.keep(small, frame: Frame(text: small), of: "a")
        sheets.keep(large, frame: Frame(text: large), of: "a")

        XCTAssertNil(sheets.frame(of: "a"))
    }

    func testAKeptFileOverTheLimitIsNotRead() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("kept-sheets-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "frame=\ntitle=A\n".write(to: folder.appendingPathComponent("a.frame"), atomically: true, encoding: .utf8)
        try String(repeating: "x", count: KeptSheets.byteLimit + 1).write(to: folder.appendingPathComponent("b.frame"), atomically: true, encoding: .utf8)

        XCTAssertEqual(Array(KeptSheets.read(folder).keys), ["a"])
    }
}
