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
        try await waitFor("the sheet before") { self.titles == ["A"] }
        XCTAssertEqual(model.flow.ahead, FlowSheet(spot: "list", page: "a"))

        XCTAssertTrue(model.handleKey(forward))
        try await waitFor("the page again") { self.titles == ["Detail a"] }
    }

    func testEscClearsTheSearchThenStepsBackThenClosesTheSheet() async throws {
        try await openList()
        try await openPage()
        model.searchText = "de"

        XCTAssertTrue(model.handleKey(escape))
        XCTAssertEqual(model.searchText, "")
        XCTAssertTrue(model.handleKey(escape))
        try await waitFor("the sheet before") { self.titles == ["A"] }
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
        XCTAssertEqual(model.flowEdges.titles(on: .behind), ["List"])
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

    func testAPageStepMovesOnTheSheetMotionAndTheSheetItLeavesGlidesIntoTheBarBehind() async throws {
        try await openList()
        host.edgeChanges = []

        try await openPage()

        try await waitFor("the step to settle") { self.model.flowEdges.from == nil && self.model.flowEdges.titles(on: .behind) == ["List"] }
        let list = FlowSheet(spot: "list")
        let places = host.edgeChanges.map { $0.edges.edges.first { $0.sheet == list }?.place }
        XCTAssertEqual(places.first, .stand(try XCTUnwrap(host.edgeChanges.first?.edges.from)))
        XCTAssertEqual(Array(places.dropFirst()), [.bar(.behind, 0), .bar(.behind, 0)])
        XCTAssertEqual(host.edgeChanges.map(\.motion), [nil, .sheet(isOpen: true), nil])
    }

    func testBackPutsThePageItLeavesInABarAheadThatAClickGoesForwardTo() async throws {
        try await openList()
        try await openPage()

        XCTAssertTrue(model.handleKey(back))

        try await waitFor("the bar ahead") { self.model.flowEdges.titles(on: .ahead) == ["A"] && self.model.flowEdges.from == nil }
        XCTAssertEqual(model.flowEdges.titles(on: .behind), [])
        XCTAssertTrue(model.forward(steps: 1))
        try await waitFor("the page again") { self.titles == ["Detail a"] && self.model.flowEdges.titles(on: .behind) == ["List"] }
    }

    func testTheBarThatBecomesTheSheetFadesIntoItAndLeavesWhenTheStepEnds() async throws {
        try await openList()
        try await openPage()
        try await waitFor("the step to settle") { self.model.flowEdges.from == nil }
        host.edgeChanges = []

        XCTAssertTrue(model.handleKey(back))

        try await waitFor("the step to settle") { self.model.flowEdges.from == nil && self.model.flowEdges.titles(on: .ahead) == ["A"] }
        let list = FlowSheet(spot: "list")
        let moved = try XCTUnwrap(host.edgeChanges.first { $0.motion == .sheet(isOpen: true) }?.edges.edges.first { $0.sheet == list })
        XCTAssertEqual(moved.place, .sheet)
        XCTAssertTrue(moved.isFading)
        XCTAssertFalse(model.flowEdges.edges.contains { $0.sheet == list })
    }

    func testEachSheetBehindHasATitleAndAClickOnItsEdgeGoesBackToIt() async throws {
        try await openList()
        try await openPage()
        XCTAssertTrue(model.push(FlowSheet(spot: "other")))
        try await waitFor("the other sheet") { self.model.openList == "other" && self.titles == ["Other"] }

        try await waitFor("the bars behind") { self.model.flowEdges.titles(on: .behind) == ["A", "List"] }

        XCTAssertTrue(model.back(steps: 2))
        try await waitFor("the first sheet") { self.model.openList == "list" && self.titles == ["A"] }
        try await waitFor("no bar behind") { self.model.flowEdges.titles(on: .behind) == [] }
        XCTAssertEqual(model.flowEdges.titles(on: .ahead), ["A", "Other"])
    }

    func testAnotherSpotOfTheFlowMovesOnTheSheetMotionAndItsSheetBeforeGlidesIntoTheBarBehind() async throws {
        try await openList()
        host.edgeChanges = []

        XCTAssertTrue(model.push(FlowSheet(spot: "other")))

        try await waitFor("the step to settle") { self.model.openList == "other" && self.model.flowEdges.from == nil && self.model.flowEdges.titles(on: .behind) == ["List"] }
        let list = FlowSheet(spot: "list")
        let places = host.edgeChanges.compactMap { change in change.edges.edges.first { $0.sheet == list }.map { (change.motion, $0.place) } }
        XCTAssertEqual(places.first?.1, .stand(try XCTUnwrap(host.edgeChanges.first?.edges.from)))
        XCTAssertEqual(places.dropFirst().first?.0, .sheet(isOpen: true))
        XCTAssertEqual(places.dropFirst().first?.1, .bar(.behind, 0))
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
        try await waitFor("the page kept") { self.model.sheets["list"]?.pageStates.map(\.page) == ["a"] }

        XCTAssertTrue(model.handleKey(toGrid))

        try await waitFor("the grid") { self.model.openList == nil }
        XCTAssertEqual(model.sheets["list"]?.pageStates.count, 0)
    }
}
