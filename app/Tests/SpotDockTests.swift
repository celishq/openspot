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

    func testTheDockLaysItsSpotsInRowsAndStartsARowForASpotThatDoesNotFit() {
        let dock = SpotDock(items: [item("Coin", size: .small), item("Disk"), item("Timer", size: .small), item("Wave", size: .square)])
        let cell = SpotTokens.cell, card = SpotTokens.rowHeight, wide = SpotTokens.width(columns: 2)
        let step = cell + SpotTokens.columnGap
        let row = SpotTokens.dockTileHeight + SpotTokens.rowGap

        XCTAssertEqual(dock.rects(columns: 4), [
            CGRect(x: 0, y: 0, width: cell, height: card),
            CGRect(x: step, y: 0, width: wide, height: card),
            CGRect(x: 3 * step, y: 0, width: cell, height: card),
            CGRect(x: 0, y: row, width: wide, height: card),
        ])
        XCTAssertEqual(dock.height(columns: 4), 2 * SpotTokens.dockTileHeight + SpotTokens.rowGap)
    }

    func testTheDockTakesAsManyColumnsAsItsWidthHolds() {
        XCTAssertEqual(SpotTokens.dockColumns(width: 1220), 16)
        XCTAssertEqual(SpotTokens.dockColumns(width: 2 * SpotTokens.padding + SpotTokens.width(columns: 5)), 5)
    }
}
