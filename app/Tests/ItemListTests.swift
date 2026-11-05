import XCTest
@testable import OpenspotCore

final class ItemListTests: XCTestCase {
    private func items(_ titles: String...) -> [SpotItem] {
        titles.map { SpotItem(title: $0, run: $0) }
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

    func testFreshItemsWithoutTheSelectedItemStayInRange() {
        var list = ItemList(items: items("A", "B", "C"))
        list.move(by: 2)

        list.replace(items("A", "B"))

        XCTAssertEqual(list.selectedItem?.title, "B")
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
