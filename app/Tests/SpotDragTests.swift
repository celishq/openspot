import XCTest
@testable import OpenspotCore

final class SpotDragTests: XCTestCase {
    /// `a a b b / c c d d`: three wide spots and a small one, which grows to fill its row.
    private let sizes: [SpotSize] = [.wide, .wide, .wide, .small]

    private func centre(of rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.midY)
    }

    func testACardDroppedLeftOfAnotherTakesItsPlaceAndBothShareTheRow() {
        let drag = SpotDrag(id: "d", start: 3, sizes: sizes, places: 0...3)
        let c = SpotGrid().place(sizes)[2].rect
        let leftHalf = CGPoint(x: c.minX + c.width / 4, y: c.midY)

        XCTAssertEqual(drag.nearest(to: leftHalf), .onGrid(2))
        XCTAssertEqual(drag.layout(at: .onGrid(2)), [
            SpotPlacement(index: 0, row: 0, column: 0, size: .wide),
            SpotPlacement(index: 1, row: 0, column: 2, size: .wide),
            SpotPlacement(index: 2, row: 1, column: 0, size: .wide),
            SpotPlacement(index: 3, row: 1, column: 2, size: .wide)
        ])
        XCTAssertEqual(drag.rect(at: .onGrid(2)), c)
    }

    func testACardOverItsOwnPlaceStaysThere() {
        let drag = SpotDrag(id: "d", start: 3, sizes: sizes, places: 0...3)

        XCTAssertEqual(drag.nearest(to: centre(of: drag.rect(at: .onGrid(3)))), .onGrid(3))
        XCTAssertEqual(drag.layout(at: .onGrid(3)), SpotGrid().place(sizes))
    }

    func testACardOverTheFirstCardTakesTheFirstPlace() {
        let drag = SpotDrag(id: "d", start: 3, sizes: sizes, places: 0...3)

        XCTAssertEqual(drag.nearest(to: CGPoint(x: 1, y: 1)), .onGrid(0))
        XCTAssertEqual(drag.rect(at: .onGrid(0)).origin, .zero)
    }

    func testACardLandsOnlyAtThePlacesItMayTake() {
        let drag = SpotDrag(id: "b", start: 1, sizes: sizes, places: 0...1)

        XCTAssertEqual(drag.nearest(to: CGPoint(x: SpotTokens.gridWidth, y: 1000)), .onGrid(1))
    }

    func testASquareDraggedOverTheSmallCardsBesideItLandsOnTheirRight() {
        let sizes: [SpotSize] = [.square] + Array(repeating: .small, count: 8)
        let drag = SpotDrag(id: "a", start: 0, sizes: sizes, places: 0...8)
        let right = CGRect(x: SpotTokens.width(columns: 2) + SpotTokens.columnGap, y: 0, width: SpotTokens.width(columns: 2), height: SpotTokens.height(rows: 2))

        let place = drag.nearest(to: centre(of: right))

        XCTAssertEqual(drag.rect(at: place), right)
    }

    func testTheLiftedCardsCentreFollowsThePointer() {
        let drag = SpotDrag(id: "d", start: 3, sizes: sizes, places: 0...3)
        let start = centre(of: drag.rect(at: .onGrid(3)))

        XCTAssertEqual(drag.centre(movedBy: CGSize(width: -40, height: 12)), CGPoint(x: start.x - 40, y: start.y + 12))
    }

    func testAPointOnTheGridOrJustPastItHoldsTheDropAndAFarOneDoesNot() {
        let drag = SpotDrag(id: "d", start: 3, sizes: sizes, places: 0...3)
        let bottom = SpotTokens.height(rows: 2)

        XCTAssertTrue(drag.holds(CGPoint(x: 10, y: 10)))
        XCTAssertTrue(drag.holds(CGPoint(x: 10, y: bottom + SpotTokens.rowHeight / 4)))
        XCTAssertFalse(drag.holds(CGPoint(x: 10, y: bottom + SpotTokens.rowHeight)))
        XCTAssertFalse(drag.holds(CGPoint(x: -SpotTokens.cell, y: 10)))
    }
}
