import XCTest
@testable import OpenspotCore

final class SpotDockTests: XCTestCase {
    private func item(_ name: String, size: SpotSize = .wide) -> SpotDock.Item {
        SpotDock.Item(command: Spot(id: name.lowercased(), name: name, url: URL(fileURLWithPath: "/\(name).sh"), size: size))
    }

    private var dock: SpotDock {
        SpotDock(items: [item("Timer"), item("Disk"), item("Coin")])
    }

    func testTheDockShowsEachSpotByName() {
        XCTAssertEqual(dock.shown.map(\.command.name), ["Coin", "Disk", "Timer"])
    }

    func testTheSearchKeepsTheSpotsWhoseNameHoldsIt() {
        var dock = dock
        dock.query = "ti"

        XCTAssertEqual(dock.shown.map(\.command.name), ["Timer"])
    }

    func testTheSearchFindsTheWordsUnderASpotsName() {
        var dock = SpotDock(items: [SpotDock.Item(command: Spot(id: "system", name: "System", url: URL(fileURLWithPath: "/system.toml"), subtitle: "Battery, CPU"))])
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
        XCTAssertEqual(SpotDock.Item(command: Spot(id: "lamp", name: "Lamp", url: URL(fileURLWithPath: "/lamp.sh"), size: .small), size: .square).size, .square)
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
}
