import XCTest
@testable import OpenspotCore

final class SpotDockTests: XCTestCase {
    private func item(_ name: String, state: SpotDock.State = .off, origin: SpotDock.Origin = .core, publication: SpotDock.Publication? = nil) -> SpotDock.Item {
        SpotDock.Item(command: Spot(id: name.lowercased(), name: name, url: URL(fileURLWithPath: "/\(name).sh")), origin: origin, state: state, publication: publication)
    }

    private var dock: SpotDock {
        SpotDock(items: [
            item("Timer", state: .onGrid), item("Disk", state: .searchOnly), item("Coin"), item("Apple", state: .onGrid),
            item("Wave", state: .onGrid, origin: .mine, publication: .changed), item("Note", origin: .mine), item("Bell", state: .searchOnly, origin: .mine, publication: .current)
        ])
    }

    func testAddedShowsTheSpotsOnTheGridThenThoseInSearchEachByName() {
        XCTAssertEqual(dock.shown.map(\.command.name), ["Apple", "Timer", "Wave", "Bell", "Disk"])
        XCTAssertEqual(dock.groups.map(\.title), ["On Grid", "In Search"])
        XCTAssertEqual(dock.groups.map(\.count), [3, 2])
    }

    func testTheStoreShowsEachSpotThatIsNotAdded() {
        var dock = dock
        dock.section = .store

        XCTAssertEqual(dock.shown.map(\.command.name), ["Coin", "Note"])
        XCTAssertEqual(dock.groups.map(\.title), ["Not Added"])
    }

    func testMadeByYouShowsYourSpotsByWhetherTheStoreHasThemAsTheyAre() {
        var dock = dock
        dock.section = .mine

        XCTAssertEqual(dock.shown.map(\.command.name), ["Note", "Wave", "Bell"])
        XCTAssertEqual(dock.groups.map(\.title), ["Not Published", "Published"])
    }

    func testEachSectionCountsItsSpots() {
        XCTAssertEqual(SpotDock.Section.allCases.map { dock.count(of: $0) }, [5, 2, 3])
    }

    func testASearchFindsSpotsOfEverySectionByState() {
        var dock = dock
        dock.query = "e"

        XCTAssertEqual(dock.shown.map(\.command.name), ["Apple", "Timer", "Wave", "Bell", "Note"])
        XCTAssertEqual(dock.groups.map(\.title), ["On Grid", "In Search", "Not Added"])
    }

    func testTheSearchFindsTheWordsUnderASpotsName() {
        var dock = SpotDock(items: [SpotDock.Item(command: Spot(id: "system", name: "System", url: URL(fileURLWithPath: "/system.toml"), subtitle: "Battery, CPU"))])
        dock.query = "cpu"

        XCTAssertEqual(dock.shown.map(\.id), ["system"])
    }

    func testTheNextStepOfASpotClimbsFromNotAddedToTheGridAndPublishesYourChanges() {
        XCTAssertEqual(item("A").step, .add)
        XCTAssertEqual(item("A", state: .searchOnly).step, .addToGrid)
        XCTAssertEqual(item("A", state: .onGrid).step, .open)
        XCTAssertEqual(item("A", state: .searchOnly, origin: .mine).step, .publish)
        XCTAssertEqual(item("A", state: .onGrid, origin: .mine, publication: .changed).step, .publish)
        XCTAssertEqual(item("A", state: .onGrid, origin: .mine, publication: .current).step, .open)
        XCTAssertEqual(item("A", origin: .mine).step, .add)
        XCTAssertEqual(SpotDock.Step.allCases.map(\.title), ["Open", "Add", "Add to Grid", "Publish"])
    }

    func testTheRowsLieTwoToALineOfTheGridsWidthUnderTheirTitlesWithAGapForALineBeforeEachLaterGroup() {
        let rects = dock.rects
        let band = SpotTokens.groupTitleBand, line = SpotTokens.rowHeight + SpotTokens.rowGap, gap = SpotTokens.groupGap
        let width = SpotTokens.gridWidth, step = width + SpotTokens.columnGap

        XCTAssertEqual(rects[0], CGRect(x: 0, y: band, width: width, height: SpotTokens.rowHeight))
        XCTAssertEqual(rects[1].origin, CGPoint(x: step, y: band))
        XCTAssertEqual(rects[2].origin, CGPoint(x: 0, y: band + line))
        XCTAssertEqual(dock.groups[1].top, band + 2 * line + gap)
        XCTAssertEqual(rects[3].origin, CGPoint(x: 0, y: 2 * band + 2 * line + gap))
        XCTAssertEqual(dock.height, 2 * band + 3 * line + gap - SpotTokens.rowGap)
    }

    func testTheStoreIsTwelveColumnsWithTheSidebarAsWideAsTheGrid() {
        XCTAssertEqual(SpotTokens.dockWidth, 2 * SpotTokens.padding + SpotTokens.width(columns: 12))
        XCTAssertEqual(SpotDock.rowsOrigin.x, SpotTokens.padding + SpotTokens.gridWidth + SpotTokens.columnGap)
        XCTAssertEqual(SpotDock.rowsOrigin.x + 2 * SpotTokens.gridWidth + SpotTokens.columnGap + SpotTokens.padding, SpotTokens.dockWidth)
    }

    func testAnOpenedSpotShowsItsSheetUnderItsLineAndPushesTheLaterLinesDown() {
        var dock = SpotDock(items: [item("Apple"), item("Bell"), item("Coin"), item("Disk")])
        dock.section = .store
        let closed = dock.rects
        dock.opened = "apple"
        XCTAssertEqual(dock.rects, closed)
        dock.isSheetOut = true

        let open = dock.rects
        let sheet = SpotTokens.storeSheetHeight + SpotTokens.rowGap
        XCTAssertEqual(open[1], closed[1])
        XCTAssertEqual(open[2], closed[2].offsetBy(dx: 0, dy: sheet))
        XCTAssertEqual(dock.sheetRect, CGRect(x: 0, y: closed[0].maxY + SpotTokens.rowGap, width: SpotTokens.width(columns: 8), height: SpotTokens.storeSheetHeight))
    }

    func testAnOpenedSpotPushesTheTitlesOfTheLaterGroupsDown() {
        var dock = SpotDock(items: [item("Apple", state: .onGrid), item("Bell", state: .searchOnly)])
        let closed = dock.groups
        dock.opened = "apple"
        dock.isSheetOut = true

        XCTAssertEqual(dock.groups[0].top, closed[0].top)
        XCTAssertEqual(dock.groups[1].top, closed[1].top + SpotTokens.storeSheetHeight + SpotTokens.rowGap)
    }

    func testASpotThatTheStoreDoesNotShowOpensNoSheet() {
        var dock = SpotDock(items: [item("Apple"), item("Bell")])
        dock.section = .store
        dock.opened = "apple"
        dock.query = "bell"

        XCTAssertNil(dock.sheetRect)
    }

    func testAPointFindsTheStepTheArrowOrTheRowOfASpot() {
        var dock = SpotDock(items: [item("Apple"), item("Bell")])
        dock.section = .store
        let rect = dock.rects[0]
        let step = SpotDock.stepRect(in: rect), arrow = SpotDock.menuRect(in: rect)

        XCTAssertEqual(dock.part(at: CGPoint(x: step.midX, y: step.midY))?.part, .step)
        XCTAssertEqual(dock.part(at: CGPoint(x: arrow.midX, y: arrow.midY))?.part, .menu)
        XCTAssertEqual(dock.part(at: CGPoint(x: rect.minX + 20, y: rect.midY))?.part, .row)
        XCTAssertEqual(dock.part(at: CGPoint(x: rect.minX + 20, y: rect.midY))?.id, "apple")
        XCTAssertEqual(arrow.maxX, rect.maxX - SpotTokens.padding)
        XCTAssertEqual(step.maxX, arrow.minX)
        XCTAssertNil(dock.part(at: CGPoint(x: -50, y: -50)))
    }

    func testTheMenuOfASpotChecksItsStateAndOffersOnlyTheActionsThatCanRun() {
        let core = SpotDock.menu(for: item("Coin", state: .searchOnly))
        XCTAssertEqual(core.map { $0.map(\.action) }, [[.place(.onGrid), .place(.searchOnly), .place(.off)], [.open], [.copyPrompt]])
        XCTAssertEqual(core[0].map(\.title), ["On Grid", "In Search Only", "Not Added"])
        XCTAssertEqual(core[0].map(\.isChecked), [false, true, false])
        XCTAssertEqual(core[2][0].title, "Copy Prompt to Review")

        let mine = SpotDock.menu(for: item("Wave", origin: .mine, publication: .current))
        XCTAssertEqual(mine.map { $0.map(\.action) }, [[.place(.onGrid), .place(.searchOnly), .place(.off)], [.share, .copyPrompt], [.edit, .moveToTrash]])
        XCTAssertEqual(mine[1][1].title, "Copy Prompt to Change")

        let builtIn = SpotDock.menu(for: SpotDock.Item(command: Spot(id: "settings", name: "Settings", url: URL(fileURLWithPath: "/s")), origin: .builtIn, state: .onGrid))
        XCTAssertEqual(builtIn[0].map(\.action), [.place(.onGrid), .place(.searchOnly)])
        let grid = SpotDock.menu(for: item("Wave", state: .onGrid, origin: .mine))
        XCTAssertEqual(grid.map { $0.map(\.action) }, [[.place(.onGrid), .place(.searchOnly), .place(.off)], [.open], [.publish, .copyPrompt], [.edit]])
    }
}
