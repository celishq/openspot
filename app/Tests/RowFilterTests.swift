import XCTest
@testable import OpenspotCore

final class RowFilterTests: XCTestCase {
    private let rows = [
        Row(title: "Hacker News", subtitle: "news.ycombinator.com", run: "open https://news.ycombinator.com"),
        Row(title: "Safari", subtitle: nil, run: "open -a Safari"),
        Row(title: "Caffeinate", subtitle: "Keep the Mac awake", run: "caffeinate -d")
    ]

    func testEmptyQueryKeepsEveryRow() {
        XCTAssertEqual(RowFilter.matching(rows, query: "").map(\.title), ["Hacker News", "Safari", "Caffeinate"])
    }

    func testMatchesTitleIgnoringCase() {
        XCTAssertEqual(RowFilter.matching(rows, query: "saf").map(\.title), ["Safari"])
    }

    func testMatchesSubtitle() {
        XCTAssertEqual(RowFilter.matching(rows, query: "awake").map(\.title), ["Caffeinate"])
    }

    func testNoMatchGivesNoRows() {
        XCTAssertTrue(RowFilter.matching(rows, query: "zzz").isEmpty)
    }
}
