import XCTest
@testable import OpenspotCore

final class RowResultTests: XCTestCase {
    func testKeepsValidLinesAndReportsBadOnes() {
        let output = """
        {"title":"Hacker News","subtitle":"news","run":"open https://news.ycombinator.com"}
        not json
        {"title":"Safari","run":"open -a Safari"}
        """
        let result = RowResult(output: output)
        XCTAssertEqual(result.rows.map(\.title), ["Hacker News", "Safari"])
        XCTAssertEqual(result.rows.first?.subtitle, "news")
        XCTAssertEqual(result.errors.count, 1)
    }
}
