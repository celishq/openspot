import XCTest
@testable import OpenspotCore

final class SpotTokensTests: XCTestCase {
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

    func testInFrontOfTheCornersCentreTheArrowLiesOnTheLineToThePointerInStepsOfOneDegree() {
        XCTAssertEqual(SpotTokens.handleAngle(of: .square, at: CGPoint(x: 22, y: 22)), 45)
        XCTAssertEqual(SpotTokens.handleAngle(of: .square, at: CGPoint(x: 22, y: 9)), 19)
        XCTAssertEqual(SpotTokens.handleAngle(of: .square, at: CGPoint(x: 9, y: 22)), 71)
        XCTAssertEqual(SpotTokens.handleAngle(of: .small, at: CGPoint(x: 26, y: 8)), 22)
    }

    func testBehindTheCornersCentreTheArrowLiesOnTheLineFromTheCardsCentreToTheCornersCentre() {
        XCTAssertEqual(SpotTokens.handleAngle(of: .square, at: CGPoint(x: -8, y: -8)), 45)
        XCTAssertEqual(SpotTokens.handleAngle(of: .large, at: CGPoint(x: -28, y: 2)), 20)
        XCTAssertEqual(SpotTokens.handleAngle(of: .wide, at: CGPoint(x: -24, y: 6)), 0)
        XCTAssertEqual(SpotTokens.handleAngle(of: .small, at: CGPoint(x: -30, y: -30)), 45)
    }

    func testInFrontTheArrowStaysBetweenLevelAndUpright() {
        XCTAssertEqual(SpotTokens.handleAngle(of: .square, at: CGPoint(x: 40, y: -10)), 0)
        XCTAssertEqual(SpotTokens.handleAngle(of: .square, at: CGPoint(x: -8, y: 40)), 90)
    }

    func testJustPastTheCornersCentreTheArrowTurnsFromTheCardsLineToThePointersLine() {
        XCTAssertEqual(SpotTokens.handleAngle(of: .wide, at: CGPoint(x: -4, y: 16)), 0)
        XCTAssertEqual(SpotTokens.handleAngle(of: .wide, at: CGPoint(x: 2, y: 16)), 37)
        XCTAssertEqual(SpotTokens.handleAngle(of: .wide, at: CGPoint(x: 8, y: 16)), 59)
    }

    func testAtTheCornersCentreTheArrowHasNoAngle() {
        XCTAssertNil(SpotTokens.handleAngle(of: .square, at: CGPoint(x: 3, y: 3)))
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
