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

    func testTheWholeTitleBeatsATitleStart() {
        XCTAssertEqual(titles("note", in: ["Notes", "Note"]), ["Note", "Notes"])
    }

    func testWordsMatchInAnyOrder() {
        XCTAssertEqual(titles("code vis", in: ["Xcode", "Visual Studio Code"]), ["Visual Studio Code"])
    }

    func testAWordMayMatchInitials() {
        XCTAssertEqual(titles("vs code", in: ["Xcode", "Visual Studio Code"]), ["Visual Studio Code"])
    }

    func testOneWordMayMatchTheTitleAndAnotherTheSubtitle() {
        let items = [item("Chrome", subtitle: "Home profile"), item("Chrome", subtitle: "Work profile")]

        XCTAssertEqual(SearchQuery(text: "chrome work").matching(items).map(\.subtitle), ["Work profile"])
    }

    func testAWordInTheTitleBeatsAWordInTheSubtitle() {
        let items = [item("Mail", subtitle: "Work inbox"), item("Work Log")]

        XCTAssertEqual(SearchQuery(text: "work").matching(items).map(\.title), ["Work Log", "Mail"])
    }

    func testLettersInOrderMatchLast() {
        let items = [item("Safari"), item("Mail", subtitle: "sfr box")]

        XCTAssertEqual(SearchQuery(text: "sfr").matching(items).map(\.title), ["Mail", "Safari"])
    }

    func testLettersInOrderStayInOneWord() {
        XCTAssertEqual(titles("note", in: ["Android File Transfer", "Notes"]), ["Notes"])
    }

    func testLettersInOrderNeedThreeLetters() {
        XCTAssertEqual(titles("sf", in: ["Safari"]), [])
    }

    func testMarksTheMatchedLettersOfEachWord() {
        let marks = SearchQuery(text: "co vis").marks(in: item("Visual Studio Code"))

        XCTAssertEqual(marks, SearchMarks(title: [0..<3, 14..<16], subtitle: []))
    }

    func testMarksEachInitial() {
        XCTAssertEqual(SearchQuery(text: "vsc").marks(in: item("Visual Studio Code")).title, [0..<1, 7..<8, 14..<15])
    }

    func testMarksAWordInTheSubtitle() {
        let marks = SearchQuery(text: "chrome work").marks(in: item("Chrome", subtitle: "Work profile"))

        XCTAssertEqual(marks, SearchMarks(title: [0..<6], subtitle: [0..<4]))
    }

    func testAnEmptySearchMarksNothing() {
        XCTAssertEqual(SearchQuery(text: "").marks(in: item("Safari")), SearchMarks(title: [], subtitle: []))
    }

    func testARecentPickComesFirstWithinItsMatch() {
        XCTAssertEqual(titles("s", in: ["Safari", "Slack", "Mess"], recent: ["Slack"]), ["Slack", "Safari", "Mess"])
    }

    func testAFrequentPickBeatsALaterOne() {
        XCTAssertEqual(titles("s", in: ["Signal", "Slack", "Safari"], recent: ["Slack", "Safari", "Safari"]), ["Safari", "Slack", "Signal"])
    }

    func testARecentPickDoesNotBeatABetterMatch() {
        XCTAssertEqual(titles("note", in: ["Keynote", "Notes"], recent: ["Keynote"]), ["Notes", "Keynote"])
    }

    func testRecentPicksLeadAnEmptySearch() {
        XCTAssertEqual(titles("", in: ["Safari", "Notes", "Mail"], recent: ["Mail", "Notes"]), ["Mail", "Notes", "Safari"])
    }

    private func list(_ titles: [String], recent: [String] = []) -> ItemList {
        ItemList(items: titles.map { item($0) }, recent: recent)
    }

    private func found(_ text: String, in lists: [ItemList]) -> [String] {
        SearchQuery(text: text).matching(in: lists).map(\.item.title)
    }

    func testTheFirstListWinsAMatchOfTheSameRank() {
        XCTAssertEqual(found("d", in: [list(["Docs"]), list(["Dictionary"])]), ["Docs", "Dictionary"])
    }

    func testABetterMatchBeatsAnEarlierList() {
        XCTAssertEqual(found("note", in: [list(["Keynote"]), list(["Notes"])]), ["Notes", "Keynote"])
    }

    func testARecentPickBeatsAnEarlierList() {
        XCTAssertEqual(found("s", in: [list(["Site"]), list(["Safari"], recent: ["Safari"])]), ["Safari", "Site"])
    }

    func testMorePicksWinAcrossListsAndEachPickBeatsAnEarlierList() {
        let lists = [list(["Site", "Sun"], recent: ["Sun"]), list(["Safari"], recent: ["Safari", "Safari"])]

        XCTAssertEqual(found("s", in: lists), ["Safari", "Sun", "Site"])
    }

    func testALatePickOutweighsManyOldOnes() {
        let recent = ["Slack"] + Array(repeating: "Mess", count: 29) + Array(repeating: "Safari", count: 5)

        XCTAssertEqual(titles("s", in: ["Safari", "Slack"], recent: recent), ["Slack", "Safari"])
    }

    func testAListAfterTheFirstWithNoPickGivesAtMostItsLimit() {
        let lists = [list(["Spot", "Star", "Stop"]), list(["Sa", "Sb", "Sc"]), list(["Sd", "Se", "Sf"], recent: ["Sf"])]

        XCTAssertEqual(SearchQuery(text: "s").matching(in: lists, unpickedLimit: 2).map(\.item.title), ["Sf", "Spot", "Star", "Stop", "Sa", "Sb", "Sd", "Se"])
    }

    func testRecentPicksKeepTheirOrderWithinAList() {
        XCTAssertEqual(found("s", in: [list(["Safari", "Slack"], recent: ["Slack", "Safari"])]), ["Slack", "Safari"])
    }

    func testAMatchTellsWhichListItCameFrom() {
        let matches = SearchQuery(text: "d").matching(in: [list(["Mail"]), list(["Docs"])])

        XCTAssertEqual(matches.map(\.list), [1])
    }

    func testAnEmptySearchOfSeveralListsKeepsListOrder() {
        XCTAssertEqual(found("", in: [list(["Docs"]), list(["Apps"])]), ["Docs", "Apps"])
    }
}
