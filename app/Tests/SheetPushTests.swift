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

    func testOnAWideGridACardBesideTheSheetsColumnsStays() {
        let step = SpotTokens.cell + SpotTokens.columnGap
        let wide = SheetPush(
            open: SpotPlacement(index: 5, row: 1, column: 5, size: .small),
            sheet: CGRect(x: 4 * step, y: -76, width: SpotTokens.gridWidth, height: 400),
            window: CGRect(x: -24, y: -100, width: 700, height: 600)
        )

        XCTAssertEqual(wide.offset(of: card(row: 1, column: 1)), .zero)
        XCTAssertNil(wide.fade(of: card(row: 3, column: 2), movedBy: .zero))
        XCTAssertEqual(wide.offset(of: card(row: 0, column: 5)), CGSize(width: 0, height: -152))
    }

    func testTheOpenCardStaysAndNeverFades() throws {
        let open = try XCTUnwrap(push.open)
        XCTAssertEqual(push.offset(of: open), .zero)
        XCTAssertEqual(push.fade(of: open, movedBy: .zero), 0)
    }

    func testACardHasFadedByTheShareOfItsWayToWhereItsCentreMeetsTheWindowsEdge() {
        XCTAssertEqual(push.fade(of: card(row: 0, column: 1), movedBy: CGSize(width: 0, height: -66)) ?? -1, 0.5, accuracy: 0.001)
        XCTAssertEqual(push.fade(of: card(row: 0, column: 1), movedBy: CGSize(width: 0, height: -140)), 1)
    }

    func testACardThatStaysInTheWindowFadesOverItsWholePush() {
        let wide = SheetPush(open: push.open, sheet: push.sheet, window: CGRect(x: -1000, y: -1000, width: 3000, height: 3000))
        XCTAssertEqual(wide.fade(of: card(row: 0, column: 1), movedBy: CGSize(width: 0, height: -76)) ?? -1, 0.5, accuracy: 0.001)
    }

    func testACardThatThePushLeavesInPlaceHasNoFadeOfItsOwn() {
        let tall = SheetPush(open: push.open, sheet: CGRect(x: 75, y: 0, width: 64, height: 300), window: push.window)
        XCTAssertNil(tall.fade(of: card(row: 1, column: 0), movedBy: .zero))
    }

    func testACardBelowHasFadedWhenItsFootMeetsTheShrinkingBlursFoot() {
        let shrinking = SheetPush(open: push.open, sheet: push.sheet, window: push.window, foot: PanelFoot(closed: 400, open: 250))
        let below = card(row: 2, column: 0)
        let meeting = 184.0 / 484.0

        XCTAssertEqual(shrinking.fade(of: below, movedBy: CGSize(width: 0, height: 92 * meeting)) ?? -1, 0.5, accuracy: 0.001)
        XCTAssertEqual(shrinking.fade(of: below, movedBy: CGSize(width: 0, height: 184 * meeting)) ?? -1, 1, accuracy: 0.001)
    }

    func testABlurThatGrowsLeavesTheWindowToEndTheFade() {
        let growing = SheetPush(open: push.open, sheet: push.sheet, window: push.window, foot: PanelFoot(closed: 250, open: 600))
        XCTAssertEqual(growing.fade(of: card(row: 0, column: 1), movedBy: CGSize(width: 0, height: -66)) ?? -1, 0.5, accuracy: 0.001)
    }

    func testWithNoCardACardThatStaysHasFadedWhenTheShrinkingBlursFootReachesIt() {
        let field = SheetPush(open: nil, sheet: push.sheet, window: push.window, foot: PanelFoot(closed: 400, open: 200))
        let below = card(row: 2, column: 0)

        XCTAssertEqual(field.offset(of: below), .zero)
        XCTAssertEqual(field.fade(of: below, share: 0.23), 0.5, accuracy: 0.001)
        XCTAssertEqual(field.fade(of: below, share: 0.46), 1, accuracy: 0.001)
        XCTAssertEqual(field.fade(of: card(row: 0, column: 0), share: 0.5), 0.5, accuracy: 0.001)
    }
}
