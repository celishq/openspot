import XCTest
@testable import OpenspotCore

@MainActor
final class FlowMoveTests: PanelCase {
    private var client: URL!

    override func setUp() async throws {
        try await super.setUp()
        client = folder.appendingPathComponent("A.app/Contents/Helpers/openspot")
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: client)
        model.runs.api = CommandAPI(mac: Mac(), places: model.files, app: ModelApp(model: model), runs: model.runs, rates: .offline)
    }

    func openFlowSpot() async throws {
        try writeFlow()
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("flow")
        try await wait("the flow") { self.model.transition.phase == .open && self.titles == ["Page first"] && self.model.sheets["flow"]?.spot.actions.count == 5 }
    }

    private func writeFlow() throws {
        try script("flow", toml: "title = 'Flow'\non = ['sheet.open']\npages = ['n*', 'swapped']", """
        os='\(client.path)'
        page=$(sed -n 's/^route=//p')
        case "$1" in
          show) printf 'button=done\\ntitle=Done\\nscope=spot\\n\\nbutton=top\\ntitle=Top\\nscope=spot\\n\\nbutton=next\\ntitle=Next\\nscope=spot\\n\\nbutton=swap\\ntitle=Swap\\nscope=spot\\n\\nbutton=leave\\ntitle=Leave\\nscope=spot\\n\\ntext=x\\ntitle=Page %s\\n' "${page:-first}" ;;
          done) "$os" route back ;;
          top) "$os" route back --root ;;
          leave) "$os" route close ;;
          next) "$os" route push "n${#page}" ;;
          swap) "$os" route push swapped --replace ;;
        esac
        """)
    }

    private func openFlowSheetInPlace() async throws {
        try await wait("the flow over the list") { self.model.openSheetID == "flow" && self.titles == ["Page first"] && self.model.sheets["flow"]?.spot.actions.count == 5 }
    }

    private func pressFlow(_ id: String) throws {
        let sheet = try XCTUnwrap(model.sheets["flow"])
        sheet.run(try XCTUnwrap(sheet.spot.actions.first { $0.id == id }), item: nil)
    }

    func testAPressPushesAPageOfItsSpotAndGoesBackAndToTheFirstSheet() async throws {
        try await openFlowSpot()

        try pressFlow("next")
        try await wait("the first page") { self.titles == ["Page n0"] }
        try pressFlow("next")
        try await wait("the second page") { self.titles == ["Page n2"] }
        try pressFlow("done")
        try await wait("the first page again") { self.titles == ["Page n0"] }
        try pressFlow("next")
        try await wait("the second page again") { self.titles == ["Page n2"] && self.model.flow.pages.count == 3 }
        try pressFlow("top")

        try await wait("the first sheet") { self.titles == ["Page first"] && self.model.flow.index == 0 }
    }

    func testAPressThatReplacesTakesThePlaceOfThePageThatShows() async throws {
        try await openFlowSpot()
        try pressFlow("next")
        try await wait("the first page") { self.titles == ["Page n0"] }

        try pressFlow("swap")

        try await wait("the swapped page") { self.titles == ["Page swapped"] }
        XCTAssertEqual(model.flow.pages, [FlowSheet(spot: "flow"), FlowSheet(spot: "flow", page: "swapped")])
    }

    func testAllOnTheFirstSheetStaysAndOnePopReturnsToTheSpotThatPushedIt() async throws {
        try writeFlow()
        try await openList()
        XCTAssertTrue(model.push(FlowSheet(spot: "flow")))
        try await openFlowSheetInPlace()

        try pressFlow("top")
        try await wait("the end of the press") { self.model.sheets["flow"]?.calls.isEmpty == true && !self.model.runs.isReading }
        XCTAssertEqual(model.openSheetID, "flow")

        try pressFlow("done")

        try await wait("the list") { self.model.openSheetID == "list" && self.titles == ["A"] }
        XCTAssertNil(model.flow.ahead)
    }

    func testOnePopOnAFirstSheetWithNothingBehindItGoesBackToTheGrid() async throws {
        try await openFlowSpot()
        XCTAssertNil(model.flow.behind)

        try pressFlow("done")

        try await wait("the grid") { self.model.openSheetID == nil }
    }

    func testCloseFromAPageWithNothingBehindItsSpotGoesToTheGridWithNoStepBack() async throws {
        try await openFlowSpot()
        try pressFlow("next")
        try await wait("the first page") { self.titles == ["Page n0"] }
        try pressFlow("next")
        try await wait("the second page") { self.titles == ["Page n2"] && self.model.flowEdges.from == nil }
        host.edgeChanges = []

        try pressFlow("leave")

        try await wait("the grid") { self.model.openSheetID == nil }
        XCTAssertNil(host.edgeChanges.first { $0.edges.from != nil })
        XCTAssertEqual(model.flow.pages, [])
    }

    func testASheetThatClosesKeepsItsPageUntilItsMotionEnds() async throws {
        try await openFlowSpot()
        try pressFlow("next")
        try await wait("the first page") { self.titles == ["Page n0"] && self.model.flowEdges.from == nil }
        host.heldEnds = []

        try pressFlow("leave")

        try await wait("the close") { self.model.openSheetID == nil }
        XCTAssertNil(model.sheets["flow"]?.page)
        XCTAssertEqual(model.closingPage?.page, "n0")
        XCTAssertEqual(model.closingPage?.list.all.map(\.title), ["Page n0"])
        let ends = host.heldEnds ?? []
        host.heldEnds = nil
        ends.forEach { $0() }
        XCTAssertNil(model.closingPage)
    }

    func testCloseFromAPageGoesBackToTheSpotThatPushedItInOneStep() async throws {
        try writeFlow()
        try await openList()
        XCTAssertTrue(model.push(FlowSheet(spot: "flow")))
        try await openFlowSheetInPlace()
        try pressFlow("next")
        try await wait("the first page") { self.titles == ["Page n0"] && self.model.flowEdges.from == nil }
        host.edgeChanges = []

        try pressFlow("leave")

        try await wait("the list") { self.model.openSheetID == "list" && self.titles == ["A"] && self.model.flowEdges.from == nil }
        XCTAssertEqual(host.edgeChanges.filter { $0.edges.sheetStart != nil }.count, 1)
        XCTAssertEqual(model.flow.pages, [FlowSheet(spot: "list")])
    }

    func testTheCommandStepsBackOnlyWithinTheSpotThatShows() async throws {
        try await openList()
        try await openPage()

        XCTAssertFalse(model.pop(in: "other"))
        XCTAssertTrue(model.pop(in: "list"))

        try await wait("the sheet before") { self.titles == ["A"] }
        XCTAssertFalse(model.pop(in: "list"))
    }

    func testAPushOfAPageThatTheSpotDoesNotTakeMovesNothingAndSaysSo() async throws {
        try await openList()
        try script("narrow", toml: "title = 'Narrow'\non = ['sheet.open']\npages = ['ok:*']", "printf 'text=n\\ntitle=N\\n'")
        await model.reload()

        XCTAssertTrue(model.push(FlowSheet(spot: "narrow", page: "bad")))

        XCTAssertEqual(model.openSheetID, "list")
        XCTAssertEqual(host.notes.last, "Narrow takes no page bad. Add bad to the pages of its spot.toml")
    }
}
