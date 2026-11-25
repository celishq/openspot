import XCTest
@testable import OpenspotCore

final class SpotSheetCardTests: XCTestCase {
    func testTheFrameOfACardIsItsPlaceUnderTheField() {
        let card = SpotSheetCard(id: "card", placement: SpotPlacement(index: 0, row: 6, column: 1, size: .small), kind: .list, look: nil)
        let place = card.placement.rect

        XCTAssertEqual(card.frame, place.offsetBy(dx: SpotTokens.halo, dy: SpotTokens.gridTop))
    }
}
