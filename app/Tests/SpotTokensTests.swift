import XCTest
@testable import OpenspotCore

final class SpotTokensTests: XCTestCase {
    func testAPictureInARoomOneLineHighIsARowIcon() {
        XCTAssertEqual(SpotTokens.pictureSide(in: CGSize(width: 80, height: 26)), SpotTokens.listIconSize)
        XCTAssertEqual(SpotTokens.pictureSide(in: CGSize(width: 80, height: SpotTokens.listRow)), SpotTokens.listIconSize)
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

    func testAFloatingListHoldsALineForEachSectionTitle() {
        let list = ItemList(items: Frame(text: "items=devices\n\nbox=nearby\nparent=devices\ntitle=Nearby\n\nitem=mouse\nparent=nearby\ntitle=Mouse\n\nitem=keyboard\nparent=nearby\ntitle=Keyboard\n").items)

        XCTAssertEqual(SpotTokens.floatSize(list: list), SpotTokens.floatSize(rows: 3, perLine: 1))
    }

    func testAFloatingSheetWithRowsSetApartHoldsTheRuleAsThePanelDoes() {
        let plain = SpotTokens.floatSize(rows: 6, perLine: 1)
        let apart = SpotTokens.floatSize(rows: 6, perLine: 1, setsApart: true)
        let panel = SpotTokens.sheetRect(rows: 6, setsApart: true).height - SpotTokens.sheetRect(rows: 6).height

        XCTAssertEqual(apart.height - plain.height, panel)
        XCTAssertGreaterThan(panel, 0)
    }
}
