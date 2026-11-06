import XCTest
@testable import OpenspotCore

final class ItemListTests: XCTestCase {
    private func items(_ titles: String...) -> [SpotItem] {
        titles.map { SpotItem(title: $0, run: $0) }
    }

    func testALoadStaysUntilItsAnswerAndASearchDoesNotEndIt() {
        var list = ItemList()

        list.beginLoading()
        list.search("a")
        XCTAssertTrue(list.isLoading)

        list.replace(items("Safari"))
        XCTAssertFalse(list.isLoading)
        XCTAssertFalse(list.hasFailed)
    }

    func testAFailedLoadSaysSoUntilTheNextAnswer() {
        var list = ItemList()

        list.beginLoading()
        list.loadFailed()
        XCTAssertFalse(list.isLoading)
        XCTAssertTrue(list.hasFailed)

        list.beginLoading()
        XCTAssertFalse(list.hasFailed)
    }

    func testShowsEachItemBeforeASearch() {
        let list = ItemList(items: items("Safari", "Notes"))

        XCTAssertEqual(list.shown.map(\.title), ["Safari", "Notes"])
        XCTAssertEqual(list.selectedItem?.title, "Safari")
    }

    func testASearchFiltersAndSelectsTheBestMatch() {
        var list = ItemList(items: items("Safari", "Notes", "Numbers"))
        list.move(by: 1)

        list.search("nu")

        XCTAssertEqual(list.shown.map(\.title), ["Numbers"])
        XCTAssertEqual(list.selected, 0)
    }

    func testTheSameTextKeepsTheSelection() {
        var list = ItemList(items: items("Notes", "Numbers"))
        list.search("n")
        list.move(by: 1)

        XCTAssertFalse(list.search("n"))

        XCTAssertEqual(list.selectedItem?.title, "Numbers")
    }

    func testNewTextReportsTheChange() {
        var list = ItemList(items: items("Notes"))

        XCTAssertTrue(list.search("n"))
    }

    func testSelectingTheFirstRowKeepsTheSearch() {
        var list = ItemList(items: items("Notes", "Numbers"))
        list.search("n")
        list.move(by: 1)

        list.selectFirst()

        XCTAssertEqual(list.query, "n")
        XCTAssertEqual(list.selected, 0)
    }

    func testSelectsARunWhenItIsShown() {
        var list = ItemList(items: items("A", "B", "C"))

        list.select(run: "C")
        XCTAssertEqual(list.selectedItem?.title, "C")

        list.select(run: "missing")
        XCTAssertEqual(list.selectedItem?.title, "C")
    }

    func testMovingStopsAtEachEnd() {
        var list = ItemList(items: items("A", "B"))

        list.move(by: -1)
        XCTAssertEqual(list.selected, 0)
        list.move(by: 5)
        XCTAssertEqual(list.selected, 1)
    }

    func testFreshItemsKeepTheSelectedItem() {
        var list = ItemList(items: items("B", "C"))
        list.move(by: 1)

        list.replace(items("A", "B", "C"))

        XCTAssertEqual(list.selectedItem?.title, "C")
        XCTAssertEqual(list.selected, 2)
    }

    func testASelectionAtTheTopStaysAtTheTop() {
        var list = ItemList(items: items("B", "C"))

        list.replace(items("A", "B", "C"))

        XCTAssertEqual(list.selectedItem?.title, "A")
    }

    func testFreshItemsWithoutTheSelectedItemStayInRange() {
        var list = ItemList(items: items("A", "B", "C"))
        list.move(by: 2)

        list.replace(items("A", "B"))

        XCTAssertEqual(list.selectedItem?.title, "B")
    }

    func testASearchElsewhereLeavesTheSearchOfTheListAlone() {
        var list = ItemList(items: items("Safari", "Notes"), recent: [])
        list.search("note")

        XCTAssertEqual(SearchQuery(text: "saf").matching(in: [list]).map(\.item.title), ["Safari"])
        XCTAssertEqual(list.shown.map(\.title), ["Notes"])
    }

    func testALiveListShowsWhatThePluginAnswersWithoutFilteringIt() {
        var list = ItemList(search: .live)
        list.search("rep")

        list.answer(items("Annual", "Report"), to: "rep")

        XCTAssertEqual(list.shown.map(\.title), ["Annual", "Report"])
    }

    func testALiveListDropsAnAnswerToAnOlderSearch() {
        var list = ItemList(search: .live)
        list.search("re")
        list.search("rep")

        list.answer(items("Old"), to: "re")

        XCTAssertEqual(list.shown, [])
        XCTAssertTrue(list.isWaiting)
    }

    func testALiveListKeepsItsRowsWhileItWaits() {
        var list = ItemList(search: .live)
        list.search("re")
        list.answer(items("Report"), to: "re")

        list.search("rep")

        XCTAssertEqual(list.shown.map(\.title), ["Report"])
        XCTAssertTrue(list.isWaiting)
    }

    func testALocalListNeverWaits() {
        var list = ItemList(items: items("Safari"))

        list.search("s")

        XCTAssertFalse(list.isWaiting)
    }

    func testAnEmptyListSelectsNothing() {
        XCTAssertNil(ItemList().selectedItem)
    }

    func testARememberedPickComesFirstAndLeadsTheRecentList() {
        var list = ItemList(items: items("A", "B", "C"), recent: ["A"])

        list.remember(SpotItem(title: "C", run: "C"))

        XCTAssertEqual(list.recent, ["C", "A"])
        XCTAssertEqual(list.shown.map(\.title), ["C", "A", "B"])
    }

    func testTheRecentListHasALimit() {
        var list = ItemList()

        for number in 0..<50 { list.remember(SpotItem(title: "\(number)", run: "\(number)")) }

        XCTAssertEqual(list.recent.count, ItemList.recentLimit)
        XCTAssertEqual(list.recent.first, "49")
    }
}
