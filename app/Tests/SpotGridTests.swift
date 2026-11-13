import XCTest
@testable import OpenspotCore

final class SpotGridTests: XCTestCase {
    func testASpotOnASidePanelLiesInThatPanelsShelvesFromTheTop() {
        let grid = SpotGrid(placed: [1: .left, 3: .right], sides: GridSides(hasLeft: true, hasRight: true))
        XCTAssertEqual(grid.place([.strip, .strip, .strip, .strip]), [
            SpotPlacement(index: 0, row: 0, column: 4, size: .strip),
            SpotPlacement(index: 1, row: 0, column: 0, size: .strip),
            SpotPlacement(index: 2, row: 1, column: 4, size: .strip),
            SpotPlacement(index: 3, row: 0, column: 8, size: .strip)
        ])
    }

    func testASpotOfASideThatTheGridDoesNotHaveLiesInTheCenter() {
        let grid = SpotGrid(placed: [0: .left], sides: GridSides(hasRight: true))
        XCTAssertEqual(grid.place([.strip]), [SpotPlacement(index: 0, row: 0, column: 0, size: .strip)])
        XCTAssertEqual(grid.columns, 8)
    }

    func testAMovedSpotTakesItsSideAlong() {
        let grid = SpotGrid(placed: [0: .right], sides: GridSides(hasRight: true)).moving(0, to: 1, split: nil)
        XCTAssertEqual(grid.placed, [1: .right])
        XCTAssertEqual(grid.sides, GridSides(hasRight: true))
    }

    func testTheHiddenGroupLiesInTheCenterUnderEveryPanel() {
        let grid = SpotGrid(split: 2, placed: [0: .left], sides: GridSides(hasLeft: true))
        XCTAssertEqual(grid.place([.large, .strip, .strip]).map { [$0.row, $0.column] }, [[0, 0], [0, 4], [2, 4]])
    }

    func testTwoSmallSpotsThenAWideOneShareARow() {
        let placements = SpotGrid().place([.small, .small, .wide])
        XCTAssertEqual(placements, [
            SpotPlacement(index: 0, row: 0, column: 0, size: .small),
            SpotPlacement(index: 1, row: 0, column: 1, size: .small),
            SpotPlacement(index: 2, row: 0, column: 2, size: .wide)
        ])
    }

    func testAStripMovesDownWhenTheRowHasASmallSpot() {
        let placements = SpotGrid().place([.small, .strip])
        XCTAssertEqual(placements[1], SpotPlacement(index: 1, row: 1, column: 0, size: .strip))
    }

    func testASquareTakesTwoRowsAndTheSmallSpotsFillTheRest() {
        let placements = SpotGrid().place([.square, .small, .small, .small, .small])
        XCTAssertEqual(placements, [
            SpotPlacement(index: 0, row: 0, column: 0, size: .square),
            SpotPlacement(index: 1, row: 0, column: 2, size: .small),
            SpotPlacement(index: 2, row: 0, column: 3, size: .small),
            SpotPlacement(index: 3, row: 1, column: 2, size: .small),
            SpotPlacement(index: 4, row: 1, column: 3, size: .small)
        ])
    }

    func testALargeSpotKeepsItsWholeShelf() {
        XCTAssertEqual(SpotGrid().place([.small, .large, .small]), [
            SpotPlacement(index: 0, row: 0, column: 0, size: .wide),
            SpotPlacement(index: 1, row: 1, column: 0, size: .large),
            SpotPlacement(index: 2, row: 0, column: 2, size: .wide)
        ])
    }

    func testALargeSpotAloneKeepsItsSize() {
        XCTAssertEqual(sizes([.large]), [.large])
    }

    func testAStripAfterASquareKeepsItsSize() {
        let placements = SpotGrid().place([.square, .strip])
        XCTAssertEqual(placements.map(\.size), [.strip, .strip])
        XCTAssertEqual(placements.map(\.row), [0, 1])
    }

    func testFourSmallSpotsKeepTheirSize() {
        XCTAssertEqual(SpotGrid().place([.small, .small, .small, .small]).map(\.size), [.small, .small, .small, .small])
    }

    private func move(from index: Int, in sizes: [SpotSize], dx: Int = 0, dy: Int = 0) -> Int? {
        let grid = SpotGrid()
        return grid.neighbour(of: index, in: grid.place(sizes), dx: dx, dy: dy)
    }

    func testDownFromAStripLandsOnTheSquaresBelowItAndNotTheStripAfterThem() {
        XCTAssertEqual(move(from: 0, in: [.strip, .square, .square, .strip], dy: 1), 1)
    }

    func testDownFromASquareLandsOnTheStripBelow() {
        XCTAssertEqual(move(from: 2, in: [.strip, .square, .square, .strip], dy: 1), 3)
    }

    func testUpFromAStripLandsOnTheSquaresAboveIt() {
        XCTAssertEqual(move(from: 3, in: [.strip, .square, .square, .strip], dy: -1), 1)
    }

    func testDownKeepsTheNearestColumn() {
        XCTAssertEqual(move(from: 1, in: [.wide, .wide, .wide, .wide], dy: 1), 3)
    }

    func testSidewaysStaysInTheSameRow() {
        XCTAssertEqual(move(from: 0, in: [.wide, .wide, .strip], dx: 1), 1)
        XCTAssertNil(move(from: 1, in: [.wide, .wide, .strip], dx: 1))
    }

    func testRightFromASquareLandsOnTheTopSpotBesideIt() {
        XCTAssertEqual(move(from: 0, in: [.square, .wide, .wide], dx: 1), 1)
    }

    func testAMoveWithNothingThereGivesNothing() {
        XCTAssertNil(move(from: 0, in: [.strip], dy: 1))
    }

    private func sizes(_ input: [SpotSize]) -> [SpotSize] {
        SpotGrid().place(input).map(\.size)
    }

    func testASpotAloneTakesTheWholeRow() {
        XCTAssertEqual(sizes([.small]), [.strip])
        XCTAssertEqual(sizes([.wide]), [.strip])
        XCTAssertEqual(sizes([.square]), [.strip])
    }

    func testTwoSpotsShareARowEqually() {
        XCTAssertEqual(sizes([.small, .small]), [.wide, .wide])
        XCTAssertEqual(sizes([.wide, .small]), [.wide, .wide])
    }

    func testThreeSmallSpotsGrowTheFirst() {
        XCTAssertEqual(sizes([.small, .small, .small]), [.wide, .small, .small])
    }

    func testASpotBesideASquareFillsItsSide() {
        XCTAssertEqual(SpotGrid().place([.square, .small]), [
            SpotPlacement(index: 0, row: 0, column: 0, size: .square),
            SpotPlacement(index: 1, row: 0, column: 2, size: .square)
        ])
    }

    func testTwoSpotsBesideASquareStack() {
        XCTAssertEqual(SpotGrid().place([.square, .small, .small]), [
            SpotPlacement(index: 0, row: 0, column: 0, size: .square),
            SpotPlacement(index: 1, row: 0, column: 2, size: .wide),
            SpotPlacement(index: 2, row: 1, column: 2, size: .wide)
        ])
    }

    func testASmallSpotMovesUpToFillARow() {
        XCTAssertEqual(SpotGrid().place([.small, .small, .small, .wide, .small]), [
            SpotPlacement(index: 0, row: 0, column: 0, size: .small),
            SpotPlacement(index: 1, row: 0, column: 1, size: .small),
            SpotPlacement(index: 2, row: 0, column: 2, size: .small),
            SpotPlacement(index: 3, row: 1, column: 0, size: .strip),
            SpotPlacement(index: 4, row: 0, column: 3, size: .small)
        ])
    }

    func testASquareAfterASmallSpotLiesOnTheRightOfTheSmallSpots() {
        XCTAssertEqual(SpotGrid().place([.small, .square, .small, .small, .small]), [
            SpotPlacement(index: 0, row: 0, column: 0, size: .small),
            SpotPlacement(index: 1, row: 0, column: 2, size: .square),
            SpotPlacement(index: 2, row: 0, column: 1, size: .small),
            SpotPlacement(index: 3, row: 1, column: 0, size: .small),
            SpotPlacement(index: 4, row: 1, column: 1, size: .small)
        ])
    }

    func testAWideSpotBeforeASquareGrowsToASquareOnItsLeft() {
        XCTAssertEqual(SpotGrid().place([.wide, .square]), [
            SpotPlacement(index: 0, row: 0, column: 0, size: .square),
            SpotPlacement(index: 1, row: 0, column: 2, size: .square)
        ])
    }

    func testSpotsWiderThanHalfARowBeforeASquareFillARowOfTheirOwn() {
        XCTAssertEqual(SpotGrid().place([.wide, .small, .square]).map(\.row), [0, 0, 1])
    }

    func testAFullSetKeepsItsSizes() {
        let input: [SpotSize] = [.square, .wide, .small, .small, .wide, .small, .small, .strip, .strip, .strip]
        XCTAssertEqual(sizes(input), input)
    }

    func testEveryCombinationFillsEveryRowWithoutOverlap() {
        let all: [SpotSize] = [.small, .wide, .square, .strip, .large]
        var combinations: [[SpotSize]] = [[]]
        for _ in 0..<6 {
            combinations += combinations.filter { $0.count == combinations.last!.count }.flatMap { base in all.map { base + [$0] } }
        }
        for input in combinations {
            let placements = SpotGrid().place(input)
            XCTAssertEqual(placements.map(\.index), Array(input.indices), "\(input)")
            var cells = Set<[Int]>()
            for spot in placements {
                XCTAssertTrue(all.contains(spot.size), "\(input)")
                for row in spot.row..<(spot.row + spot.size.rows) {
                    for column in spot.column..<(spot.column + spot.size.columns) {
                        XCTAssertTrue(cells.insert([row, column]).inserted, "overlap in \(input)")
                    }
                }
            }
            let rows = (placements.map { $0.row + $0.size.rows }.max() ?? 0)
            XCTAssertEqual(cells.count, rows * 4, "hole in \(input)")
        }
    }

    func testTwoGroupsLieEachUnderItsTitleBand() {
        let placements = SpotGrid(split: 2).place([.small, .small, .small, .small, .small])
        let band = SpotTokens.groupTitleBand
        XCTAssertEqual(placements.map(\.index), [0, 1, 2, 3, 4])
        XCTAssertEqual(placements[0].rect.minY, band)
        XCTAssertEqual(placements[2].row, 1)
        XCTAssertEqual(placements[2].column, 0)
        XCTAssertEqual(placements[2].rect.minY, placements[0].rect.maxY + SpotTokens.rowGap + band)
        XCTAssertEqual(SpotGrid.height(of: placements), placements[4].rect.maxY)
    }

    func testOneGroupHasNoTitleBand() {
        let sizes: [SpotSize] = [.small, .wide, .small]
        XCTAssertEqual(SpotGrid(split: 3).place(sizes), SpotGrid().place(sizes))
        XCTAssertEqual(SpotGrid(split: 0).place(sizes), SpotGrid().place(sizes))
        XCTAssertEqual(SpotGrid(split: nil).place(sizes), SpotGrid().place(sizes))
    }

    func testAnEmptyGridHasNoHeight() {
        XCTAssertEqual(SpotGrid.height(of: []), 0)
    }

    func testAKeptSpotNeverGrowsToFillItsRow() {
        XCTAssertEqual(SpotGrid(kept: [0]).place([.small]).map(\.size), [.small])
        XCTAssertEqual(SpotGrid(kept: [0]).place([.square]).map(\.size), [.square])
        XCTAssertEqual(SpotGrid(kept: [0]).place([.small, .small]).map(\.size), [.small, .wide])
        XCTAssertEqual(SpotGrid(kept: [0]).place([.small, .small, .small]).map(\.size), [.small, .wide, .small])
    }

    func testAKeptSpotKeepsItsSizeInEachGroup() {
        let placements = SpotGrid(split: 2, kept: [2]).place([.small, .wide, .small])
        XCTAssertEqual(placements.map(\.size), [.wide, .wide, .small])
    }
}
