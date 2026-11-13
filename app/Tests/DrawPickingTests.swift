import XCTest

/// Proves the picking of boards in the list, as Finder picks files: a click, a Command-click, a Shift-click and the arrows.
final class DrawPickingTests: XCTestCase {
    private let order = ["a", "b", "c", "d", "e"].map { URL(fileURLWithPath: "/boards/\($0).json") }

    private func names(_ picking: Picking) -> [String] {
        picking.picked.map { $0.deletingPathExtension().lastPathComponent }.sorted()
    }

    func testAClickPicksOneAndACommandClickAddsOrDrops() {
        var picking = Picking()
        picking.click(order[0], in: order, mode: .only)
        picking.click(order[2], in: order, mode: .toggle)
        XCTAssertEqual(names(picking), ["a", "c"])

        picking.click(order[0], in: order, mode: .toggle)
        XCTAssertEqual(names(picking), ["c"])
    }

    func testAShiftClickPicksTheRunFromTheAnchor() {
        var picking = Picking()
        picking.click(order[1], in: order, mode: .only)

        picking.click(order[3], in: order, mode: .range)

        XCTAssertEqual(names(picking), ["b", "c", "d"])
    }

    func testAnArrowMovesOneAndShiftArrowsGrowTheRun() {
        var picking = Picking()
        picking.click(order[1], in: order, mode: .only)

        XCTAssertEqual(picking.step(1, in: order, extend: false), order[2])
        XCTAssertEqual(names(picking), ["c"])

        picking.step(1, in: order, extend: true)
        picking.step(1, in: order, extend: true)
        XCTAssertEqual(names(picking), ["c", "d", "e"])

        picking.step(-1, in: order, extend: true)
        XCTAssertEqual(names(picking), ["c", "d"])
    }

    func testAnArrowStopsAtTheEnds() {
        var picking = Picking()
        picking.click(order[4], in: order, mode: .only)

        XCTAssertEqual(picking.step(1, in: order, extend: false), order[4])
        XCTAssertEqual(names(picking), ["e"])
    }

    func testASweepPicksTheRowsItPassesAndWithCommandAddsThem() {
        var picking = Picking()
        picking.click(order[0], in: order, mode: .only)

        picking.sweep(from: order[2], to: order[3], in: order, adding: false)
        XCTAssertEqual(names(picking), ["c", "d"])

        picking.click(order[0], in: order, mode: .only)
        picking.sweep(from: order[4], to: order[3], in: order, adding: true)
        XCTAssertEqual(names(picking), ["a", "d", "e"])
    }

    func testAClickOnEmptySpaceClearsThePick() {
        var picking = Picking()
        picking.click(order[0], in: order, mode: .only)
        picking.click(order[2], in: order, mode: .toggle)

        picking.clear()

        XCTAssertEqual(names(picking), [])
        XCTAssertEqual(picking.step(1, in: order, extend: false), order[0])
    }
}
