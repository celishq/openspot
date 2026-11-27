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
}
