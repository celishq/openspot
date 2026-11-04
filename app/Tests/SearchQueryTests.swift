import XCTest
@testable import OpenspotCore

final class SearchQueryTests: XCTestCase {
    private let rows = [
        Row(title: "Hacker News", subtitle: "news.ycombinator.com", run: "open https://news.ycombinator.com"),
        Row(title: "Safari", subtitle: nil, run: "open -a Safari"),
        Row(title: "Caffeinate", subtitle: "Keep the Mac awake", run: "caffeinate -d")
    ]

    func testEmptyTextKeepsEveryRow() {
        XCTAssertEqual(SearchQuery(text: "").matching(rows).map(\.title), ["Hacker News", "Safari", "Caffeinate"])
    }

    func testMatchesTitleIgnoringCase() {
        XCTAssertEqual(SearchQuery(text: "saf").matching(rows).map(\.title), ["Safari"])
    }

    func testMatchesSubtitle() {
        XCTAssertEqual(SearchQuery(text: "awake").matching(rows).map(\.title), ["Caffeinate"])
    }

    func testNoMatchGivesNoRows() {
        XCTAssertTrue(SearchQuery(text: "zzz").matching(rows).isEmpty)
    }
}
