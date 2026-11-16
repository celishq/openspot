import XCTest
@testable import OpenspotCore

@MainActor
final class FlowNavigationTests: PanelCase {
    func testARowThatOpensAPagePushesItAndKeepsThePanelOpen() async throws {
        try await openList()

        try await openPage()

        XCTAssertEqual(model.flow.current, FlowSheet(spot: "list", page: "a"))
        XCTAssertEqual(model.openSheetID, "list")
        XCTAssertEqual(host.dismissals, 0)
    }

    func testBackShowsTheSheetBeforeAtOnceAndForwardShowsThePageAgain() async throws {
        try await openList()
        try await openPage()

        XCTAssertTrue(model.handleKey(back))
        try await wait("the sheet before") { self.titles == ["A"] }
        XCTAssertEqual(model.flow.ahead, FlowSheet(spot: "list", page: "a"))

        XCTAssertTrue(model.handleKey(forward))
        try await wait("the page again") { self.titles == ["Detail a"] }
    }

    func testEscClearsTheSearchThenStepsBackThenClosesTheSheet() async throws {
        try await openList()
        try await openPage()
        model.searchText = "de"
        model.landSearch()

        XCTAssertTrue(model.handleKey(escape))
        XCTAssertEqual(model.searchText, "")
        XCTAssertTrue(model.handleKey(escape))
        try await wait("the sheet before") { self.titles == ["A"] }
        XCTAssertEqual(model.openSheetID, "list")
        XCTAssertTrue(model.handleKey(escape))

        try await wait("the grid") { self.model.openSheetID == nil }
        XCTAssertNil(model.flow.current)
    }

    func testCommandEscGoesToTheGridFromAPageAndTheSpotShowsItsFirstSheetNextTime() async throws {
        try await openList()
        try await openPage()

        XCTAssertTrue(model.handleKey(toGrid))

        try await wait("the grid") { self.model.openSheetID == nil }
        XCTAssertNil(model.flow.current)
        XCTAssertNil(model.sheets["list"]?.page)
    }

    func testASpotThatOpensAnotherPushesItAndBackComesHome() async throws {
        try await openList()

        XCTAssertTrue(model.push(FlowSheet(spot: "other")))
        try await wait("the other sheet") { self.model.openSheetID == "other" && self.titles == ["Other"] }

        XCTAssertTrue(model.handleKey(back))
        try await wait("the first sheet") { self.model.openSheetID == "list" && self.titles == ["A"] }
        XCTAssertEqual(model.flow.ahead, FlowSheet(spot: "other"))
    }

    func testAPageOpensFromOutsideTheSpot() async throws {
        try await openList()

        XCTAssertTrue(model.push(FlowSheet(spot: "list", page: "a")))

        try await wait("the page") { self.titles == ["Detail a"] }
        XCTAssertEqual(model.flowEdges.titles(on: .behind), ["List"])
        XCTAssertEqual(model.flow.current?.title, "A")
        XCTAssertEqual(model.flow.pages, [FlowSheet(spot: "list"), FlowSheet(spot: "list", page: "a")])
    }

    func testTheHintOfAPageSaysThatEscGoesBack() async throws {
        try script("info", header: "on=sheet.open\npages=a", """
        if [ -n "$OPENSPOT_PAGE" ]; then printf 'text=detail\\ntitle=Detail\\n'; else printf 'text=first\\ntitle=First\\n\\nrow=a\\ntitle=A\\npush=true\\n'; fi
        """)
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("info")
        try await wait("the first sheet") { self.model.openParts?.parts.first?.title == "First" }
        XCTAssertTrue(model.push(FlowSheet(spot: "info", page: "a")))

        try await wait("the page of parts") { self.model.openParts?.parts.first?.title == "Detail" }

        XCTAssertEqual(model.hint, "Esc Back")
    }

    func testAPageStepMovesOnTheSheetMotionAndTheSheetItLeavesGlidesIntoTheBarBehind() async throws {
        try await openList()
        host.edgeChanges = []

        try await openPage()

        try await wait("the step to settle") { self.model.flowEdges.from == nil && self.model.flowEdges.titles(on: .behind) == ["List"] }
        let list = FlowSheet(spot: "list")
        let places = host.edgeChanges.map { $0.edges.edges.first { $0.sheet == list }?.place }
        XCTAssertEqual(places.first, .stand(try XCTUnwrap(host.edgeChanges.first?.edges.from)))
        XCTAssertTrue(places.dropFirst().allSatisfy { $0 == .bar(.behind, 0) })
        XCTAssertEqual(host.edgeChanges.map(\.motion), [nil, .flow, nil])
        XCTAssertEqual(host.edgeChanges.map(\.edges.isMoving), [false, true, false])
    }

    func testAStepSwapsThePageAtThePressAndHoldsACopyOfThePageItLeaves() async throws {
        try await openList()
        host.heldEnds = []

        XCTAssertTrue(model.push(FlowSheet(spot: "list", page: "a")))

        XCTAssertEqual(model.sheets["list"]?.page, "a")
        let held = try XCTUnwrap(model.flowEdges.leavingPage)
        XCTAssertEqual(held.list.shown.map(\.title), ["A"])
        XCTAssertEqual(held.rect, model.flowEdges.from)
        XCTAssertEqual(model.flowEdges.room(around: try XCTUnwrap(model.sheets["list"]?.sheetRect)), held.rect)
    }

    func testAStepSaysWhichSideItsNewPageComesFromUntilItEnds() async throws {
        try await openList()
        host.edgeChanges = []
        try await openPage()
        try await wait("the push to settle") { self.model.flowEdges.from == nil && self.model.flowEdges.titles(on: .behind) == ["List"] }
        let pushed = host.edgeChanges.map(\.edges.coming)
        host.edgeChanges = []

        XCTAssertTrue(model.handleKey(back))

        try await wait("the back to settle") { self.model.flowEdges.from == nil && self.model.flowEdges.titles(on: .ahead) == ["A"] }
        XCTAssertEqual(pushed.first, .ahead)
        XCTAssertEqual(pushed.last, .some(nil))
        XCTAssertEqual(host.edgeChanges.first?.edges.coming, .behind)
        XCTAssertEqual(host.edgeChanges.last?.edges.coming, .some(nil))
    }

    func testAPushedPageMovesOnlyOnceItsFirstRowsAreIn() async throws {
        try await openList()
        host.edgeChanges = []

        try await openPage()

        try await wait("the step to settle") { self.model.flowEdges.from == nil && self.model.flowEdges.titles(on: .behind) == ["List"] }
        XCTAssertEqual(host.edgeChanges.first { $0.motion == .flow }?.rows, ["Detail a"])
    }

    func testPressesDuringAStepWaitForItThenMakeOneStepToTheNewestPage() async throws {
        try await openList()
        host.heldEnds = []
        XCTAssertTrue(model.push(FlowSheet(spot: "list", page: "a")))
        try await wait("the step to move") { self.model.flowEdges.isMoving }

        XCTAssertTrue(model.handleKey(back))
        XCTAssertTrue(model.handleKey(forward))
        XCTAssertTrue(model.handleKey(back))

        XCTAssertEqual(model.sheets["list"]?.page, "a")
        let ends = host.heldEnds ?? []
        host.heldEnds = nil
        host.edgeChanges = []
        ends.forEach { $0() }
        try await wait("one step to the newest page") { self.model.sheets["list"]?.page == nil && self.model.flowEdges.from == nil }
        XCTAssertEqual(model.flowEdges.titles(on: .ahead), ["A"])
        XCTAssertEqual(host.edgeChanges.filter { $0.motion == .flow }.count, 1)
    }

    func testAPressStartsItsStepOnceTheStepBeforeIsLogicallyCompleteThoughItsAnimationStillRuns() async throws {
        try await openList()
        host.heldRemovals = []
        XCTAssertTrue(model.push(FlowSheet(spot: "list", page: "a")))
        try await wait("the step to move") { self.model.flowEdges.isMoving }

        XCTAssertTrue(model.handleKey(back))

        try await wait("the back step at the press") { self.model.sheets["list"]?.page == nil }
        let removals = host.heldRemovals ?? []
        host.heldRemovals = nil
        removals.forEach { $0() }
        try await wait("the back step to settle") { self.model.flowEdges.from == nil && self.model.flowEdges.titles(on: .ahead) == ["A"] }
    }

    func testBackPutsThePageItLeavesInABarAheadThatAClickGoesForwardTo() async throws {
        try await openList()
        try await openPage()

        XCTAssertTrue(model.handleKey(back))

        try await wait("the bar ahead") { self.model.flowEdges.titles(on: .ahead) == ["A"] && self.model.flowEdges.from == nil }
        XCTAssertEqual(model.flowEdges.titles(on: .behind), [])
        XCTAssertTrue(model.forward(steps: 1))
        try await wait("the page again") { self.titles == ["Detail a"] && self.model.flowEdges.titles(on: .behind) == ["List"] }
    }

    func testBackGrowsTheSheetOutOfTheLineBehindAndThePageLeftGoesIntoALineAhead() async throws {
        try await openList()
        try await openPage()
        try await wait("the step to settle") { self.model.flowEdges.from == nil }
        host.edgeChanges = []

        XCTAssertTrue(model.handleKey(back))

        try await wait("the step to settle") { self.model.flowEdges.from == nil && self.model.flowEdges.titles(on: .ahead) == ["A"] }
        let start = try XCTUnwrap(host.edgeChanges.first?.edges)
        XCTAssertEqual(start.sheetStart, .bar(.behind, 0))
        XCTAssertEqual(start.leaving, .bar(.ahead, 0))
        XCTAssertFalse(start.edges.contains { $0.sheet == FlowSheet(spot: "list") })
        XCTAssertEqual(start.leavingEdge?.sheet, FlowSheet(spot: "list", page: "a"))
    }

    func testAPushGrowsTheSheetOutOfANewLineOnTheRight() async throws {
        try await openList()
        host.edgeChanges = []

        try await openPage()

        try await wait("the step to settle") { self.model.flowEdges.from == nil && self.model.flowEdges.titles(on: .behind) == ["List"] }
        let start = try XCTUnwrap(host.edgeChanges.first?.edges)
        XCTAssertEqual(start.sheetStart, .bar(.ahead, 0))
        XCTAssertEqual(start.leaving, .bar(.behind, 0))
        XCTAssertNil(host.edgeChanges.first { $0.edges.edges.contains { $0.sheet == FlowSheet(spot: "list", page: "a") } })
    }

    func testEscPopsThePageSoNothingWaitsAheadAndItLeavesNoLine() async throws {
        try await openList()
        try await openPage()
        try await wait("the step to settle") { self.model.flowEdges.from == nil }
        host.edgeChanges = []

        XCTAssertTrue(model.handleKey(escape))

        try await wait("the step to settle") { self.titles == ["A"] && self.model.flowEdges.from == nil }
        XCTAssertEqual(model.flow.pages, [FlowSheet(spot: "list")])
        XCTAssertEqual(model.flowEdges.titles(on: .ahead), [])
        XCTAssertEqual(host.edgeChanges.first?.edges.leaving, .line(.ahead))
        XCTAssertTrue(model.handleKey(forward))
        XCTAssertEqual(model.flow.index, 0)
    }

    func testEachSheetBehindHasATitleAndAClickOnItsEdgeGoesBackToIt() async throws {
        try await openList()
        try await openPage()
        XCTAssertTrue(model.push(FlowSheet(spot: "other")))
        try await wait("the other sheet") { self.model.openSheetID == "other" && self.titles == ["Other"] }

        try await wait("the bars behind") { self.model.flowEdges.titles(on: .behind) == ["A", "List"] }

        XCTAssertTrue(model.back(steps: 2))
        try await wait("the first sheet") { self.model.openSheetID == "list" && self.titles == ["A"] }
        try await wait("no bar behind") { self.model.flowEdges.titles(on: .behind) == [] }
        XCTAssertEqual(model.flowEdges.titles(on: .ahead), ["A", "Other"])
    }

    func testAnotherSpotOfTheFlowMovesOnTheSheetMotionAndItsSheetBeforeGlidesIntoTheBarBehind() async throws {
        try await openList()
        host.edgeChanges = []

        XCTAssertTrue(model.push(FlowSheet(spot: "other")))

        try await wait("the step to settle") { self.model.openSheetID == "other" && self.model.flowEdges.from == nil && self.model.flowEdges.titles(on: .behind) == ["List"] }
        let list = FlowSheet(spot: "list")
        let places = host.edgeChanges.compactMap { change in change.edges.edges.first { $0.sheet == list }.map { (change.motion, $0.place) } }
        XCTAssertEqual(places.first?.1, .stand(try XCTUnwrap(host.edgeChanges.first?.edges.from)))
        XCTAssertEqual(places.dropFirst().first?.0, .flow)
        XCTAssertEqual(places.last?.1, .bar(.behind, 0))
    }

    func testOpenStartsANewFlowWithNothingBehind() async throws {
        try await openList()
        try await openPage()

        XCTAssertTrue(model.open("other"))

        try await wait("the other spot") { self.model.openSheetID == "other" && self.titles == ["Other"] }
        XCTAssertEqual(model.flow.pages, [FlowSheet(spot: "other")])
        XCTAssertNil(model.sheets["list"]?.page)
    }

    func testASheetWithNoCardGrowsFromTheFieldAndShrinksBackIntoIt() async throws {
        try script("hidden", header: "on=sheet.open\noffers=search", "printf 'row=h\\ntitle=Hidden\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        XCTAssertNil(SpotSheetCard.of("hidden", in: model))

        XCTAssertTrue(model.open("hidden"))
        try await wait("the open sheet") { self.model.transition.phase == .open && self.titles == ["Hidden"] }
        XCTAssertTrue(host.motions.contains(.sheet(isOpen: true)))

        model.closeSheet(moving: true)
        XCTAssertTrue(host.motions.contains(.sheet(isOpen: false)))
    }

    func testAnOpenKeyStartsANewFlowWithNothingBehind() async throws {
        try await openList()
        try await openPage()

        model.press(GlobalKey(spot: "other", act: .open, trigger: .key(try XCTUnwrap(Shortcut(text: "ctrl+h")))))

        try await wait("the other spot") { self.model.openSheetID == "other" && self.titles == ["Other"] }
        XCTAssertEqual(model.flow.pages, [FlowSheet(spot: "other")])
        try await wait("no bar behind") { self.model.flowEdges.from == nil && self.model.flowEdges.titles(on: .behind) == [] }
    }

    func testARunForgetsWhatEachPageShowedOnceThePageLeavesTheFlow() async throws {
        try await openList()
        try await openPage()
        XCTAssertTrue(model.handleKey(back))
        try await wait("the page kept") { self.model.sheets["list"]?.pageStates.map(\.page) == ["a"] }

        XCTAssertTrue(model.handleKey(toGrid))

        try await wait("the grid") { self.model.openSheetID == nil }
        XCTAssertEqual(model.sheets["list"]?.pageStates.count, 0)
    }
}
