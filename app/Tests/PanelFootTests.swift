import XCTest
@testable import OpenspotCore

final class PanelFootTests: XCTestCase {
    private let morph = SheetMorph(card: CGRect(x: 165, y: 165, width: 64, height: 64), sheet: CGRect(x: 90, y: 90, width: 289, height: 430))
    private let below = SpotTokens.halo + SpotTokens.hintBlock

    func testAShrinkingFootReachesTheSheetsFootByTheEndOfTheGridsFade() {
        let foot = PanelFoot(closed: 700, open: 400)
        XCTAssertEqual(foot.path(at: 0), 700)
        XCTAssertEqual(foot.path(at: MotionTokens.cardShare / 2), 550, accuracy: 0.001)
        XCTAssertEqual(foot.path(at: MotionTokens.cardShare), 400)
        XCTAssertEqual(foot.path(at: 0.9), 400)
    }

    func testAGrowingFootHoldsTheGridsFoot() {
        XCTAssertEqual(PanelFoot(closed: 300, open: 500).path(at: 0.7), 300)
    }

    func testTheFootHoldsTheGridWhileItFadesThenRidesOnTheMovingShape() {
        let foot = PanelFoot(closed: 900, open: 520 + below)
        let at = { (progress: Double) in SheetMotion(morph: self.morph, progress: progress).place(of: foot) }

        XCTAssertEqual(at(0), 900, accuracy: 0.001)
        XCTAssertEqual(at(MotionTokens.cardShare), 520 + below, accuracy: 0.001)
        XCTAssertEqual(at(1), 520 + below, accuracy: 0.001)
        XCTAssertEqual(SheetMotion(morph: morph, progress: 0.5).place(of: PanelFoot(closed: 300, open: 520 + below)), 374.5 + below, accuracy: 0.001)
    }

    func testTheMovingShapesFootEndsAtTheFootItIsGiven() {
        XCTAssertEqual(SheetMotion(morph: morph, progress: 1).place(of: PanelFoot(closed: 300, open: 600 + below)), 600 + below, accuracy: 0.001)
    }

    func testWithNoMovingShapeTheFootIsClosedOrOpen() {
        let foot = PanelFoot(closed: 300, open: 600)
        XCTAssertEqual(SheetMotion(morph: nil, progress: 0).place(of: foot), 300)
        XCTAssertEqual(SheetMotion(morph: nil, progress: 1).place(of: foot), 600)
    }

    func testAFootMovedIntoTheGridsSpaceKeepsItsPath() {
        XCTAssertEqual(PanelFoot(closed: 700, open: 400).moved(by: -100), PanelFoot(closed: 600, open: 300))
    }
}
