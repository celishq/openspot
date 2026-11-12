import XCTest
@testable import OpenspotCore

final class SpotDockTests: XCTestCase {
    private func item(_ name: String, size: SpotSize = .wide) -> SpotDock.Item {
        SpotDock.Item(spot: Spot(id: name.lowercased(), name: name, url: URL(fileURLWithPath: "/\(name).sh"), size: size))
    }

    private var dock: SpotDock {
        SpotDock(items: [item("Timer"), item("Disk"), item("Coin")])
    }

    func testTheDockShowsEachSpotByName() {
        XCTAssertEqual(dock.shown.map(\.spot.name), ["Coin", "Disk", "Timer"])
    }

    func testTheSearchKeepsTheSpotsWhoseNameHoldsIt() {
        var dock = dock
        dock.query = "ti"

        XCTAssertEqual(dock.shown.map(\.spot.name), ["Timer"])
    }

    func testTheSearchFindsTheWordsUnderASpotsName() {
        var dock = SpotDock(items: [SpotDock.Item(spot: Spot(id: "system", name: "System", url: URL(fileURLWithPath: "/system.toml"), subtitle: "Battery, CPU"))])
        dock.query = "cpu"

        XCTAssertEqual(dock.shown.map(\.id), ["system"])
    }

    func testTheDockPacksItsSpotsInShelvesAtTheirSizesWithTheGridsGaps() {
        let dock = SpotDock(items: [item("Coin", size: .small), item("Disk"), item("Lamp", size: .square), item("Timer", size: .small), item("Wave", size: .large)])
        let cell = SpotTokens.cell, card = SpotTokens.rowHeight, wide = SpotTokens.width(columns: 2)
        let step = cell + SpotTokens.columnGap
        let row = SpotTokens.rowHeight + SpotTokens.rowGap

        XCTAssertEqual(dock.rects(columns: 4), [
            CGRect(x: 0, y: 0, width: cell, height: card),
            CGRect(x: step, y: 0, width: wide, height: card),
            CGRect(x: 0, y: row, width: wide, height: SpotTokens.height(rows: 2)),
            CGRect(x: 3 * step, y: 0, width: cell, height: card),
            CGRect(x: 0, y: 3 * row, width: SpotTokens.width(columns: 4), height: SpotTokens.height(rows: 2)),
        ])
        XCTAssertEqual(dock.height(columns: 4), SpotTokens.height(rows: 5))
    }

    func testASpotMovesUpOnlyIntoTheShelfThatIsFilled() {
        let dock = SpotDock(items: [item("Apple"), item("Bell", size: .square), item("Coin", size: .small), item("Disk", size: .small), item("Echo", size: .small)])
        let step = SpotTokens.cell + SpotTokens.columnGap
        let row = SpotTokens.rowHeight + SpotTokens.rowGap

        let origins = dock.rects(columns: 4).map(\.origin)

        XCTAssertEqual(origins, [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 0, y: row),
            CGPoint(x: 2 * step, y: 0),
            CGPoint(x: 3 * step, y: 0),
            CGPoint(x: 2 * step, y: row)
        ])
    }

    func testASpotInTheDockTakesThePreferredSizeOverItsOwn() {
        XCTAssertEqual(SpotDock.Item(spot: Spot(id: "lamp", name: "Lamp", url: URL(fileURLWithPath: "/lamp.sh"), size: .small), size: .square).size, .square)
        XCTAssertEqual(item("Lamp", size: .small).size, .small)
    }

    func testTheDockTakesAsManyColumnsAsItsWidthHolds() {
        XCTAssertEqual(SpotTokens.dockColumns(width: 1220), 16)
        XCTAssertEqual(SpotTokens.dockColumns(width: 2 * SpotTokens.padding + SpotTokens.width(columns: 5)), 5)
    }

    func testAnOpenedSpotShowsItsSheetUnderItsShelfAndPushesTheLaterShelvesDown() {
        var dock = SpotDock(items: [item("Apple"), item("Bell"), item("Coin"), item("Disk")])
        let closed = dock.rects(columns: 4)
        dock.opened = "apple"

        let open = dock.rects(columns: 4)
        let sheet = SpotTokens.storeSheetHeight + SpotTokens.rowGap
        XCTAssertEqual(open[0], closed[0])
        XCTAssertEqual(open[1], closed[1])
        XCTAssertEqual(open[2], closed[2].offsetBy(dx: 0, dy: sheet))
        XCTAssertEqual(open[3], closed[3].offsetBy(dx: 0, dy: sheet))
        XCTAssertEqual(dock.sheetRect(columns: 4), CGRect(x: 0, y: closed[0].maxY + SpotTokens.rowGap, width: SpotTokens.width(columns: 4), height: SpotTokens.storeSheetHeight))
        XCTAssertEqual(dock.height(columns: 4), SpotTokens.height(rows: 2) + sheet)
    }

    func testASpotThatTheStoreDoesNotShowOpensNoSheet() {
        var dock = SpotDock(items: [item("Apple"), item("Bell")])
        dock.opened = "apple"
        dock.query = "bell"

        XCTAssertNil(dock.sheetRect(columns: 4))
        XCTAssertEqual(dock.rects(columns: 4).first?.minY, 0)
    }

    func testAPointFindsTheCrossOrTheCardOfASpot() {
        let dock = SpotDock(items: [SpotDock.Item(spot: Spot(id: "apple", name: "Apple", url: URL(fileURLWithPath: "/apple.sh")), origin: .mine), item("Bell")])
        let rect = dock.rects(columns: 4)[0]
        let rim = SpotTokens.corner(for: .wide) * SpotTokens.rimPoint

        XCTAssertEqual(dock.part(at: CGPoint(x: rect.maxX - rim, y: rect.minY + rim), columns: 4)?.part, .delete)
        XCTAssertEqual(dock.part(at: CGPoint(x: rect.maxX - 20, y: rect.midY), columns: 4)?.id, "apple")
        XCTAssertEqual(dock.part(at: CGPoint(x: rect.maxX - 20, y: rect.midY), columns: 4)?.part, .card)
        let bell = dock.rects(columns: 4)[1]
        XCTAssertEqual(dock.part(at: CGPoint(x: bell.maxX - rim, y: bell.minY + rim), columns: 4)?.part, .card)
        XCTAssertNil(dock.part(at: CGPoint(x: -50, y: -50), columns: 4))
    }

    private func item(_ name: String, state: SpotDock.State, size: SpotSize = .wide) -> SpotDock.Item {
        SpotDock.Item(spot: Spot(id: name.lowercased(), name: name, url: URL(fileURLWithPath: "/\(name).sh"), size: size), state: state)
    }

    func testTheStoreShowsItsSpotsByStateEachGroupUnderItsTitle() {
        let dock = SpotDock(items: [item("Bell", state: .off), item("Apple", state: .onGrid), item("Coin", state: .searchOnly), item("Disk", state: .onGrid)])
        let band = SpotTokens.groupTitleBand

        XCTAssertEqual(dock.shown.map(\.id), ["bell", "coin", "apple", "disk"])
        XCTAssertEqual(dock.groups(columns: 4).map(\.state), [.off, .searchOnly, .onGrid])
        XCTAssertEqual(dock.groups(columns: 4).map(\.count), [1, 1, 2])
        let rects = dock.rects(columns: 4)
        XCTAssertEqual(rects[0].minY, band)
        XCTAssertEqual(dock.groups(columns: 4)[1].top, rects[0].maxY + SpotTokens.rowGap)
        XCTAssertEqual(rects[1].minY, rects[0].maxY + SpotTokens.rowGap + band)
    }

    func testAStoreOfOneStateHasNoTitles() {
        let dock = SpotDock(items: [item("Apple", state: .off), item("Bell", state: .off)])

        XCTAssertEqual(dock.groups(columns: 4).count, 0)
        XCTAssertEqual(dock.rects(columns: 4).first?.minY, 0)
    }

    func testTheAddPillOfASpotThatIsNotOnTheGridTakesAClick() {
        let dock = SpotDock(items: [item("Apple", state: .off), item("Bell", state: .onGrid), item("Coin", state: .off, size: .small)])
        let rects = dock.rects(columns: 4)
        let apple = dock.shown.firstIndex { $0.id == "apple" }!, bell = dock.shown.firstIndex { $0.id == "bell" }!, coin = dock.shown.firstIndex { $0.id == "coin" }!
        let pill = SpotDock.addRect(in: rects[apple], size: .wide)
        let rim = SpotTokens.corner(for: .small) * SpotTokens.rimPoint

        XCTAssertEqual(dock.part(at: CGPoint(x: pill.midX, y: pill.midY), columns: 4)?.part, .add)
        XCTAssertEqual(dock.part(at: CGPoint(x: rects[bell].maxX - 20, y: rects[bell].midY), columns: 4)?.part, .card)
        XCTAssertEqual(dock.part(at: CGPoint(x: rects[coin].minX + rim, y: rects[coin].minY + rim), columns: 4)?.part, .add)
    }
}
