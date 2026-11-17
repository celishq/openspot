import XCTest
@testable import OpenspotCore

@MainActor
final class PanelKeysTests: PanelCase {
    private let enter = ActionKey(name: "return")
    private let settings = ActionKey(name: "return", isCommand: true)
    private let actions = ActionKey(name: "k", isCommand: true)
    private let history = ActionKey(name: "y", isCommand: true)
    private let tab = ActionKey(name: "\t")
    private let up = ActionKey(name: "up")
    private let down = ActionKey(name: "down")
    private let left = ActionKey(name: "left")
    private let right = ActionKey(name: "right")

    private func showGrid() async throws {
        try script("alpha", header: "title=Alpha", "true")
        try script("beta", header: "title=Beta", "true")
        try script("weather", header: "title=Weather\non=sheet.open\npress=open", ":")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
    }

    private func select(_ id: String) throws {
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == id })
    }

    private func openInfo() async throws {
        try script("info", header: "on=sheet.open\npages=a", """
        if [ -n "$OPENSPOT_PAGE" ]; then printf 'text=detail\\ntitle=Detail\\n'; else printf 'text=first\\ntitle=First\\n'; fi
        """)
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("info")
        try await wait("the first sheet") { self.model.openParts?.parts.first?.title == "First" }
    }

    func testTheModeFollowsWhatTakesTheKeys() async throws {
        try await showGrid()
        XCTAssertEqual(model.mode, .grid)
        try select("weather")

        XCTAssertTrue(model.handleKey(actions))
        XCTAssertEqual(model.mode, .menu)
        XCTAssertTrue(model.handleKey(escape))
        XCTAssertEqual(model.mode, .grid)

        model.beginEditing()
        XCTAssertEqual(model.mode, .edit)
        model.toggleRecording(id: "alpha")
        XCTAssertEqual(model.mode, .recording)
        model.stopRecording()
        model.endEditing()
        XCTAssertEqual(model.mode, .grid)

        try await openList()
        XCTAssertEqual(model.mode, .sheet)
        XCTAssertTrue(model.handleKey(toGrid))
        try await wait("the grid") { self.model.mode == .grid }
    }

    func testTheCardsMoveOnlyWhileTheGridShowsInFront() async throws {
        try await showGrid()
        XCTAssertTrue(model.cardsMove)
        try select("weather")

        XCTAssertTrue(model.handleKey(actions))
        XCTAssertFalse(model.cardsMove)
        XCTAssertTrue(model.handleKey(escape))
        XCTAssertTrue(model.cardsMove)

        model.beginEditing()
        XCTAssertFalse(model.cardsMove)
        model.endEditing()
        XCTAssertTrue(model.cardsMove)

        model.isShown = false
        XCTAssertFalse(model.cardsMove)
        model.isShown = true

        try await openList()
        XCTAssertFalse(model.cardsMove)
    }

    func testASearchThatFindsNoSpotTeachesTheSlash() async throws {
        try script("list", header: "title=List\non=sheet.open", "printf 'row=a\\ntitle=A\\n'")
        await model.reload()

        model.query = "zzz"

        try await wait("the hint of the slash") { self.model.hint.hasPrefix("Type / and a spot's name to run it with text") }
        model.query = "lis"
        try await wait("the list found") { !self.model.visible.isEmpty }
        XCTAssertFalse(model.hint.contains("Type /"))
    }

    func testAKeyAddedInOneRowShowsInTheHint() async throws {
        try await showGrid()
        model.beginEditing()
        let rows = model.keyRows(of: .edit)

        XCTAssertEqual(KeyRow.hint(of: rows), "S Size   H Hide   ⇧ Arrows Move   Esc Done")
        XCTAssertEqual(model.hint, KeyRow.hint(of: rows))
        let added = rows + [KeyRow("x", words: "Extra") { _ in true }]
        XCTAssertEqual(KeyRow.hint(of: added), "S Size   H Hide   ⇧ Arrows Move   Esc Done   X Extra")
    }

    func testOnTheGridEscClearsTheSearchThenHidesAndTabGoesToTheText() async throws {
        try await showGrid()
        model.query = "al"
        model.landSearch()

        XCTAssertTrue(model.handleKey(escape))
        XCTAssertEqual(model.query, "")
        XCTAssertEqual(host.dismissals, 0)
        XCTAssertFalse(model.handleKey(tab))
        XCTAssertFalse(model.handleKey(history))
        XCTAssertFalse(model.handleKey(actions))
        XCTAssertTrue(model.handleKey(escape))
        XCTAssertEqual(host.dismissals, 1)
    }

    func testOnTheGridTheArrowsMoveBetweenCardsAndReturnRunsTheSelectedOne() async throws {
        try await showGrid()
        XCTAssertEqual(model.selected, 0)

        XCTAssertTrue(model.handleSearchKey(right))
        XCTAssertEqual(model.selected, 1)
        XCTAssertTrue(model.handleSearchKey(left))
        XCTAssertEqual(model.selected, 0)
        XCTAssertTrue(model.handleSearchKey(down))
        XCTAssertTrue(model.handleSearchKey(up))

        XCTAssertTrue(model.handleSearchKey(enter))
        XCTAssertEqual(host.dismissals, 1)
    }

    func testReturnAndTheArrowsStayWithAFieldThatIsNotTheSearchField() async throws {
        try await showGrid()

        XCTAssertFalse(model.handleKey(enter))
        XCTAssertFalse(model.handleKey(right))
        XCTAssertFalse(model.handleKey(down))

        XCTAssertEqual(model.selected, 0)
        XCTAssertEqual(host.dismissals, 0)
    }

    func testWhileASearchIsTypedOnTheGridTheSideArrowsStayInTheText() async throws {
        try await showGrid()
        model.query = "a"
        model.landSearch()

        XCTAssertFalse(model.handleSearchKey(left))
        XCTAssertFalse(model.handleSearchKey(right))
        XCTAssertTrue(model.handleSearchKey(down))
    }

    func testInASheetOfRowsTheArrowsMoveByLinesAndReturnPicksTheRow() async throws {
        try script("fruit", header: "on=sheet.open", "printf 'row=a\\ntitle=Apple\\n\\nrow=b\\ntitle=Banana\\n\\nrow=c\\ntitle=Cherry\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("fruit")
        try await wait("the rows") { self.model.openItems?.shown.count == 3 }

        XCTAssertFalse(model.handleKey(down))
        XCTAssertTrue(model.handleSearchKey(down))
        XCTAssertEqual(model.openItems?.selectedItem?.run, "b")
        XCTAssertTrue(model.handleSearchKey(ActionKey(name: "down", isCommand: true)))
        XCTAssertEqual(model.openItems?.selectedItem?.run, "c")
        XCTAssertTrue(model.handleSearchKey(ActionKey(name: "up", isCommand: true)))
        XCTAssertEqual(model.openItems?.selectedItem?.run, "a")
        XCTAssertFalse(model.handleSearchKey(left))
        XCTAssertFalse(model.handleSearchKey(right))
        XCTAssertFalse(model.handleKey(tab))
        XCTAssertFalse(model.handleKey(history))
        XCTAssertFalse(model.handleKey(settings))
    }

    func testReturnInASheetOfRowsRunsTheSelectedRow() async throws {
        try await openList()

        XCTAssertFalse(model.handleKey(enter))
        XCTAssertTrue(model.handleSearchKey(enter))

        try await wait("the page") { self.titles == ["Detail a"] }
    }

    func testEscPopsAPageOfASheetOfPartsAsItDoesInASheetOfRows() async throws {
        try await openInfo()
        XCTAssertTrue(model.push(FlowSheet(spot: "info", page: "a")))
        try await wait("the page of parts") { self.model.openParts?.parts.first?.title == "Detail" }
        try await wait("the step to settle") { self.model.flowEdges.from == nil }

        XCTAssertTrue(model.handleKey(escape))

        try await wait("the first sheet") { self.model.openParts?.parts.first?.title == "First" }
        XCTAssertNil(model.flow.ahead)
        XCTAssertEqual(model.flow.pages, [FlowSheet(spot: "info")])
        try await wait("the step to settle") { self.model.flowEdges.from == nil }
        XCTAssertTrue(model.handleKey(escape))
        try await wait("the grid") { self.model.openSheetID == nil }
        XCTAssertEqual(host.dismissals, 0)
    }

    func testASheetOfPartsWithNoFocusLeavesReturnTabAndTheSideArrowsAlone() async throws {
        try await openInfo()

        XCTAssertFalse(model.handleKey(enter))
        XCTAssertFalse(model.handleSearchKey(enter))
        XCTAssertFalse(model.handleSearchKey(down))
        XCTAssertFalse(model.handleKey(tab))
        XCTAssertFalse(model.handleKey(left))
        XCTAssertFalse(model.handleKey(settings))
        XCTAssertFalse(model.handleKey(history))
        XCTAssertTrue(model.handleKey(down))
        XCTAssertEqual(model.openSheetID, "info")
    }

    func testTheMenuTakesEachKeyUntilItCloses() async throws {
        try await showGrid()
        try select("weather")
        let chosen = model.selected
        XCTAssertTrue(model.handleKey(actions))
        let menu = try XCTUnwrap(model.menu)

        XCTAssertTrue(model.handleKey(down))
        XCTAssertEqual(model.menu?.selected, 1)
        XCTAssertTrue(model.handleKey(up))
        XCTAssertEqual(model.menu?.selected, 0)
        XCTAssertEqual(model.handleKey(tab), !menu.isSearchable)
        XCTAssertTrue(model.handleKey(settings))
        XCTAssertTrue(model.handleKey(history))
        XCTAssertNotNil(model.menu)
        XCTAssertEqual(model.selected, chosen)
        XCTAssertNil(model.openSheetID)
        XCTAssertTrue(model.handleKey(actions))
        XCTAssertNil(model.menu)

        XCTAssertTrue(model.handleKey(actions))
        XCTAssertTrue(model.handleKey(enter))
        XCTAssertNil(model.menu)
    }

    func testEditSpotsTakesEveryKeyAndEscEndsIt() async throws {
        try await showGrid()
        model.beginEditing()

        XCTAssertTrue(model.handleKey(right))
        XCTAssertEqual(model.selected, 1)
        XCTAssertTrue(model.handleKey(enter))
        XCTAssertTrue(model.handleKey(tab))
        XCTAssertTrue(model.handleKey(actions))
        XCTAssertTrue(model.handleKey(settings))
        XCTAssertTrue(model.handleKey(history))
        XCTAssertNil(model.menu)
        XCTAssertNil(model.openSheetID)
        XCTAssertEqual(host.dismissals, 0)
        XCTAssertTrue(model.isEditing)

        XCTAssertTrue(model.handleKey(ActionKey(name: "right", isShift: true)))
        XCTAssertTrue(model.handleKey(escape))
        XCTAssertFalse(model.isEditing)
    }

    func testEscWhileAKeyIsRecordedStopsTheRecordingAndKeepsTheSheet() async throws {
        try script("draw", header: "title=Draw\non=sheet.open", "printf 'row=float\\ntitle=Float\\ntype=hotkey\\nshortcut=Record\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("draw")
        let sheet = "draw"
        try await wait("its rows") { self.model.openItems?.shown.map(\.run) == ["float"] }
        XCTAssertTrue(model.handleSearchKey(enter))
        XCTAssertEqual(model.recording, "float")
        XCTAssertEqual(model.hint, "Esc Cancel")

        XCTAssertFalse(model.handleKey(ActionKey(name: "s")))
        XCTAssertFalse(model.handleKey(enter))
        XCTAssertEqual(model.recording, "float")
        XCTAssertTrue(model.handleKey(escape))

        XCTAssertNil(model.recording)
        XCTAssertEqual(model.openSheetID, sheet)
    }

    func testCommandYOpensTheHistoryOfASpotWhoseReturnRunsItsCommand() async throws {
        try script("dictate", header: "title=Dictate\non=sheet.open\n\nbutton=dictate\ntitle=Dictate", "printf 'row=a\\ntitle=Said\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.query = "dictate"
        model.landSearch()
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "dictate" })

        XCTAssertTrue(model.handleKey(history))

        try await wait("its rows") { self.model.openSheetID == "dictate" && self.titles == ["Said"] }
    }
}
