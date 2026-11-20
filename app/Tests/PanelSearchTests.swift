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

    func testAKeyRanksTheSpotsAwayFromTheMainThreadAndShowsThemWhenTheyLand() async throws {
        try await showGrid()
        let grid = shown
        let ranks = SearchRanks()

        SearchRanks.$meter.withValue(ranks) { model.query = "al" }

        XCTAssertEqual(shown, grid)
        XCTAssertEqual(ranks.count, 0)
        try await wait("the found spots") { self.shown == ["alpha"] }
        XCTAssertEqual(ranks.count, 1)
        XCTAssertEqual(ranks.countOnMain, 0)
    }

    func testASpotThatListsWantIsAskedOnceWhenItsRowsFirstShowInEachPanelOpen() async throws {
        let log = folder.appendingPathComponent("wants")
        try script("tabs", toml: "title = 'Tabs'\non = ['sheet.open', 'spot.want']\noffers = ['search']", "sed -n 's/^event=//p' >> '\(log.path)'\nprintf 'text=current\\ntitle=Snooze Current Tab\\n'")
        try script("other", toml: "title = 'Other'\noffers = ['search']", "printf 'text=x\\ntitle=Snore\\n'")
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
        try script("tabs", toml: "title = 'Tabs'\non = ['sheet.open', 'spot.want']", "sed -n 's/^event=//p' >> '\(log.path)'\nprintf 'text=current\\ntitle=Snooze Current Tab\\n'")
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

    func testASpotThatOnlyOffersActionsIsNotFound() async throws {
        try await showGrid()
        try script("acts", toml: "title = 'Alpha acts'\n[commands.change]\ntitle = 'Change'\noffers = ['actions']", "true")
        await model.reload()

        model.query = "al"

        try await wait("the found spots") { !self.shown.contains("beta") }
        XCTAssertEqual(shown, ["alpha"])
    }

    func testTheNextKeyCancelsTheSearchOfTheKeyBefore() async throws {
        try await showGrid()
        let ranks = SearchRanks()

        SearchRanks.$meter.withValue(ranks) {
            model.query = "b"
            model.query = "al"
        }

        try await wait("the found spots") { self.shown == ["alpha"] }
        try await wait("the end of the first search") { ranks.dropped == 1 }
        XCTAssertEqual(ranks.count, 1)
    }

    func testAResultForAnOlderTextNeverLandsOverANewerOne() async throws {
        try await showGrid()
        let hold = DispatchSemaphore(value: 0)
        let ranks = SearchRanks(gate: { number in if number == 1 { hold.wait() } })

        SearchRanks.$meter.withValue(ranks) { model.query = "b" }
        try await wait("the first search in flight") { ranks.count == 1 }
        SearchRanks.$meter.withValue(ranks) { model.query = "al" }
        try await wait("the newer spots") { self.shown == ["alpha"] }
        hold.signal()

        try await wait("the end of the first search") { ranks.dropped == 1 }
        XCTAssertEqual(shown, ["alpha"])
        XCTAssertEqual(ranks.count, 2)
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
        try await wait("the end of the search in flight") { ranks.dropped == 1 }
        XCTAssertEqual(ranks.count, 1)
    }

    func testAKeyWithNoCommandActsOnTheSpotsOfTheNewText() async throws {
        try await showGrid()

        model.query = "bet"
        _ = model.handleKey(ActionKey(name: "\t"))

        XCTAssertEqual(shown, ["beta"])
    }

    func testAClickRunsTheCardThatThePersonSawWhileANewerTextIsStillSearched() async throws {
        try await showGrid()

        model.query = "bet"
        model.tap("alpha")

        try await wait("the sheet of the card") { self.model.openSheetID == "alpha" }
    }

    func testClearingTheTextShowsTheGridAtOnceAndDropsTheSearchInFlight() async throws {
        try await showGrid()
        let grid = shown
        let ranks = SearchRanks()

        SearchRanks.$meter.withValue(ranks) {
            model.query = "al"
            model.query = ""
        }

        XCTAssertEqual(shown, grid)
        try await wait("the end of the search in flight") { ranks.dropped == 1 }
        XCTAssertEqual(shown, grid)
        XCTAssertEqual(ranks.count, 0)
    }
}
