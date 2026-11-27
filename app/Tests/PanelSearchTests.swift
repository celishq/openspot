import XCTest
@testable import OpenspotCore

@MainActor
final class PanelSearchTests: PanelCase {
    private func showGrid() async throws {
        try script("alpha", toml: "title = 'Alpha'", "true")
        try script("beta", toml: "title = 'Beta'", "true")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
    }

    private var shown: [String] {
        model.visible.map(\.id)
    }

    func testAKeyRanksTheSpotsOnceAndShowsThemBeforeTheSetterReturns() async throws {
        try await showGrid()
        let ranks = SearchRanks()

        SearchRanks.$meter.withValue(ranks) { model.query = "al" }

        XCTAssertEqual(shown, ["alpha"])
        XCTAssertEqual(ranks.count, 1)
    }

    func testASpotThatListsWantIsAskedOnceWhenItsRowsFirstShowInEachPanelOpen() async throws {
        let log = folder.appendingPathComponent("wants")
        try script("tabs", toml: "title = 'Tabs'\n[on]\n\"sheet.open\" = true\n\"spot.want\" = true\nsearch = true", "sed -n 's/^input\\.event=//p' >> '\(log.path)'\nprintf 'item=current\\ntitle=Snooze Current Tab\\n'")
        try script("other", toml: "title = 'Other'\n[on]\nsearch = true", "printf 'item=x\\ntitle=Snore\\n'")
        await model.reload()
        let wants = { ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").filter { $0 == "spot.want" }.count }
        model.isShown = true
        model.panelWillShow()

        model.query = "snooze"
        try await wait("the want") { wants() == 1 }
        model.query = "snooze c"
        model.query = "snooze cu"
        try await wait("the rows") { self.shown.contains { $0.hasPrefix("tabs") } }
        XCTAssertEqual(wants(), 1)
        model.panelWillHide()
        model.panelDidHide()
        model.panelWillShow()
        model.query = "snooze"

        try await wait("the next want") { wants() == 2 }
    }

    func testASpotThatListsWantIsAskedOnceWhenThePanelOpensWithItsCardOnTheGrid() async throws {
        let log = folder.appendingPathComponent("card-wants")
        try script("tabs", toml: "title = 'Tabs'\n[on]\n\"sheet.open\" = true\n\"spot.want\" = true", "sed -n 's/^input\\.event=//p' >> '\(log.path)'\nprintf 'text=current\\ntitle=Snooze Current Tab\\n'")
        await model.reload()
        let wants = { ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").filter { $0 == "spot.want" }.count }

        model.isShown = true
        model.panelWillShow()
        try await wait("the want") { wants() == 1 }
        model.panelWillHide()
        model.panelDidHide()
        model.panelWillShow()

        try await wait("the next want") { wants() == 2 }
    }

    func testAFailedPressOfARowMarksThatRowAndNotTheSpotsCard() async throws {
        try script("tabs", toml: "title = 'Tabs'\n[on]\nsearch = true", "[ \"$1\" = press ] && { echo 'Ghostty is not a browser' >&2; exit 1; }\nprintf 'item=current\\ntitle=Snooze Current Tab\\nclose=false\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.query = "snooze current"
        try await wait("the row") { self.model.visible.contains { $0.item?.run == "current" } }
        let row = try XCTUnwrap(model.visible.first { $0.item?.run == "current" })

        model.pick(try XCTUnwrap(row.item), of: try XCTUnwrap(model.entry("tabs")))

        try await wait("the failure") { self.model.failure(of: row) != nil }
        XCTAssertEqual(model.failure(of: row), "Ghostty is not a browser")
        XCTAssertNil(model.failure(of: try XCTUnwrap(model.entry("tabs"))))
        XCTAssertEqual(host.notes, ["Ghostty is not a browser"])
    }

    func testAFailedPressWhileThePanelIsHiddenIsAToast() async throws {
        try script("tabs", toml: "title = 'Tabs'\n[on]\nsearch = true", "[ \"$1\" = press ] && { echo 'Ghostty is not a browser' >&2; exit 1; }\nprintf 'text=current\\ntitle=Snooze Current Tab\\n'")
        await model.reload()
        let entry = try XCTUnwrap(model.entry("tabs"))

        model.pick(SpotItem(title: "Snooze Current Tab", run: "current"), of: entry)

        try await wait("the toast") { self.host.notes == ["Ghostty is not a browser"] }
    }

    func testASpotThatOnlyOffersActionsIsNotFound() async throws {
        try await showGrid()
        try script("acts", toml: "title = 'Alpha acts'\n[actions.change]\ntitle = 'Change'\noffers = ['actions']", "true")
        await model.reload()

        model.query = "al"

        try await wait("the found spots") { !self.shown.contains("beta") }
        XCTAssertEqual(shown, ["alpha"])
    }

    func testReturnRightAfterAKeyActsOnTheSpotsOfTheNewText() async throws {
        try await showGrid()
        let ranks = SearchRanks()

        SearchRanks.$meter.withValue(ranks) {
            model.query = "bet"
            XCTAssertTrue(model.handleSearchKey(ActionKey(name: "return")))
        }

        XCTAssertEqual(shown, ["beta"])
        try await wait("the sheet of beta") { self.model.openSheetID == "beta" }
        XCTAssertEqual(ranks.count, 1)
    }

    func testAKeyWithNoCommandActsOnTheSpotsOfTheNewText() async throws {
        try await showGrid()

        model.query = "bet"
        _ = model.handleKey(ActionKey(name: "\t"))

        XCTAssertEqual(shown, ["beta"])
    }

    func testClearingTheTextShowsTheGridAtOnce() async throws {
        try await showGrid()
        let grid = shown

        model.query = "al"
        model.query = ""

        XCTAssertEqual(shown, grid)
    }

    private func slowAnswer(gate: URL, rows: String) throws {
        try script("make", toml: "title = 'Make'\n[on]\nsearch = '\\S'", "[ \"$1\" = search ] || exit 0\nwhile [ ! -f '\(gate.path)' ]; do sleep 0.01; done\n\(rows)")
    }

    func testAKeyWhoseOnlyRowsAreOnTheirWayKeepsTheLastRowsUntilTheyLand() async throws {
        let gate = folder.appendingPathComponent("gate")
        try slowAnswer(gate: gate, rows: "printf 'item=3\\ntitle=Make a spot\\n'")
        try await showGrid()
        let grid = shown

        model.query = "3"

        XCTAssertEqual(shown, grid)
        FileManager.default.createFile(atPath: gate.path, contents: Data())
        try await wait("the late row") { self.model.visible.map(\.item?.title) == ["Make a spot"] }
    }

    func testALateRowLandsInOnePressSoTheHintComesWithIt() async throws {
        let gate = folder.appendingPathComponent("gate")
        try slowAnswer(gate: gate, rows: "printf 'item=3\\ntitle=Make a spot\\n'")
        try await showGrid()
        model.query = "3"
        nonisolated(unsafe) var inPress: Bool?
        withObservationTracking { _ = model.visible } onChange: { [model] in
            MainActor.assumeIsolated { inPress = model!.pressDepth > 0 }
        }

        FileManager.default.createFile(atPath: gate.path, contents: Data())

        try await wait("the late row") { inPress != nil }
        XCTAssertEqual(inPress, true)
    }

    func testAKeyWhoseLateAnswerIsEmptyShowsNoRowsOnceItLands() async throws {
        let gate = folder.appendingPathComponent("gate")
        try slowAnswer(gate: gate, rows: "true")
        try await showGrid()

        model.query = "3"
        FileManager.default.createFile(atPath: gate.path, contents: Data())

        try await wait("no rows") { self.model.visible.isEmpty }
    }

    func testASearchThatFindsNothingKeepsTheKeysOfTheFooter() async throws {
        try await showGrid()

        model.query = "zzz"

        XCTAssertFalse(model.hint.contains("Type /"))
    }

    func testANarrowedKeyRanksOnlyTheMatchesOfTheLastKey() {
        let list = ItemList(items: items(["Safe", "Safety", "Safari"] + (0..<1000).map { "Row \($0)" }))
        var search = PanelSearch()
        _ = search.matching(SearchQuery(text: "saf", layouts: []), in: [list])

        let found = search.matching(SearchQuery(text: "safa", layouts: []), in: [list])

        XCTAssertEqual(search.rankedCount, 3)
        XCTAssertEqual(found.map(\.item.title), ["Safari"])
    }

    func testTheRowsOfAListWithSearchOffAreNotSearched() {
        let off = ItemList(items: items(["Create a new key", "Use my words"]), search: .off)
        let list = ItemList(items: items(["Safe"]))
        var search = PanelSearch()

        let found = search.matching(SearchQuery(text: "s", layouts: []), in: [off, list])

        XCTAssertEqual(found.map(\.item.title), ["Safe"])
    }

    func testAKeyThatDoesNotNarrowRanksEachItem() {
        let list = ItemList(items: items(["Safe", "Notes", "Signal"]))
        var search = PanelSearch()
        _ = search.matching(SearchQuery(text: "sa", layouts: []), in: [list])

        _ = search.matching(SearchQuery(text: "sig", layouts: []), in: [list])

        XCTAssertEqual(search.rankedCount, 3)
    }

    func testNewRowsAreSearchedWhole() {
        var list = ItemList(items: items(["Safe", "Notes"]))
        var search = PanelSearch()
        _ = search.matching(SearchQuery(text: "saf", layouts: []), in: [list])
        list.replace(items(["Safe", "Notes", "Safari"]))

        let found = search.matching(SearchQuery(text: "safa", layouts: []), in: [list])

        XCTAssertEqual(found.map(\.item.title), ["Safari"])
    }

    func testANewPickOrSearchKindRanksEachItemAgain() {
        var list = ItemList(items: items(["Safe", "Notes", "Safari"]))
        var search = PanelSearch()
        _ = search.matching(SearchQuery(text: "saf", layouts: []), in: [list])
        list.remember(list.all[2])

        let picked = search.matching(SearchQuery(text: "safa", layouts: []), in: [list])
        XCTAssertEqual(search.rankedCount, 3)
        list.take(search: .script)
        _ = search.matching(SearchQuery(text: "safar", layouts: []), in: [list])

        XCTAssertEqual(picked.map(\.item.title), ["Safari"])
        XCTAssertEqual(search.rankedCount, 3)
    }

    func testAListThatItsScriptSearchesIsFoldedOnceForAllKeys() {
        let list = ItemList(items: items(["Safe", "Notes", "Safari"]), search: .script)
        var search = PanelSearch()

        for text in ["s", "sa", "saf", "safa", "sa"] { _ = search.matching(SearchQuery(text: text, layouts: []), in: [list]) }

        XCTAssertEqual(search.indexBuilds, 1)
    }

    func testNewRowsOfAListThatItsScriptSearchesAreFoldedAgain() {
        var list = ItemList(items: items(["Safe", "Notes"]), search: .script)
        var search = PanelSearch()
        _ = search.matching(SearchQuery(text: "n", layouts: []), in: [list])
        list.answer(items(["Notes", "Numbers"]), to: "")

        let found = search.matching(SearchQuery(text: "nu", layouts: []), in: [list])

        XCTAssertEqual(found.map(\.item.title), ["Numbers"])
        XCTAssertEqual(search.indexBuilds, 2)
    }

    func testAGrowingSearchFindsWhatAFreshSearchFinds() {
        let lists = [ItemList(items: items(["axbxc", "abc", "Abacus", "cab", "a b c", "xabcx", "Notes"]), recent: ["cab"]), ItemList(items: items(["Cabinet", "Abc Store"]))]
        var search = PanelSearch()
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
