import XCTest
@testable import OpenspotCore

final class SheetPushTests: XCTestCase {
    private let push = SheetPush(
        open: SpotPlacement(index: 5, row: 1, column: 1, size: .small),
        sheet: CGRect(x: 0, y: -76, width: SpotTokens.gridWidth, height: 400),
        window: CGRect(x: -24, y: -100, width: 300, height: 600)
    )

    private func card(row: Int, column: Int) -> SpotPlacement {
        SpotPlacement(index: 0, row: row, column: column, size: .small)
    }

    func testACardLiesAtItsCellOfTheGrid() {
        XCTAssertEqual(card(row: 1, column: 2).rect, CGRect(x: 150, y: 76, width: 64, height: 64))
    }

    func testACardAboveMovesUpAsFarAsTheSheetsTopEdge() {
        XCTAssertEqual(push.offset(of: card(row: 0, column: 1)), CGSize(width: 0, height: -152))
    }

    func testACardBelowMovesDownAsFarAsTheSheetsFootEdge() {
        XCTAssertEqual(push.offset(of: card(row: 2, column: 0)), CGSize(width: 0, height: 184))
    }

    func testACardBesideMovesToItsSide() {
        XCTAssertEqual(push.offset(of: card(row: 1, column: 0)), CGSize(width: -75, height: 0))
    }

    func testTheOpenCardStaysAndNeverFades() {
        XCTAssertEqual(push.offset(of: push.open), .zero)
        XCTAssertEqual(push.fade(of: push.open), 1...1)
    }

    func testACardFadesFromWhenItsLeadingEdgeMeetsTheWindowsEdgeUntilItsCentreDoes() {
        let fade = push.fade(of: card(row: 0, column: 1))
        XCTAssertEqual(fade.lowerBound, 100.0 / 152, accuracy: 0.001)
        XCTAssertEqual(fade.upperBound, 132.0 / 152, accuracy: 0.001)
    }

    func testACardThatStaysInTheWindowFadesAfterItLeavesTheSheet() {
        let wide = SheetPush(open: push.open, sheet: push.sheet, window: CGRect(x: -1000, y: -1000, width: 3000, height: 3000))
        let fade = wide.fade(of: card(row: 0, column: 1))
        XCTAssertEqual(fade.lowerBound, 106.0 / 152, accuracy: 0.001)
        XCTAssertEqual(fade.upperBound, 1)
    }
}
