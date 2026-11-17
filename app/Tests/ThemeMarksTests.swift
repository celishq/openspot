import XCTest
@testable import OpenspotCore

final class ThemeMarksTests: XCTestCase {
    private let sizes = SpotSizes(Theme())

    private var grid: ThemeMarks {
        ThemeMarks(sizes: sizes, cards: [
            (SpotPlacement(index: 0, row: 0, column: 0, size: .small), true),
            (SpotPlacement(index: 1, row: 0, column: 1, size: .small), true),
            (SpotPlacement(index: 2, row: 1, column: 0, size: .square), true)
        ])
    }

    private func key(at point: CGPoint, in marks: ThemeMarks) -> String? {
        marks.mark(at: point).map { "[\($0.section)] \($0.key)" }
    }

    func testAPointOnTheGridFindsTheTokenThatShapesIt() {
        XCTAssertEqual(key(at: CGPoint(x: 159, y: 200), in: grid), "[space] column-gap")
        XCTAssertEqual(key(at: CGPoint(x: 120, y: 236), in: grid), "[space] row-gap")
        XCTAssertEqual(key(at: CGPoint(x: 95, y: 200), in: grid), "[space] padding")
        XCTAssertEqual(key(at: CGPoint(x: 152, y: 200), in: grid), "[space] cell")
        XCTAssertEqual(key(at: CGPoint(x: 92, y: 244), in: grid), "[radius] card")
        XCTAssertEqual(key(at: CGPoint(x: 120, y: 200), in: grid), nil)
        XCTAssertEqual(key(at: CGPoint(x: 10, y: 10), in: grid), nil)
    }

    func testARoundCardHasNoCornerMarkAndASmallWidgetNoPadding() {
        let marks = ThemeMarks(sizes: sizes, cards: [(SpotPlacement(index: 0, row: 0, column: 0, size: .small), false)])

        XCTAssertEqual(key(at: CGPoint(x: 92, y: 168), in: marks), nil)
        XCTAssertEqual(key(at: CGPoint(x: 95, y: 200), in: marks), nil)
    }

    func testAScrolledGridMovesItsMarks() {
        let marks = ThemeMarks(sizes: sizes, cards: [(SpotPlacement(index: 0, row: 0, column: 0, size: .small), true)], scroll: 20)

        XCTAssertEqual(key(at: CGPoint(x: 95, y: 180), in: marks), "[space] padding")
    }

    func testAnOpenSheetGivesItsOwnMarksInPlaceOfTheGrid() {
        let marks = ThemeMarks(sizes: sizes, cards: [(SpotPlacement(index: 0, row: 0, column: 0, size: .small), true)], sheet: CGRect(x: 90, y: 90, width: 289, height: 300))

        XCTAssertEqual(key(at: CGPoint(x: 92, y: 92), in: marks), "[radius] card")
        XCTAssertEqual(key(at: CGPoint(x: 95, y: 200), in: marks), "[space] padding")
        XCTAssertEqual(key(at: CGPoint(x: 370, y: 200), in: marks), "[space] padding")
        XCTAssertEqual(key(at: CGPoint(x: 200, y: 200), in: marks), nil)
    }

    func testADragAlongAGapWidensItAndADragAcrossItDoesNot() throws {
        let gap = try XCTUnwrap(grid.mark(at: CGPoint(x: 159, y: 200)))

        XCTAssertEqual(gap.value(after: CGSize(width: 5, height: 40), from: 11, kind: .points), .integer(16))
        XCTAssertEqual(gap.value(after: CGSize(width: 0, height: 40), from: 11, kind: .points), .integer(11))
        XCTAssertEqual(gap.value(after: CGSize(width: 2.4, height: 0), from: 11, kind: .points), .integer(13))
    }

    func testADragKeepsTheValueInsideTheRangeOfItsKind() throws {
        let gap = try XCTUnwrap(grid.mark(at: CGPoint(x: 120, y: 236)))

        XCTAssertEqual(gap.value(after: CGSize(width: 0, height: -50), from: 12, kind: .points), .integer(0))
        XCTAssertEqual(gap.value(after: CGSize(width: 0, height: 500), from: 12, kind: .points), .integer(100))
    }

    func testEachMarkDragsAlongItsOwnAxis() throws {
        let corner = try XCTUnwrap(grid.mark(at: CGPoint(x: 92, y: 244)))
        let left = try XCTUnwrap(grid.mark(at: CGPoint(x: 95, y: 200)))
        let right = try XCTUnwrap(grid.mark(at: CGPoint(x: 145, y: 200)))
        let wide = try XCTUnwrap(grid.mark(at: CGPoint(x: 229, y: 310)))

        XCTAssertEqual(corner.value(after: CGSize(width: 4, height: 4), from: 26, kind: .points), .integer(32))
        XCTAssertEqual(corner.value(after: CGSize(width: 4, height: -4), from: 26, kind: .points), .integer(26))
        XCTAssertEqual(left.value(after: CGSize(width: 3, height: 0), from: 13, kind: .points), .integer(16))
        XCTAssertEqual(right.value(after: CGSize(width: -3, height: 0), from: 13, kind: .points), .integer(16))
        XCTAssertEqual(wide.key, "cell")
        XCTAssertEqual(wide.value(after: CGSize(width: 10, height: 0), from: 64, kind: .points), .integer(69))
    }

    func testTheEdgeOfACardFurtherOutMovesByEachCellBeforeIt() throws {
        let marks = ThemeMarks(sizes: sizes, cards: [(SpotPlacement(index: 0, row: 1, column: 2, size: .small), true)])
        let right = try XCTUnwrap(marks.all.first { $0.key == "cell" && $0.axis.dx == 1 })
        let bottom = try XCTUnwrap(marks.all.first { $0.key == "cell" && $0.axis.dy == 1 })

        XCTAssertEqual(right.value(after: CGSize(width: 9, height: 0), from: 64, kind: .points), .integer(67))
        XCTAssertEqual(bottom.value(after: CGSize(width: 0, height: 4), from: 64, kind: .points), .integer(66))
    }
}
