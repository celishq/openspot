import XCTest
@testable import OpenspotCore

final class SpotGridTests: XCTestCase {
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

    func testNoSpotsGivesNoPlacements() {
        XCTAssertEqual(SpotGrid().place([]), [])
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
}
