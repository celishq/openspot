import XCTest
@testable import OpenspotCore

@MainActor
final class FlowNavigationTests: PanelCase {
    func testARowThatOpensAPagePushesItAndKeepsThePanelOpen() async throws {
        try await openList()

        try await openPage()

        XCTAssertEqual(model.flow.current, FlowSheet(spot: "list", page: "a"))
        XCTAssertEqual(model.openList, "list")
        XCTAssertEqual(host.dismissals, 0)
    }

    func testBackShowsTheSheetBeforeAtOnceAndForwardShowsThePageAgain() async throws {
        try await openList()
        try await openPage()

        XCTAssertTrue(model.handleKey(back))
        XCTAssertEqual(titles, ["A"])
        XCTAssertEqual(model.flow.ahead, FlowSheet(spot: "list", page: "a"))

        XCTAssertTrue(model.handleKey(forward))
        XCTAssertEqual(titles, ["Detail a"])
    }

    func testEscClearsTheSearchThenStepsBackThenClosesTheSheet() async throws {
        try await openList()
        try await openPage()
        model.searchText = "de"

        XCTAssertTrue(model.handleKey(escape))
        XCTAssertEqual(model.searchText, "")
        XCTAssertTrue(model.handleKey(escape))
        XCTAssertEqual(titles, ["A"])
        XCTAssertEqual(model.openList, "list")
        XCTAssertTrue(model.handleKey(escape))

        try await waitFor("the grid") { self.model.openList == nil }
        XCTAssertNil(model.flow.current)
    }

    func testCommandEscGoesToTheGridFromAPageAndTheSpotShowsItsFirstSheetNextTime() async throws {
        try await openList()
        try await openPage()

        XCTAssertTrue(model.handleKey(toGrid))

        try await waitFor("the grid") { self.model.openList == nil }
        XCTAssertNil(model.flow.current)
        XCTAssertNil(model.sheets["list"]?.page)
    }

    func testASpotThatOpensAnotherPushesItAndBackComesHome() async throws {
        try await openList()

        XCTAssertTrue(model.push(FlowSheet(spot: "other")))
        try await waitFor("the other sheet") { self.model.openList == "other" && self.titles == ["Other"] }

        XCTAssertTrue(model.handleKey(back))
        try await waitFor("the first sheet") { self.model.openList == "list" && self.titles == ["A"] }
        XCTAssertEqual(model.flow.ahead, FlowSheet(spot: "other"))
    }

    func testAPageOpensFromOutsideTheSpot() async throws {
        try await openList()

        XCTAssertTrue(model.push(FlowSheet(spot: "list", page: "a")))

        try await waitFor("the page") { self.titles == ["Detail a"] }
        XCTAssertEqual(model.behindTitles, ["List"])
        XCTAssertEqual(model.flow.current?.title, "A")
        XCTAssertEqual(model.flow.pages, [FlowSheet(spot: "list"), FlowSheet(spot: "list", page: "a")])
    }

    func testTheHintOfAPageSaysThatEscGoesBack() async throws {
        try script("info", header: "on=sheet.open\npages=a", """
        if [ -n "$OPENSPOT_PAGE" ]; then printf 'text=detail\\ntitle=Detail\\n'; else printf 'text=first\\ntitle=First\\n\\nrow=a\\ntitle=A\\npush=true\\n'; fi
        """)
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("info")
        try await waitFor("the first sheet") { self.model.openPanel?.parts.first?.title == "First" }
        XCTAssertTrue(model.push(FlowSheet(spot: "info", page: "a")))

        try await waitFor("the page of parts") { self.model.openPanel?.parts.first?.title == "Detail" }

        XCTAssertEqual(model.hint, "Esc Back")
    }

    func testAPageOfTheSameSheetSlidesInFromTheSideItComesFrom() async throws {
        try await openList()
        host.motions = []
        try await openPage()
        try await waitFor("the slide from the right to rest") { self.host.motions.contains(.push) && self.model.pushOffset == 0 }
        XCTAssertTrue(host.pushStarts.contains { $0 > 0 })
        host.pushStarts = []

        XCTAssertTrue(model.handleKey(back))

        try await waitFor("the slide from the left to rest") { self.model.pushOffset == 0 && self.host.pushStarts.contains { $0 < 0 } }
    }

    func testEachSheetBehindHasATitleAndAClickOnItsEdgeGoesBackToIt() async throws {
        try await openList()
        try await openPage()
        XCTAssertTrue(model.push(FlowSheet(spot: "other")))
        try await waitFor("the other sheet") { self.model.openList == "other" && self.titles == ["Other"] }

        XCTAssertEqual(model.behindTitles, ["A", "List"])

        XCTAssertTrue(model.back(steps: 2))
        try await waitFor("the first sheet") { self.model.openList == "list" && self.titles == ["A"] }
        XCTAssertEqual(model.behindTitles, [])
    }

    func testAnotherSpotOfTheFlowPushesInFromTheRightAndComesBackFromTheLeft() async throws {
        try await openList()
        host.pushStarts = []

        XCTAssertTrue(model.push(FlowSheet(spot: "other")))
        try await waitFor("the push to rest") { self.model.openList == "other" && self.model.pushOffset == 0 && !self.host.pushStarts.isEmpty }
        XCTAssertEqual(host.pushStarts.first.map { $0 > 0 }, true)
        host.pushStarts = []

        XCTAssertTrue(model.handleKey(back))

        try await waitFor("the way back to rest") { self.model.openList == "list" && self.model.pushOffset == 0 && !self.host.pushStarts.isEmpty }
        XCTAssertEqual(host.pushStarts.first.map { $0 < 0 }, true)
    }


    func testOpenStartsANewFlowWithNothingBehind() async throws {
        try await openList()
        try await openPage()

        XCTAssertTrue(model.open("other"))

        try await waitFor("the other spot") { self.model.openList == "other" && self.titles == ["Other"] }
        XCTAssertEqual(model.flow.pages, [FlowSheet(spot: "other")])
        XCTAssertNil(model.sheets["list"]?.page)
    }

    func testARunForgetsWhatEachPageShowedOnceThePageLeavesTheFlow() async throws {
        try await openList()
        try await openPage()
        XCTAssertTrue(model.handleKey(back))
        XCTAssertEqual(model.sheets["list"]?.pageStates.map(\.page), ["a"])

        XCTAssertTrue(model.handleKey(toGrid))

        try await waitFor("the grid") { self.model.openList == nil }
        XCTAssertEqual(model.sheets["list"]?.pageStates.count, 0)
    }
}
