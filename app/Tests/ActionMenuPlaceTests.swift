import XCTest
@testable import OpenspotCore

final class ActionMenuPlaceTests: XCTestCase {
    private let bounds = CGRect(x: 16, y: 166, width: 437, height: 500)
    private let height: CGFloat = 200

    private func card(column: Int, row: Int = 0, columns: Int = 1) -> CGRect {
        SpotPlacement(index: 0, row: row, column: column, size: SpotSize(columns: columns, rows: 1)).rect
            .offsetBy(dx: SpotTokens.halo, dy: SpotTokens.gridTop)
    }

    private func place(_ item: CGRect) -> CGRect {
        ActionMenuPlace(item: item, height: height, bounds: bounds).rect
    }

    func testTheMenuOfACardOnTheLeftOpensToItsRightAtItsTop() {
        let item = card(column: 1)

        let menu = place(item)

        XCTAssertEqual(menu.minX, item.maxX + ActionMenuPlace.gap)
        XCTAssertEqual(menu.minY, item.minY)
    }

    func testTheMenuOfACardOnTheRightOpensToItsLeft() {
        let item = card(column: 2)

        XCTAssertEqual(place(item).maxX, item.minX - ActionMenuPlace.gap)
    }

    func testTheMenuOfAWideCardOpensUnderItOnItsSide() {
        let left = card(column: 0, columns: 2)
        let right = card(column: 2, columns: 2)

        XCTAssertEqual(place(left).minY, left.maxY + ActionMenuPlace.gap)
        XCTAssertEqual(place(left).minX, left.minX)
        XCTAssertEqual(place(right).maxX, right.maxX)
    }

    func testTheMenuOfARowNearTheBottomOpensOverIt() {
        let row = CGRect(x: 103, y: 600, width: 263, height: 40)

        let menu = place(row)

        XCTAssertEqual(menu.maxY, row.minY - ActionMenuPlace.gap)
        XCTAssertEqual(menu.minX, row.minX)
    }

    func testTheMenuStaysInItsBounds() {
        let low = card(column: 0, row: 6)
        let tall = ActionMenuPlace(item: CGRect(x: 103, y: 300, width: 263, height: 40), height: 480, bounds: bounds).rect

        XCTAssertEqual(place(low).maxY, bounds.maxY)
        XCTAssertTrue(bounds.contains(tall))
        XCTAssertTrue(bounds.contains(place(card(column: 3))))
    }

    func testASearchShortensTheMenuFromTheEdgeAwayFromItsItem() {
        let low = ActionMenuPlace(item: CGRect(x: 103, y: 600, width: 263, height: 40), height: height, bounds: bounds)
        let high = ActionMenuPlace(item: card(column: 0), height: height, bounds: bounds)

        XCTAssertTrue(low.growsUp)
        XCTAssertFalse(high.growsUp)
        XCTAssertEqual(low.rect(height: 80).maxY, low.rect.maxY)
        XCTAssertEqual(high.rect(height: 80).minY, high.rect.minY)
        XCTAssertEqual(high.rect(height: 80).height, 80)
    }

    func testTheMenuGrowsFromItsCornerNearestItsItem() {
        let row = CGRect(x: 103, y: 600, width: 263, height: 40)

        XCTAssertEqual(ActionMenuPlace(item: card(column: 0), height: height, bounds: bounds).corner, CGPoint(x: 0, y: 0))
        XCTAssertEqual(ActionMenuPlace(item: card(column: 3), height: height, bounds: bounds).corner, CGPoint(x: 1, y: 0))
        XCTAssertEqual(ActionMenuPlace(item: card(column: 2, columns: 2), height: height, bounds: bounds).corner, CGPoint(x: 1, y: 0))
        XCTAssertEqual(ActionMenuPlace(item: row, height: height, bounds: bounds).corner, CGPoint(x: 0, y: 1))
    }

    func testTheMenuOfACentredItemKeepsToItsLeftEdgeAtAnyScale() {
        for item in [card(column: 0, columns: 4), card(column: 1, columns: 2)] {
            for shift in [-0.000001, 0.000001] {
                let scaled = item.insetBy(dx: -item.width * 0.02, dy: -1).offsetBy(dx: shift, dy: 0)

                XCTAssertEqual(place(scaled).minX, scaled.minX)
                XCTAssertEqual(ActionMenuPlace(item: scaled, height: height, bounds: bounds).corner.x, 0)
            }
            XCTAssertEqual(place(item).minX, item.minX)
        }
    }

    func testTheStillEdgeIsTheEdgeNearerTheItem() {
        let middle = card(column: 0, row: 3)
        let pushedUp = ActionMenuPlace(item: middle, height: 400, bounds: bounds)

        XCTAssertLessThan(pushedUp.rect.minY, middle.minY)
        XCTAssertFalse(pushedUp.growsUp)
        XCTAssertTrue(ActionMenuPlace(item: card(column: 0, row: 6), height: height, bounds: bounds).growsUp)
    }

    func testTheMenuOfAFullWidthItemOverShortContentLiesUnderIt() {
        let item = card(column: 0, columns: 4)

        let menu = ActionMenuPlace(item: item, height: 116, bounds: ActionMenuPlace.bounds(under: SpotTokens.gridTop)).rect

        XCTAssertEqual(menu.minY, item.maxY + ActionMenuPlace.gap)
        XCTAssertLessThanOrEqual(menu.maxY, SpotTokens.panelHeight - SpotTokens.halo - SpotTokens.hintBlock)
    }
}
