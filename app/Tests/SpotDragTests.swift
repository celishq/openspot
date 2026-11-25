import XCTest
@testable import OpenspotCore

final class SpotDragTests: XCTestCase {
    private let grid = GridLayout(columns: 4, rows: 7)
    private let step = SpotTokens.cell + SpotTokens.columnGap

    private func placements(_ spots: [GridSpot]) -> [SpotPlacement] {
        grid.place(spots)
    }

    func testACardMovedOverAFreeCellTakesItAndTheRestStay() throws {
        let start = placements([GridSpot(size: .wide, cell: GridCell(row: 0, column: 0)), GridSpot(size: .wide, cell: GridCell(row: 0, column: 2))])
        let drag = SpotDrag(id: "a", index: 0, placements: start, grid: grid, choices: SpotSize.all)

        let moved = try XCTUnwrap(drag.moved(to: drag.cell(movedBy: CGSize(width: 0, height: 3 * step))))

        XCTAssertEqual(moved.layout, [
            SpotPlacement(index: 0, row: 3, column: 0, size: .wide),
            SpotPlacement(index: 1, row: 0, column: 2, size: .wide)
        ])
    }

    func testACardOverAHoleSmallerThanItTakesTheSizeOfTheHole() throws {
        let start = placements([
            GridSpot(size: .square, cell: GridCell(row: 2, column: 0)),
            GridSpot(size: .wide, cell: GridCell(row: 0, column: 2)),
            GridSpot(size: .strip, cell: GridCell(row: 1, column: 0))
        ])
        let drag = SpotDrag(id: "a", index: 0, placements: start, grid: grid, choices: SpotSize.all)

        let moved = try XCTUnwrap(drag.moved(to: GridCell(row: 0, column: 0)))

        XCTAssertEqual(moved.placement, SpotPlacement(index: 0, row: 0, column: 0, size: .wide))
        XCTAssertEqual(drag.start, .square)
    }

    func testACardOverATakenCellPushesTheCardThere() throws {
        let start = placements([GridSpot(size: .small, cell: GridCell(row: 3, column: 0)), GridSpot(size: .small, cell: GridCell(row: 0, column: 0))])
        let drag = SpotDrag(id: "a", index: 0, placements: start, grid: grid, choices: SpotSize.all)

        let moved = try XCTUnwrap(drag.moved(to: GridCell(row: 0, column: 0)))

        XCTAssertEqual(moved.layout.map(\.cell), [GridCell(row: 0, column: 0), GridCell(row: 0, column: 1)])
    }

    func testACardBackOverItsHomeGivesBackTheLayoutItLeft() throws {
        let start = placements([GridSpot(size: .small, cell: GridCell(row: 0, column: 0)), GridSpot(size: .small, cell: GridCell(row: 0, column: 1))])
        let drag = SpotDrag(id: "a", index: 0, placements: start, grid: grid, choices: SpotSize.all)

        let away = try XCTUnwrap(drag.moved(to: GridCell(row: 0, column: 1)))
        let back = try XCTUnwrap(away.moved(to: drag.home))

        XCTAssertEqual(back.layout, start)
    }

    func testAPointOnTheGridOrJustPastItHoldsTheDropAndAFarOneDoesNot() {
        let start = placements([GridSpot(size: .small, cell: GridCell(row: 6, column: 0))])
        let drag = SpotDrag(id: "a", index: 0, placements: start, grid: grid, choices: SpotSize.all)

        XCTAssertTrue(drag.holds(movedBy: .zero))
        XCTAssertTrue(drag.holds(movedBy: CGSize(width: 0, height: SpotTokens.cell / 4)))
        XCTAssertFalse(drag.holds(movedBy: CGSize(width: 0, height: SpotTokens.cell)))
        XCTAssertFalse(drag.holds(movedBy: CGSize(width: -SpotTokens.cell - 1, height: 0)))
    }
}
