import XCTest
@testable import OpenspotCore

final class SpotSheetCardTests: XCTestCase {
    private func card(row: Int) -> SpotSheetCard {
        SpotSheetCard(id: "card", placement: SpotPlacement(index: 0, row: row, column: 0, size: .small), kind: .list, look: nil)
    }

    func testACardInTheVisibleGridIsSeen() {
        XCTAssertTrue(card(row: 0).isSeen(scrollOffset: 0, gridHeight: SpotTokens.panelHeight))
    }

    func testACardBelowTheVisibleGridIsNotSeenUntilTheGridScrollsToIt() {
        let below = card(row: 9)
        let scroll = SpotTokens.height(rows: 9) + SpotTokens.rowGap

        XCTAssertFalse(below.isSeen(scrollOffset: 0, gridHeight: SpotTokens.panelHeight))
        XCTAssertTrue(below.isSeen(scrollOffset: scroll, gridHeight: SpotTokens.panelHeight))
    }
}
