import XCTest
@testable import OpenspotCore

final class ActionMenuFrameTests: XCTestCase {
    private let bounds = CGRect(x: 16, y: 166, width: 437, height: 500)
    private let height: CGFloat = 200

    private func card(column: Int, row: Int = 0, columns: Int = 1) -> CGRect {
        SpotPlacement(index: 0, row: row, column: column, size: SpotSize(columns: columns, rows: 1)).rect
            .offsetBy(dx: SpotTokens.halo, dy: SpotTokens.gridTop)
    }

    private func place(_ item: CGRect) -> CGRect {
        ActionMenuFrame(item: item, height: height, bounds: bounds).rect
    }

    func testTheMenuOfACardOnTheLeftOpensToItsRightAtItsTop() {
        let item = card(column: 1)

        let menu = place(item)

        XCTAssertEqual(menu.minX, item.maxX + ActionMenuFrame.gap)
        XCTAssertEqual(menu.minY, item.minY)
    }

    func testTheMenuOfACardOnTheRightOpensToItsLeft() {
        let item = card(column: 2)

        XCTAssertEqual(place(item).maxX, item.minX - ActionMenuFrame.gap)
    }

    func testTheMenuOfAWideCardOpensUnderItOnItsSide() {
        let left = card(column: 0, columns: 2)
        let right = card(column: 2, columns: 2)

        XCTAssertEqual(place(left).minY, left.maxY + ActionMenuFrame.gap)
        XCTAssertEqual(place(left).minX, left.minX)
        XCTAssertEqual(place(right).maxX, right.maxX)
    }

    func testTheMenuOfARowNearTheBottomOpensOverIt() {
        let row = CGRect(x: 103, y: 600, width: 263, height: 40)

        let menu = place(row)

        XCTAssertEqual(menu.maxY, row.minY - ActionMenuFrame.gap)
        XCTAssertEqual(menu.minX, row.minX)
    }

    func testTheMenuStaysInItsBounds() {
        let low = card(column: 0, row: 6)
        let tall = ActionMenuFrame(item: CGRect(x: 103, y: 300, width: 263, height: 40), height: 480, bounds: bounds).rect

        XCTAssertEqual(place(low).maxY, bounds.maxY)
        XCTAssertTrue(bounds.contains(tall))
        XCTAssertTrue(bounds.contains(place(card(column: 3))))
    }

    func testASearchShortensTheMenuFromTheEdgeAwayFromItsItem() {
        let low = ActionMenuFrame(item: CGRect(x: 103, y: 600, width: 263, height: 40), height: height, bounds: bounds)
        let high = ActionMenuFrame(item: card(column: 0), height: height, bounds: bounds)

        XCTAssertEqual(low.stillEdge, .bottom)
        XCTAssertEqual(high.stillEdge, .top)
        XCTAssertEqual(low.rect(height: 80).maxY, low.rect.maxY)
        XCTAssertEqual(high.rect(height: 80).minY, high.rect.minY)
        XCTAssertEqual(high.rect(height: 80).height, 80)
    }

    func testTheMenuGrowsFromItsSideAndEdgeNearestItsItem() {
        let row = CGRect(x: 103, y: 600, width: 263, height: 40)

        let left = ActionMenuFrame(item: card(column: 0), height: height, bounds: bounds)
        XCTAssertEqual(left.side, .left)
        XCTAssertEqual(left.stillEdge, .top)
        let right = ActionMenuFrame(item: card(column: 3), height: height, bounds: bounds)
        XCTAssertEqual(right.side, .right)
        XCTAssertEqual(right.stillEdge, .top)
        let wide = ActionMenuFrame(item: card(column: 2, columns: 2), height: height, bounds: bounds)
        XCTAssertEqual(wide.side, .right)
        XCTAssertEqual(wide.stillEdge, .top)
        let low = ActionMenuFrame(item: row, height: height, bounds: bounds)
        XCTAssertEqual(low.side, .left)
        XCTAssertEqual(low.stillEdge, .bottom)
    }

    func testTheMenuOfACentredItemKeepsToItsLeftEdgeAtAnyScale() {
        for item in [card(column: 0, columns: 4), card(column: 1, columns: 2)] {
            for shift in [-0.000001, 0.000001] {
                let scaled = item.insetBy(dx: -item.width * 0.02, dy: -1).offsetBy(dx: shift, dy: 0)

                XCTAssertEqual(place(scaled).minX, scaled.minX)
                XCTAssertEqual(ActionMenuFrame(item: scaled, height: height, bounds: bounds).side, .left)
            }
            XCTAssertEqual(place(item).minX, item.minX)
        }
    }

    func testTheStillEdgeIsTheEdgeNearerTheItem() {
        let middle = card(column: 0, row: 3)
        let pushedUp = ActionMenuFrame(item: middle, height: 400, bounds: bounds)

        XCTAssertLessThan(pushedUp.rect.minY, middle.minY)
        XCTAssertEqual(pushedUp.stillEdge, .top)
        XCTAssertEqual(ActionMenuFrame(item: card(column: 0, row: 6), height: height, bounds: bounds).stillEdge, .bottom)
    }

    func testTheMenuOfAFullWidthItemOverShortContentLiesUnderIt() {
        let item = card(column: 0, columns: 4)

        let menu = ActionMenuFrame(item: item, height: 116, bounds: ActionMenuFrame.bounds(under: SpotTokens.gridTop)).rect

        XCTAssertEqual(menu.minY, item.maxY + ActionMenuFrame.gap)
        XCTAssertLessThanOrEqual(menu.maxY, SpotTokens.panelHeight - SpotTokens.halo - SpotTokens.hintBlock)
    }

    func testTheRowUnderAPointSkipsTheFieldOnTheStillEdge() throws {
        let actions = ["One", "Two", "Three"].enumerated().map { CommandAction(id: "a\($0.offset)", title: $0.element) }
        let spot = Spot(id: "a", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: .list, primary: "Open", actions: actions)
        let menu = try XCTUnwrap(ActionMenu(spot: spot, item: SpotItem(title: "One", run: "1")))
        let top = ActionMenuFrame(item: card(column: 0), menu: menu, bounds: bounds)
        let bottom = ActionMenuFrame(item: card(column: 0, row: 6), menu: menu, bounds: bounds)

        XCTAssertEqual(top.fieldRect(of: menu)?.minY, top.rect.minY + SpotTokens.menuPadding)
        XCTAssertEqual(top.row(at: CGPoint(x: top.rect.midX, y: top.rowRect(2, of: menu).midY), of: menu), 2)
        XCTAssertEqual(bottom.fieldRect(of: menu)?.maxY, bottom.rect.maxY - SpotTokens.menuPadding)
        XCTAssertEqual(bottom.row(at: CGPoint(x: bottom.rect.midX, y: bottom.rect.minY + SpotTokens.menuPadding + 1), of: menu), 0)
        XCTAssertNil(top.row(at: CGPoint(x: top.rect.midX, y: top.fieldRect(of: menu)!.midY), of: menu))
    }
}
