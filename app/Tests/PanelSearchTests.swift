import XCTest
@testable import OpenspotCore

@MainActor
final class PanelSearchTests: PanelCase {
    private func showGrid() async throws {
        try script("alpha", header: "title=Alpha", "true")
        try script("beta", header: "title=Beta", "true")
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

    func testASpotThatOffersNoPlaceIsNotFound() async throws {
        try await showGrid()
        try script("hidden", header: "title=Alphabet\noffers=none", "true")
        try script("acts", header: "title=Alpha acts\n\nbutton=change\ntitle=Change\noffers=actions", "true")
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
        XCTAssertEqual(host.dismissals, 1)
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

        XCTAssertEqual(host.dismissals, 1)
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
