import XCTest
@testable import OpenspotCore

final class ItemListTests: XCTestCase {
    func testTheSameItemsAgainTakeNoNewWork() {
        let rows = (0..<6000).map { SpotItem(title: "Ключ настройки \($0)", subtitle: "Системные настройки", run: "\($0)", keywords: ["громкость", "звук", "экран"]) }
        var list = ItemList(items: rows)
        let started = Date()

        for _ in 0..<10 { list.replace(rows) }

        XCTAssertLessThan(Date().timeIntervalSince(started), 0.5)
        XCTAssertEqual(list.shown.count, 6000)
    }

    func testRowsReadiedFromTheRowsOfAListReplaceThemAsAnAnswerDoes() {
        var list = ItemList(items: items("Safari", "Slack"))
        list.search("s")
        var answered = list

        list.replace(list.ready(items("Signal", "Notes", "Safari"), search: .local))
        answered.replace(items("Signal", "Notes", "Safari"))

        XCTAssertEqual(list, answered)
        XCTAssertEqual(Set(list.shown.map(\.title)), ["Signal", "Notes", "Safari"])
    }

    func testRowsReadiedFromRowsThatTheListNoLongerHoldsAreComparedAgain() {
        var list = ItemList(items: items("Safari"))
        let readied = list.ready(items("Slack"), search: .local)

        list.replace(items("Notes"))
        list.replace(readied)

        XCTAssertEqual(list.shown.map(\.title), ["Slack"])
        XCTAssertEqual(list, ItemList(items: items("Slack")))
    }

    func testTheSameRowsReadiedLeaveTheListAsItWas() {
        var list = ItemList(items: items("Safari", "Slack"))
        list.move(by: 1)
        let before = list

        list.replace(list.ready(items("Safari", "Slack"), search: .local))

        XCTAssertEqual(list, before)
    }

    func testTypingAndDeletingShowsTheRowsOfAFreshSearch() {
        let rows = [
            SpotItem(title: "Smiling Face", run: "1", picture: .glyph("😊"), keywords: ["happy", "smile"]),
            SpotItem(title: "Simple Mail", subtitle: "Send messages", run: "2"),
            SpotItem(title: "Small Icons", subtitle: "System Settings › Dock", run: "3", keywords: ["size"]),
            SpotItem(title: "Cat Face", run: "4", picture: .glyph("🐱"), keywords: ["pet", "smile"]),
            SpotItem(title: "Screen Mirroring", run: "5")
        ]
        var list = ItemList(items: rows)
        let texts = ["s", "sm", "smi", "smil", "smile", "smil", "smi", "sm", "s", "", "s", "sm", "sm ", "sm i", "sm", "c", "ca", "cat f", "ca", ""]

        for text in texts {
            list.search(text)
            var fresh = ItemList(items: rows)
            fresh.search(text)
            XCTAssertEqual(list.shown.map(\.run), fresh.shown.map(\.run), text)
        }
    }

    func testAPickRanksAgainForTheSameText() {
        var list = ItemList(items: items("Safari", "Slack"))
        list.search("s")
        list.search("sl")
        list.search("s")
        XCTAssertEqual(list.shown.map(\.title), ["Safari", "Slack"])

        list.remember(SpotItem(title: "Slack", run: "Slack"))

        XCTAssertEqual(list.shown.map(\.title), ["Slack", "Safari"])
    }

    func testAListThatLearnsTheScriptSearchesWaitsForAnAnswerToItsText() {
        var list = ItemList(items: [SpotItem(title: "Notes", run: "n"), SpotItem(title: "Mail", run: "m")])
        list.search("no")
        XCTAssertEqual(list.shown.map(\.title), ["Notes"])

        list.take(search: .script)

        XCTAssertTrue(list.isWaiting)
        XCTAssertEqual(list.shown.count, 2)
    }

    private func items(_ titles: String...) -> [SpotItem] {
        items(titles)
    }

    private func items(_ titles: [String]) -> [SpotItem] {
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

    func testALongerCyrillicSearchStillFindsALatinTitle() {
        var list = ItemList(items: items("Safari", "Notes"))

        list.search("са")
        list.search("саф")

        XCTAssertEqual(list.shown.map(\.title), ["Safari"])
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
        var list = ItemList(search: .script)
        list.search("rep")

        list.answer(items("Annual", "Report"), to: "rep")

        XCTAssertEqual(list.shown.map(\.title), ["Annual", "Report"])
    }

    func testALiveListDropsAnAnswerToAnOlderSearch() {
        var list = ItemList(search: .script)
        list.search("re")
        list.search("rep")

        list.answer(items("Old"), to: "re")

        XCTAssertEqual(list.shown, [])
        XCTAssertTrue(list.isWaiting)
    }

    func testALiveListKeepsItsRowsWhileItWaits() {
        var list = ItemList(search: .script)
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

    private func grid(_ count: Int, perLine: Int) -> ItemList {
        var list = ItemList(items: (0..<count).map { SpotItem(title: "\($0)", run: "\($0)") })
        list.take(perLine: perLine)
        return list
    }

    func testAKeyDownKeepsThePlaceInTheLine() {
        var list = grid(10, perLine: 4)
        list.move(by: 1)

        list.moveLine(by: 1)

        XCTAssertEqual(list.selected, 5)
    }

    func testAKeyDownToAShortLineTakesItsLastItem() {
        var list = grid(10, perLine: 4)
        list.move(by: 7)

        list.moveLine(by: 1)

        XCTAssertEqual(list.selected, 9)
    }

    func testAKeyStopsAtTheFirstAndTheLastLine() {
        var list = grid(10, perLine: 4)
        list.move(by: 2)
        list.moveLine(by: -1)
        XCTAssertEqual(list.selected, 2)

        list.move(by: 7)
        list.moveLine(by: 1)
        XCTAssertEqual(list.selected, 9)
    }

    func testOneItemPerLineMovesAsAList() {
        var list = grid(3, perLine: 1)

        list.moveLine(by: 1)
        XCTAssertEqual(list.selected, 1)
        list.moveLine(by: -1)
        XCTAssertEqual(list.selected, 0)
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

    func testEachPickCountsSoTheMostPickedComesFirst() {
        var list = ItemList(items: items("A", "B", "C"), recent: ["A", "A"])

        list.remember(SpotItem(title: "C", run: "C"))

        XCTAssertEqual(list.recent, ["C", "A", "A"])
        XCTAssertEqual(list.shown.map(\.title), ["A", "C", "B"])
    }

    func testTheRecentListHasALimit() {
        var list = ItemList()

        for number in 0..<150 { list.remember(SpotItem(title: "\(number)", run: "\(number)")) }

        XCTAssertEqual(list.recent.count, ItemList.recentLimit)
        XCTAssertEqual(list.recent.first, "149")
    }

    func testTypingMakesNoPickWeightsAndAPickMakesThemOnce() {
        var list = ItemList(items: items("Safari", "Slack", "Notes"), recent: ["Slack"])
        var search = MainSearch()
        let before = PickWeights.builds

        for text in ["s", "sa", "saf", "sl", "s"] {
            list.search(text)
            _ = search.matching(SearchQuery(text: text), in: [list])
        }
        XCTAssertEqual(PickWeights.builds - before, 0)
        list.remember(list.all[0])

        XCTAssertEqual(PickWeights.builds - before, 1)
        XCTAssertEqual(list.shown.map(\.title), ["Safari", "Slack", "Notes"])
    }

    func testEachKeystrokeInALargeListAnswersQuickly() {
        let rows = (0..<5_096).map { SpotItem(title: "rightwards arrow with hook \($0)", subtitle: "Rightwards Arrows", run: "\($0)") }
        var list = ItemList(items: rows)
        let started = Date()

        for text in ["w", "wi", "wit", "with", "with h"] { list.search(text) }

        let time = Date().timeIntervalSince(started) / 5
        XCTAssertLessThan(time, 1)
    }

    func testAGrowingSearchFindsWhatAFreshSearchFinds() {
        let titles = ["axbxc", "abc", "Abacus", "cab", "a b c", "xabcx", "Notes"]
        var typed = ItemList(items: items(titles))
        for text in ["a", "ab", "abc", "abc ", "abc b"] {
            typed.search(text)
            var fresh = ItemList(items: items(titles))
            fresh.search(text)

            XCTAssertEqual(typed.shown.map(\.title), fresh.shown.map(\.title), text)
        }
    }

    func testAShorterSearchFindsAgainWhatTheLongerOneDropped() {
        var list = ItemList(items: items("Safari", "Notes"))
        list.search("sa")
        list.search("s")

        XCTAssertEqual(list.shown.map(\.title), ["Safari", "Notes"])
    }
}
