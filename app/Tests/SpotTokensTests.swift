import XCTest
@testable import OpenspotCore

final class SpotTokensTests: XCTestCase {
    func testASheetOpensOverItsCardsColumnsAndStaysInsideTheGrid() {
        let step = SpotTokens.cell + SpotTokens.columnGap
        XCTAssertEqual(SpotTokens.sheetShift(column: 3, columns: 4), 0)
        XCTAssertEqual(SpotTokens.sheetShift(column: 2, columns: 8), 2 * step)
        XCTAssertEqual(SpotTokens.sheetShift(column: 7, columns: 8), 4 * step)
        XCTAssertEqual(SpotTokens.sheetShift(column: 11, columns: 12), 8 * step)
    }

    func testAPictureInARoomOneLineHighIsARowIcon() {
        XCTAssertEqual(SpotTokens.pictureSide(in: CGSize(width: 80, height: 26)), SpotTokens.listIconSize)
        XCTAssertEqual(SpotTokens.pictureSide(in: CGSize(width: 80, height: SpotTokens.listRowHeight)), SpotTokens.listIconSize)
    }

    func testAPictureInABiggerRoomFillsMostOfIt() {
        XCTAssertEqual(SpotTokens.pictureSide(in: CGSize(width: 100, height: 120)), 60)
    }

    func testAPictureNeverOutgrowsItsRoom() {
        XCTAssertEqual(SpotTokens.pictureSide(in: CGSize(width: 16, height: 30)), 16)
    }

    func testTheArrowsHeadsShowWhetherTheCardCanGrowOrShrink() {
        let sizes: [SpotSize] = [.small, .wide, .square]
        XCTAssertEqual(SpotSize.small.reach(among: sizes).grows, true)
        XCTAssertEqual(SpotSize.small.reach(among: sizes).shrinks, false)
        XCTAssertEqual(SpotSize.wide.reach(among: sizes).grows, true)
        XCTAssertEqual(SpotSize.wide.reach(among: sizes).shrinks, true)
        XCTAssertEqual(SpotSize.square.reach(among: sizes).grows, false)
        XCTAssertEqual(SpotSize.square.reach(among: sizes).shrinks, true)
    }
}
