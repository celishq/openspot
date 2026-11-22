import XCTest
@testable import OpenspotCore

@MainActor
final class EmptySearchTests: PanelCase {
    private var searches: [String: Int] {
        model.runs.usage.days(1, at: Date()).first?.searches ?? [:]
    }

    private func search(_ text: String) {
        model.query = text
        model.landSearch()
    }

    func testASearchThatFoundNothingCountsByItsFoldedTextWhenItIsClearedOrThePanelHides() async throws {
        try script("coffee", toml: "title = 'Coffee'", "true")
        await model.reload()
        model.isShown = true
        model.panelWillShow()

        search("Tímezone")
        search("")
        search("weather ")
        model.panelDidHide()

        XCTAssertEqual(searches, ["timezone": 1, "weather": 1])
    }

    func testASearchThatFoundOnlyAnAnswerUnderTheResultsCountsAsMissed() async throws {
        try script("make", toml: "title = 'Make'\nanswers = 'last'\n[on]\nsearch = '.'", #"text=$(sed -n 's/^input\.text=//p'); printf 'item=%s\ntitle=Make\n' "$text""#)
        await model.reload()
        model.isShown = true
        model.panelWillShow()

        search("timezon")
        try await wait("the last answer") { model.visible.map(\.id) == ["make\ntimezon"] }
        search("timezone")
        search("")

        XCTAssertEqual(searches, ["timezone": 1])
    }

    func testASearchThatFoundASpotOrIsShortCountsNothing() async throws {
        try script("coffee", toml: "title = 'Coffee'", "true")
        await model.reload()
        model.isShown = true
        model.panelWillShow()

        search("coffee")
        search("")
        search("zq")
        search("")
        model.panelDidHide()

        XCTAssertEqual(searches, [:])
    }

    func testTheSameSearchHiddenThenClearedCountsOnce() async throws {
        await model.reload()
        model.isShown = true
        model.panelWillShow()

        search("timezone")
        model.panelDidHide()
        search("")

        XCTAssertEqual(searches, ["timezone": 1])
    }

    func testASearchClearedOneLetterAtATimeCountsItsLongestText() async throws {
        await model.reload()
        model.isShown = true
        model.panelWillShow()

        for end in (1..."timezone".count).reversed() { search(String("timezone".prefix(end))) }
        search("")

        XCTAssertEqual(searches, ["timezone": 1])
    }

    func testEnteringEditSpotsCountsNoSearch() async throws {
        await model.reload()
        model.isShown = true
        model.panelWillShow()

        search("timezone")
        model.beginEditing()
        model.panelDidHide()

        XCTAssertEqual(searches, [:])
    }

    func testADayKeepsAtMostFiftySearches() {
        let usage = StatsLog()
        for index in 0..<60 { usage.missed("search \(index)", at: Date()) }
        usage.missed("search 0", at: Date())

        let kept = usage.days(1, at: Date()).first?.searches ?? [:]
        XCTAssertEqual(kept.count, 50)
        XCTAssertEqual(kept["search 0"], 2)
    }

    func testTheStatsPrintEachSearchThatFoundNothing() throws {
        let usage = StatsLog()
        usage.missed("timezone", at: Date())
        usage.missed("timezone", at: Date())

        let days = usage.days(1, at: Date())
        XCTAssertTrue(try Stats(days: days, spot: nil).text(.frame).hasSuffix("search=timezone\ncount=2\n\n"))
        XCTAssertTrue(try Stats(days: days, spot: nil).text(.metrics).contains("# TYPE openspot_search_empty counter\nopenspot_search_empty_total{query=\"timezone\"} 2\n"))
        XCTAssertTrue(try Stats(days: days, spot: nil).text(.json).contains("\"searches\":{\"timezone\":2}"))
    }
}
