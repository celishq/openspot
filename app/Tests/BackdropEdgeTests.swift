import XCTest
@testable import OpenspotCore

final class BackdropEdgeTests: XCTestCase {
    private let edges = BackdropEdge.blurs
    private let shortest = SpotTokens.contentHeight(gridHeight: 0)

    func testTwoCapsFitInTheShortestBackdropSoTheEdgeIsNeverSqueezed() {
        XCTAssertEqual(shortest, 278)
        for edge in edges {
            XCTAssertLessThanOrEqual(2 * edge.cap.height, shortest)
            XCTAssertLessThanOrEqual(2 * edge.cap.width, SpotTokens.panelWidth)
        }
    }

    func testACapHoldsTheInsetTheCornerAndTheFadeOfTheEdge() {
        for edge in edges {
            XCTAssertGreaterThanOrEqual(edge.cap.height, edge.inset + edge.corner)
            XCTAssertGreaterThanOrEqual(edge.cap.height, edge.inset + SpotTokens.backdropReach * edge.softness)
            XCTAssertGreaterThanOrEqual(edge.cap.width, edge.inset + edge.corner + SpotTokens.backdropReach * edge.softness)
        }
    }

    func testThePiecesCoverTheShortestBackdropWithNoMiddleRow() {
        let rect = CGRect(x: 0, y: 0, width: SpotTokens.panelWidth, height: shortest)
        for edge in edges {
            let pieces = edge.pieces(in: rect)
            XCTAssertEqual(pieces.count, 9)
            XCTAssertEqual(pieces[3].scale.height, 0)
            XCTAssertEqual(pieces[0].frame.maxY, pieces[6].frame.minY)
            XCTAssertEqual(pieces[6].frame.maxY, rect.maxY)
            XCTAssertEqual(pieces[2].frame.maxX, rect.maxX)
        }
    }

    func testThePiecesTileATallWideBackdropAndOnlyTheMiddleOnesAreScaled() {
        let rect = CGRect(x: -300, y: 0, width: 1069, height: 700)
        let edge = BackdropEdge.blurs[0]
        let pieces = edge.pieces(in: rect)

        XCTAssertEqual(pieces[0].frame, CGRect(x: -300, y: 0, width: edge.cap.width, height: edge.cap.height))
        XCTAssertEqual(pieces[4].frame, CGRect(x: -300 + edge.cap.width, y: edge.cap.height, width: 1069 - 2 * edge.cap.width, height: 700 - 2 * edge.cap.height))
        XCTAssertEqual(pieces[8].frame, CGRect(x: rect.maxX - edge.cap.width, y: 700 - edge.cap.height, width: edge.cap.width, height: edge.cap.height))
        XCTAssertEqual(pieces.map(\.frame).reduce(CGRect.null) { $0.union($1) }, rect)
        XCTAssertEqual(pieces.reduce(0) { $0 + $1.frame.width * $1.frame.height }, rect.width * rect.height, accuracy: 0.001)
        for index in [0, 2, 6, 8] { XCTAssertEqual(pieces[index].scale, CGSize(width: 1, height: 1)) }
        XCTAssertEqual(pieces.map(\.source).reduce(CGRect.null) { $0.union($1) }, CGRect(origin: .zero, size: edge.pictureSize))
    }

    func testTheBlurGrowsWeakerInStepsWhoseFadesMeetSoNoLineShows() {
        let blurs = BackdropEdge.blurs
        XCTAssertGreaterThanOrEqual(blurs.count, 3)
        for (outer, inner) in zip(blurs, blurs.dropFirst()) {
            XCTAssertGreaterThan(inner.inset, outer.inset)
            XCTAssertLessThanOrEqual(inner.inset - outer.inset, 2 * min(inner.softness, outer.softness))
        }
    }

    func testTheBlurReachesAsFarPastTheCardsAsBeforeAndBothStayInTheWindow() {
        let reach = { (edge: BackdropEdge) in SpotTokens.halo - edge.inset + SpotTokens.backdropReach * edge.softness }
        XCTAssertGreaterThanOrEqual(reach(BackdropEdge.blurs[0]), 55)
        XCTAssertLessThanOrEqual(reach(BackdropEdge.blurs[0]), SpotTokens.halo)
    }
}
