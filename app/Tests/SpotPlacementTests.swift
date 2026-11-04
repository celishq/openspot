import XCTest
@testable import OpenspotCore

final class SpotPlacementTests: XCTestCase {
    private let open = SpotPlacement(index: 4, row: 2, column: 1, size: .wide)

    private func direction(row: Int, column: Int, size: SpotSize) -> [Int] {
        let away = SpotPlacement(index: 0, row: row, column: column, size: size).direction(awayFrom: open)
        return [away.columns, away.rows]
    }

    func testASpotAboveMovesUp() {
        XCTAssertEqual(direction(row: 0, column: 0, size: .square), [0, -1])
    }

    func testASpotBelowMovesDown() {
        XCTAssertEqual(direction(row: 3, column: 0, size: .strip), [0, 1])
    }

    func testASpotInTheSameRowMovesToItsSide() {
        XCTAssertEqual(direction(row: 2, column: 0, size: .small), [-1, 0])
        XCTAssertEqual(direction(row: 2, column: 3, size: .small), [1, 0])
    }

    func testASpotBesideATallOpenSpotMovesToItsSide() {
        let tall = SpotPlacement(index: 1, row: 0, column: 0, size: .square)
        let away = SpotPlacement(index: 2, row: 1, column: 2, size: .small).direction(awayFrom: tall)
        XCTAssertEqual([away.columns, away.rows], [1, 0])
    }

    func testTheOpenSpotStaysInPlace() {
        let away = open.direction(awayFrom: open)
        XCTAssertEqual([away.columns, away.rows], [0, 0])
    }
}
