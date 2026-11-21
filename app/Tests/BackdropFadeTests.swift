import XCTest
@testable import OpenspotCore

final class BackdropFadeTests: XCTestCase {
    private let content = CGRect(x: 90, y: 90, width: 400, height: 300)

    func testTheFadeHasNoBlurAtTheOuterEdgeOfTheHaloAndFullBlurAtTheContent() {
        let rings = BackdropFade(size: 80, padding: 0).rings(around: content)
        XCTAssertEqual(rings.first?.rect, content.insetBy(dx: -80, dy: -80))
        XCTAssertEqual(rings.first?.strength, 0)
        XCTAssertEqual(rings.last?.rect, content)
        XCTAssertEqual(rings.last?.strength, 1)
    }

    func testTheBlurGrowsEvenlyAcrossTheHalo() {
        let rings = BackdropFade(size: 80, padding: 0).rings(around: content)
        let strengths = zip(rings, rings.dropFirst()).map { $1.strength - $0.strength }
        let widths = zip(rings, rings.dropFirst()).map { $1.rect.minX - $0.rect.minX }
        for step in strengths { XCTAssertEqual(step, strengths[0], accuracy: 0.0001) }
        for width in widths { XCTAssertEqual(width, widths[0], accuracy: 0.0001) }
    }

    func testThePaddingHoldsFullBlurPastTheContent() {
        let rings = BackdropFade(size: 80, padding: 20).rings(around: content)
        XCTAssertEqual(rings.first?.rect, content.insetBy(dx: -80, dy: -80))
        XCTAssertEqual(rings.last?.rect, content.insetBy(dx: -20, dy: -20))
        XCTAssertEqual(rings.last?.strength, 1)
    }

    func testEachRingKeepsTheCornerOfTheContentAtItsDistance() {
        for ring in BackdropFade(size: 80, padding: 0).rings(around: content) {
            XCTAssertEqual(ring.corner, SpotTokens.cardRadius + (content.minX - ring.rect.minX), accuracy: 0.0001)
        }
    }
}
