import XCTest
@testable import OpenspotCore

final class GridLayoutTests: XCTestCase {
    private let layout = GridLayout(columns: 4, rows: 7)

    func testASpotLiesAtItsCellAndLeavesTheCellsBeforeItEmpty() {
        let placements = layout.place([GridSpot(size: .small, cell: GridCell(row: 2, column: 3))])
        XCTAssertEqual(placements, [SpotPlacement(index: 0, row: 2, column: 3, size: .small)])
    }

    func testASpotWithNoCellTakesTheFirstFreeCellThatFitsIt() {
        let placements = layout.place([
            GridSpot(size: .small, cell: GridCell(row: 0, column: 1)),
            GridSpot(size: .wide, cell: nil)
        ])
        XCTAssertEqual(placements.map { [$0.row, $0.column] }, [[0, 1], [0, 2]])
    }

    func testASpotKeepsItsSizeAndNeverGrowsToFillARow() {
        let placements = layout.place([GridSpot(size: .small, cell: nil), GridSpot(size: .small, cell: nil)])
        XCTAssertEqual(placements.map(\.size), [.small, .small])
    }

    func testASpotWhoseCellIsTakenGoesToTheNextFreeCellInReadingOrder() {
        let placements = layout.place([
            GridSpot(size: .square, cell: GridCell(row: 0, column: 0)),
            GridSpot(size: .small, cell: GridCell(row: 1, column: 1))
        ])
        XCTAssertEqual(placements.map { [$0.row, $0.column] }, [[0, 0], [1, 2]])
    }

    func testASpotThatOverhangsTheFrameMovesInsideIt() {
        let placements = layout.place([GridSpot(size: .wide, cell: GridCell(row: 0, column: 3))])
        XCTAssertEqual(placements.map { [$0.row, $0.column] }, [[1, 0]])
    }

    func testASpotWithNoRoomIsLeftOut() {
        let spots = (0..<8).map { _ in GridSpot(size: .large, cell: nil) }
        XCTAssertEqual(layout.place(spots).map(\.index), [0, 1, 2])
    }

    func testThePlacedSpotGoesFirstAndTheSpotsItCoversGiveWay() {
        let spots = [
            GridSpot(size: .small, cell: GridCell(row: 0, column: 0)),
            GridSpot(size: .small, cell: GridCell(row: 0, column: 1)),
            GridSpot(size: .square, cell: GridCell(row: 0, column: 0))
        ]
        let placements = layout.place(spots, first: 2)
        XCTAssertEqual(placements.map { [$0.index, $0.row, $0.column] }, [[0, 0, 2], [1, 0, 3], [2, 0, 0]])
    }

    func testAStoredCellPastTheFrameTakesAFreeCellAndCrashesNothing() {
        let placements = layout.place([GridSpot(size: .small, cell: GridCell(row: 9, column: 0)), GridSpot(size: .small, cell: GridCell(row: 0, column: 12))])
        XCTAssertEqual(placements.map(\.cell), [GridCell(row: 0, column: 0), GridCell(row: 0, column: 1)])
    }

    func testAWiderFrameHoldsMoreColumns() {
        let placements = GridLayout(columns: 8, rows: 7).place([GridSpot(size: .large, cell: nil), GridSpot(size: .large, cell: nil)])
        XCTAssertEqual(placements.map { [$0.row, $0.column] }, [[0, 0], [0, 4]])
    }

    func testAFreeHoleSmallerThanASpotTakesTheLargestOfItsSizesThatFits() {
        let others = layout.place([GridSpot(size: .wide, cell: GridCell(row: 0, column: 2)), GridSpot(size: .strip, cell: GridCell(row: 1, column: 0))])
        let size = layout.size(of: .square, at: GridCell(row: 0, column: 0), among: others, choices: SpotSize.all)
        XCTAssertEqual(size, .wide)
    }

    func testASpotKeepsItsSizeWhereItFits() {
        let size = layout.size(of: .square, at: GridCell(row: 0, column: 0), among: [], choices: SpotSize.all)
        XCTAssertEqual(size, .square)
    }

    func testASpotOverATakenCellKeepsItsSize() {
        let others = layout.place([GridSpot(size: .small, cell: GridCell(row: 0, column: 0))])
        let size = layout.size(of: .square, at: GridCell(row: 0, column: 0), among: others, choices: SpotSize.all)
        XCTAssertEqual(size, .square)
    }

    func testTheFreeCellsAreEveryCellNoSpotCovers() {
        let placements = layout.place([GridSpot(size: .large, cell: nil)])
        let free = layout.freeCells(around: placements)
        XCTAssertEqual(free.count, 4 * 7 - 8)
        XCTAssertFalse(free.contains(GridCell(row: 1, column: 3)))
        XCTAssertTrue(free.contains(GridCell(row: 2, column: 0)))
    }

    func testTheCellNearestAPointIsClampedSoTheSpotFitsTheFrame() {
        let cell = layout.cell(near: CGPoint(x: 10_000, y: 10_000), for: .wide)
        XCTAssertEqual(cell, GridCell(row: 6, column: 2))
    }

    func testAListTakesAsManyRowsAsItsSpotsNeed() {
        let placements = layout.list(Array(repeating: layout.row, count: 9) + [.small])
        XCTAssertEqual(placements.map(\.row), Array(0..<10))
    }
}
