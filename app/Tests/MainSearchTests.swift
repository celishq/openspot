import XCTest
@testable import OpenspotCore

final class MainSearchTests: XCTestCase {
    func testANarrowedKeyRanksOnlyTheMatchesOfTheLastKey() {
        let list = ItemList(items: items(["Safe", "Safety", "Safari"] + (0..<1000).map { "Row \($0)" }))
        var search = MainSearch()
        _ = search.matching(SearchQuery(text: "saf", layouts: []), in: [list])

        let found = search.matching(SearchQuery(text: "safa", layouts: []), in: [list])

        XCTAssertEqual(search.ranked, 3)
        XCTAssertEqual(found.map(\.item.title), ["Safari"])
    }

    func testAKeyThatDoesNotNarrowRanksEachItem() {
        let list = ItemList(items: items(["Safe", "Notes", "Signal"]))
        var search = MainSearch()
        _ = search.matching(SearchQuery(text: "sa", layouts: []), in: [list])

        _ = search.matching(SearchQuery(text: "sig", layouts: []), in: [list])

        XCTAssertEqual(search.ranked, 3)
    }

    func testNewRowsAreSearchedWhole() {
        var list = ItemList(items: items(["Safe", "Notes"]))
        var search = MainSearch()
        _ = search.matching(SearchQuery(text: "saf", layouts: []), in: [list])
        list.replace(items(["Safe", "Notes", "Safari"]))

        let found = search.matching(SearchQuery(text: "safa", layouts: []), in: [list])

        XCTAssertEqual(found.map(\.item.title), ["Safari"])
    }

    func testANewPickOrSearchKindRanksEachItemAgain() {
        var list = ItemList(items: items(["Safe", "Notes", "Safari"]))
        var search = MainSearch()
        _ = search.matching(SearchQuery(text: "saf", layouts: []), in: [list])
        list.remember(list.all[2])

        let picked = search.matching(SearchQuery(text: "safa", layouts: []), in: [list])
        XCTAssertEqual(search.ranked, 3)
        list.take(search: .script)
        _ = search.matching(SearchQuery(text: "safar", layouts: []), in: [list])

        XCTAssertEqual(picked.map(\.item.title), ["Safari"])
        XCTAssertEqual(search.ranked, 3)
    }

    func testAGrowingSearchFindsWhatAFreshSearchFinds() {
        let lists = [ItemList(items: items(["axbxc", "abc", "Abacus", "cab", "a b c", "xabcx", "Notes"]), recent: ["cab"]), ItemList(items: items(["Cabinet", "Abc Store"]))]
        var search = MainSearch()
        for text in ["a", "ab", "abc", "abc ", "abc b"] {
            let typed = search.matching(SearchQuery(text: text), in: lists, unpickedLimit: 1, limit: 4)
            let fresh = SearchQuery(text: text).matching(in: lists, unpickedLimit: 1, limit: 4)

            XCTAssertEqual(typed.map(\.item.title), fresh.map(\.item.title), text)
        }
    }

    private func items(_ titles: [String]) -> [SpotItem] {
        titles.map { SpotItem(title: $0, run: $0) }
    }
}
