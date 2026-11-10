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

    func testThePointerInTheMiddleOfAHandlePointsAtTheCornerAt45Degrees() {
        XCTAssertEqual(SpotTokens.handleAngle(of: .small, at: CGPoint(x: 20, y: 20)), 45)
        XCTAssertEqual(SpotTokens.handleAngle(of: .square, at: CGPoint(x: 20, y: 20)), 45)
    }

    func testThePointerTowardsAnEndOfTheHandleTurnsTheAngleInSteps() {
        XCTAssertEqual(SpotTokens.handleAngle(of: .small, at: CGPoint(x: 26, y: 8)), 20)
        XCTAssertEqual(SpotTokens.handleAngle(of: .small, at: CGPoint(x: 8, y: 26)), 70)
    }

    func testTheAngleStaysWithinTheQuarterOfTheCorner() {
        XCTAssertEqual(SpotTokens.handleAngle(of: .square, at: CGPoint(x: 28, y: 0)), 0)
        XCTAssertEqual(SpotTokens.handleAngle(of: .square, at: CGPoint(x: 0, y: 28)), 90)
    }
}
