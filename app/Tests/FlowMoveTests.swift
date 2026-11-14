import XCTest
@testable import OpenspotCore

@MainActor
final class FlowMoveTests: PanelCase {
    func openFlowSpot() async throws {
        try writeFlow()
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("flow")
        try await waitFor("the flow") { self.model.transition.phase == .open && self.titles == ["Page first"] && self.model.sheets["flow"]?.spot.actions.count == 5 }
    }

    private func writeFlow() throws {
        try script("flow", header: "title=Flow\non=sheet.open\npages=n*\npages=swapped", """
        case "$1" in
          read) printf 'button=done\\ntitle=Done\\nscope=spot\\n\\nbutton=top\\ntitle=Top\\nscope=spot\\n\\nbutton=next\\ntitle=Next\\nscope=spot\\n\\nbutton=swap\\ntitle=Swap\\nscope=spot\\n\\nbutton=hand\\ntitle=Hand\\nscope=spot\\n\\nrow=x\\ntitle=Page %s\\n' "${OPENSPOT_PAGE-first}" ;;
          done) printf 'pop=true\\n' ;;
          top) printf 'pop=all\\n' ;;
          next) printf 'push=n%s\\n' "${#OPENSPOT_PAGE}" ;;
          swap) printf 'push=swapped\\npush.replace=true\\n' ;;
          hand) printf 'push.spot=other\\n' ;;
        esac
        """)
    }

    private func openFlowSheetInPlace() async throws {
        try await waitFor("the flow over the list") { self.model.openList == "flow" && self.titles == ["Page first"] && self.model.sheets["flow"]?.spot.actions.count == 5 }
    }

    private func pressFlow(_ id: String) throws {
        let sheet = try XCTUnwrap(model.sheets["flow"])
        sheet.run(try XCTUnwrap(sheet.spot.actions.first { $0.id == id }), item: nil)
    }

    func testAPressPushesAPageOfItsSpotAndGoesBackAndToTheFirstSheet() async throws {
        try await openFlowSpot()

        try pressFlow("next")
        try await waitFor("the first page") { self.titles == ["Page n0"] }
        try pressFlow("next")
        try await waitFor("the second page") { self.titles == ["Page n2"] }
        try pressFlow("done")
        try await waitFor("the first page again") { self.titles == ["Page n0"] }
        try pressFlow("next")
        try await waitFor("the second page again") { self.titles == ["Page n2"] && self.model.flow.pages.count == 3 }
        try pressFlow("top")

        try await waitFor("the first sheet") { self.titles == ["Page first"] && self.model.flow.index == 0 }
    }

    func testAPressThatReplacesTakesThePlaceOfThePageThatShows() async throws {
        try await openFlowSpot()
        try pressFlow("next")
        try await waitFor("the first page") { self.titles == ["Page n0"] }

        try pressFlow("swap")

        try await waitFor("the swapped page") { self.titles == ["Page swapped"] }
        XCTAssertEqual(model.flow.pages, [FlowSheet(spot: "flow"), FlowSheet(spot: "flow", page: "swapped")])
    }

    func testAllOnTheFirstSheetStaysAndOnePopReturnsToTheSpotThatPushedIt() async throws {
        try writeFlow()
        try await openList()
        XCTAssertTrue(model.push(FlowSheet(spot: "flow")))
        try await openFlowSheetInPlace()

        try pressFlow("top")
        try await waitFor("the end of the press") { self.model.sheets["flow"]?.calls.isEmpty == true && !self.model.runs.isReading }
        XCTAssertEqual(model.openList, "flow")

        try pressFlow("done")

        try await waitFor("the list") { self.model.openList == "list" && self.titles == ["A"] }
        XCTAssertEqual(model.flow.ahead, FlowSheet(spot: "flow"))
    }

    func testAPressPushesAnotherSpotOverItsSheet() async throws {
        try writeFlow()
        try await openList()
        XCTAssertTrue(model.push(FlowSheet(spot: "flow")))
        try await openFlowSheetInPlace()

        try pressFlow("hand")

        try await waitFor("the other spot") { self.model.openList == "other" && self.titles == ["Other"] }
        XCTAssertEqual(model.behindTitles, ["Flow", "List"])
    }

    func testAReadThatPushesMovesNothing() async throws {
        try script("reader", header: "title=Reader\non=sheet.open", "printf 'push=elsewhere\\n\\nrow=r\\ntitle=R\\n'")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("reader")

        try await waitFor("the reader") { self.titles == ["R"] && !self.model.runs.isReading }

        XCTAssertEqual(model.flow.pages, [FlowSheet(spot: "reader")])
    }

    func testTheCommandStepsBackOnlyWithinTheSpotThatShows() async throws {
        try await openList()
        try await openPage()

        XCTAssertFalse(model.pop(in: "other"))
        XCTAssertTrue(model.pop(in: "list"))

        XCTAssertEqual(titles, ["A"])
        XCTAssertFalse(model.pop(in: "list"))
    }

    func testAPushOfAPageThatTheSpotDoesNotTakeMovesNothingAndSaysSo() async throws {
        try await openList()
        try script("narrow", header: "title=Narrow\non=sheet.open\npages=ok:*", "printf 'row=n\\ntitle=N\\n'")
        model.reload()

        XCTAssertTrue(model.push(FlowSheet(spot: "narrow", page: "bad")))

        XCTAssertEqual(model.openList, "list")
        XCTAssertEqual(host.notes.last, "Narrow takes no page bad. Add pages=bad to its header")
    }
}
