import XCTest
@testable import OpenspotCore

final class SpotResizeTests: XCTestCase {
    private let grid = GridLayout(columns: 4, rows: 7)

    private var start: [SpotPlacement] {
        grid.place([
            GridSpot(size: .wide, cell: GridCell(row: 0, column: 0)),
            GridSpot(size: .wide, cell: GridCell(row: 0, column: 2)),
            GridSpot(size: .wide, cell: GridCell(row: 1, column: 0)),
            GridSpot(size: .small, cell: GridCell(row: 1, column: 2))
        ])
    }

    private func corner(of rect: CGRect) -> CGPoint {
        CGPoint(x: rect.maxX, y: rect.maxY)
    }

    func testACardGrownOverOthersPushesThemToTheNextFreeCells() {
        let resize = SpotResize(id: "c", index: 2, placements: start, choices: SpotSize.all, grid: grid)

        XCTAssertEqual(resize.choices, [.wide, .small, .square, .strip, .large])
        XCTAssertEqual(resize.placement(of: .square), SpotPlacement(index: 2, row: 1, column: 0, size: .square))
        XCTAssertEqual(resize.layout(of: .strip)[3], SpotPlacement(index: 3, row: 2, column: 0, size: .small))
        XCTAssertEqual(resize.layout(of: .large)[3], SpotPlacement(index: 3, row: 3, column: 0, size: .small))
    }

    func testThePointerAtItsOwnCornerKeepsTheSize() {
        let resize = SpotResize(id: "c", index: 2, placements: start, choices: SpotSize.all, grid: grid)

        XCTAssertEqual(resize.size, .wide)
        XCTAssertEqual(resize.nearest(to: resize.corner(movedBy: .zero)), .wide)
    }

    func testThePointerPulledDownARowTakesTheSquare() {
        let resize = SpotResize(id: "c", index: 2, placements: start, choices: SpotSize.all, grid: grid)

        let pointer = resize.corner(movedBy: CGSize(width: 0, height: SpotTokens.cell + SpotTokens.rowGap))

        XCTAssertEqual(pointer, corner(of: resize.placement(of: .square)?.rect ?? .zero))
        XCTAssertEqual(resize.nearest(to: pointer), .square)
    }

    func testASizeThatPushesACardOutOfTheFrameIsNoChoice() {
        let full = grid.place((0..<7).map { GridSpot(size: .strip, cell: GridCell(row: $0, column: 0)) })
        let resize = SpotResize(id: "a", index: 0, placements: full, choices: [.strip, .large], grid: grid)

        XCTAssertEqual(resize.choices, [.strip])
    }

    func testACardThatOffersOneSizeHasNothingToChoose() {
        let resize = SpotResize(id: "c", index: 2, placements: start, choices: [], grid: grid)

        XCTAssertEqual(resize.choices, [.wide])
        XCTAssertEqual(resize.nearest(to: .zero), .wide)
    }
}
