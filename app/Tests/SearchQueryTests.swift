import XCTest
@testable import OpenspotCore

final class SearchQueryTests: XCTestCase {
    private func item(_ title: String, subtitle: String? = nil) -> SpotItem {
        SpotItem(title: title, subtitle: subtitle, run: title)
    }

    private func titles(_ text: String, in titles: [String], recent: [String] = []) -> [String] {
        SearchQuery(text: text).matching(titles.map { item($0) }, recent: recent).map(\.title)
    }

    func testEmptyTextKeepsEveryItemInOrder() {
        XCTAssertEqual(titles("", in: ["Safari", "Notes"]), ["Safari", "Notes"])
    }

    func testMatchesIgnoringCaseAndAccents() {
        XCTAssertEqual(titles("SAF", in: ["Safari", "Notes"]), ["Safari"])
        XCTAssertEqual(titles("cafe", in: ["Café", "Notes"]), ["Café"])
    }

    func testNoMatchGivesNoItems() {
        XCTAssertEqual(titles("zzz", in: ["Safari"]), [])
    }

    func testAWordStartBeatsAnyMatch() {
        XCTAssertEqual(titles("note", in: ["Keynote", "Pages Notes"]), ["Pages Notes", "Keynote"])
    }

    func testTheTitleStartBeatsAWordStart() {
        XCTAssertEqual(titles("not", in: ["Sticky Notes", "Notes"]), ["Notes", "Sticky Notes"])
    }

    func testAMatchMayCrossWords() {
        XCTAssertEqual(titles("studio co", in: ["Visual Studio Code", "Xcode"]), ["Visual Studio Code"])
    }

    func testInitialsMatchEachWord() {
        XCTAssertEqual(titles("vsc", in: ["Xcode", "Visual Studio Code"]), ["Visual Studio Code"])
    }

    func testInitialsMaySkipAWord() {
        XCTAssertEqual(titles("ae", in: ["Xcode", "Adobe After Effects"]), ["Adobe After Effects"])
    }

    func testACapitalInsideAWordStartsAWord() {
        XCTAssertEqual(titles("ft", in: ["Loft", "FaceTime"]), ["FaceTime", "Loft"])
    }

    func testASubtitleMatchComesLast() {
        let items = [item("Mail", subtitle: "Notes app"), item("Keynote")]

        XCTAssertEqual(SearchQuery(text: "note").matching(items).map(\.title), ["Keynote", "Mail"])
    }

    func testARecentPickComesFirstWithinItsMatch() {
        XCTAssertEqual(titles("s", in: ["Safari", "Slack", "Mess"], recent: ["Slack"]), ["Slack", "Safari", "Mess"])
    }

    func testARecentPickDoesNotBeatABetterMatch() {
        XCTAssertEqual(titles("note", in: ["Keynote", "Notes"], recent: ["Keynote"]), ["Notes", "Keynote"])
    }

    func testRecentPicksLeadAnEmptySearch() {
        XCTAssertEqual(titles("", in: ["Safari", "Notes", "Mail"], recent: ["Mail", "Notes"]), ["Mail", "Notes", "Safari"])
    }
}
