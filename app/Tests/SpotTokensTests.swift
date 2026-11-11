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

    func testTheArrowLiesOnTheLineFromTheCardsCentreToThePointerInStepsOfOneDegree() {
        XCTAssertEqual(SpotTokens.handleAngle(of: .square, at: CGPoint(x: 22, y: 22)), 45)
        XCTAssertEqual(SpotTokens.handleAngle(of: .square, at: CGPoint(x: 28, y: 0)), 31)
        XCTAssertEqual(SpotTokens.handleAngle(of: .square, at: CGPoint(x: 0, y: 28)), 59)
        XCTAssertEqual(SpotTokens.handleAngle(of: .wide, at: CGPoint(x: 22, y: 22)), 22)
        XCTAssertEqual(SpotTokens.handleAngle(of: .wide, at: CGPoint(x: 28, y: 0)), 3)
        XCTAssertEqual(SpotTokens.handleAngle(of: .large, at: CGPoint(x: 14, y: 14)), 23)
        XCTAssertEqual(SpotTokens.handleAngle(of: .small, at: CGPoint(x: 26, y: 8)), 22)
    }

    func testAtTheCardsCentreTheArrowHasNoAngle() {
        XCTAssertNil(SpotTokens.handleAngle(of: .small, at: CGPoint(x: -2, y: -2)))
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
