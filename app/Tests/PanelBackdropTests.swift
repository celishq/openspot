import XCTest
@testable import OpenspotCore

@MainActor
final class PanelBackdropTests: PanelCase {
    private let edges = 2 * SpotTokens.halo + SpotTokens.hintBlock

    func testTheBackdropOfAnEmptyGridHoldsTheFieldAndTheHint() async throws {
        await model.reload()

        XCTAssertEqual(model.backdrop, CGRect(x: 0, y: 0, width: SpotTokens.panelWidth, height: edges + SpotTokens.cell))
    }

    func testTheBackdropOfTheGridEndsUnderItsLastCard() async throws {
        try script("list", toml: "title = 'List'", "printf 'item=a\\ntitle=A\\n'")
        await model.reload()

        let cards = SpotGrid.height(of: model.placements)
        XCTAssertGreaterThan(cards, 0)
        XCTAssertEqual(model.backdrop, CGRect(x: 0, y: 0, width: SpotTokens.panelWidth, height: edges + SpotTokens.cell + SpotTokens.rowGap + cards))
    }

    func testTheBackdropOfAnOpenSheetHasTheHeightOfTheSheetAndGoesBackToTheGridWhenItCloses() async throws {
        try await openList()
        let grid = model.gridHeight

        XCTAssertEqual(model.backdrop.height, SpotTokens.sheetRect(rows: 1).height + edges)
        XCTAssertNotEqual(model.backdrop.height, grid)

        XCTAssertTrue(model.handleKey(escape))
        try await wait("the closed sheet") { self.model.transition.id == nil }

        XCTAssertEqual(model.backdrop.height, grid)
    }

    func testTheBackdropOfAnOpenSheetHoldsTheRoomOfAStepUntilTheStepEnds() async throws {
        try await openList()
        let sheet = try XCTUnwrap(model.openSheet?.sheetRect)
        let from = sheet.insetBy(dx: 0, dy: -20)
        model.flowEdges = model.flowEdges.standing(at: from, holding: nil, in: model.flow, title: { _ in "" })
        XCTAssertEqual(model.flowEdges.heldHeight(of: sheet), 40)

        XCTAssertEqual(model.backdrop.height, sheet.height + edges + 40)
    }

    func testTheBackdropUnderTheMenuReachesTheEndOfTheMenu() async throws {
        try script("weather", toml: "title = 'Weather'\non = ['sheet.open']\n[commands.hot]\ntitle = 'Hot'\n[commands.cold]\ntitle = 'Cold'", ":")
        _ = try model.files.config.change { $0.arrangement.set(isOnGrid: true, of: "weather") }
        await model.reload()
        model.isShown = true
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "weather" })
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        let frame = ActionMenuFrame(item: CGRect(x: 16, y: 80, width: 80, height: 80), menu: try XCTUnwrap(model.menu), bounds: ActionMenuFrame.bounds(under: SpotTokens.gridTop))
        model.placeMenu(frame)
        try await wait("the grow") { self.model.menuSession?.phase != .opening }

        XCTAssertGreaterThan(frame.rect.maxY + SpotTokens.halo + SpotTokens.hintBlock, model.gridHeight)
        XCTAssertEqual(model.backdrop.height, frame.rect.maxY + SpotTokens.halo + SpotTokens.hintBlock)

        model.closeMenu()
        try await wait("the closed menu") { self.model.menuSession == nil }

        XCTAssertEqual(model.backdrop.height, model.gridHeight)
    }

    func testATypedKeyThatLeavesTheBackdropAsItIsTellsNoReaderOfIt() async throws {
        try script("list", toml: "title = 'List'", "printf 'item=a\\ntitle=A\\n'")
        await model.reload()
        model.query = "l"
        let rect = model.backdrop
        nonisolated(unsafe) var told = false
        withObservationTracking { _ = model.backdrop } onChange: { told = true }

        model.query = "li"

        XCTAssertEqual(model.backdrop, rect)
        XCTAssertFalse(told)
    }

    func testTheBackdropSpansTheSidePanelsAndASearchNarrowsItToTheMainPanel() async throws {
        try script("list", toml: "title = 'List'", "printf 'item=a\\ntitle=A\\n'")
        await model.reload()
        model.panels = GridPanels(hasLeft: true, hasRight: true)
        let side = SpotTokens.gridWidth + SpotTokens.columnGap

        XCTAssertEqual(model.backdrop.minX, -side)
        XCTAssertEqual(model.backdrop.width, SpotTokens.panelWidth + 2 * side)

        model.query = "zzz"

        XCTAssertEqual(model.backdrop, CGRect(x: 0, y: 0, width: SpotTokens.panelWidth, height: model.gridHeight))
    }
}
