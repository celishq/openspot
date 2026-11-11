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

    func testTheDockLaysItsSpotsAtTheirSizesInRowsAndMovesASmallerSpotUpIntoAGap() {
        let dock = SpotDock(items: [item("Coin", size: .small), item("Disk"), item("Lamp", size: .square), item("Timer", size: .small), item("Wave", size: .large)])
        let cell = SpotTokens.cell, card = SpotTokens.rowHeight, wide = SpotTokens.width(columns: 2)
        let step = cell + SpotTokens.columnGap
        let row = SpotTokens.dockTileHeight + SpotTokens.rowGap

        XCTAssertEqual(dock.rects(columns: 4), [
            CGRect(x: 0, y: 0, width: cell, height: card),
            CGRect(x: step, y: 0, width: wide, height: card),
            CGRect(x: 0, y: row, width: wide, height: SpotTokens.height(rows: 2)),
            CGRect(x: 3 * step, y: 0, width: cell, height: card),
            CGRect(x: 0, y: 3 * row, width: SpotTokens.width(columns: 4), height: SpotTokens.height(rows: 2)),
        ])
        XCTAssertEqual(dock.height(columns: 4), 5 * SpotTokens.dockTileHeight + 4 * SpotTokens.rowGap)
    }

    func testASpotInTheDockTakesThePreferredSizeOverItsOwn() {
        XCTAssertEqual(SpotDock.Item(spot: Spot(id: "lamp", name: "Lamp", url: URL(fileURLWithPath: "/lamp.sh"), size: .small), size: .square).size, .square)
        XCTAssertEqual(item("Lamp", size: .small).size, .small)
    }

    func testTheDockTakesAsManyColumnsAsItsWidthHolds() {
        XCTAssertEqual(SpotTokens.dockColumns(width: 1220), 16)
        XCTAssertEqual(SpotTokens.dockColumns(width: 2 * SpotTokens.padding + SpotTokens.width(columns: 5)), 5)
    }
}
