import XCTest
@testable import OpenspotCore

final class BackdropFadeTests: XCTestCase {
    private let content = CGRect(x: 90, y: 90, width: 400, height: 300)
    private var area: CGRect { content.insetBy(dx: -SpotTokens.halo, dy: -SpotTokens.halo) }

    func testTheFadeHasNoStrengthAtTheOuterEdgeOfTheHaloAndFullStrengthAtTheContent() {
        let rings = BackdropFade(size: 80, padding: 0, corner: 20, blur: nil).rings(in: area)
        XCTAssertEqual(rings.first?.rect, content.insetBy(dx: -80, dy: -80))
        XCTAssertEqual(rings.first?.strength, 0)
        XCTAssertEqual(rings.last?.rect, content)
        XCTAssertEqual(rings.last?.strength, 1)
    }

    func testTheRingsSpreadEvenlyAcrossTheHalo() {
        let rings = BackdropFade(size: 80, padding: 0, corner: 20, blur: nil).rings(in: area)
        let widths = zip(rings, rings.dropFirst()).map { $1.rect.minX - $0.rect.minX }
        for width in widths { XCTAssertEqual(width, widths[0], accuracy: 0.0001) }
    }

    func testATintGrowsEvenlyAcrossTheHalo() {
        let rings = BackdropFade(size: 80, padding: 0, corner: 20, blur: nil).rings(in: area)
        XCTAssertEqual(rings[rings.count / 2].strength, 0.5, accuracy: 0.0001)
        XCTAssertEqual(rings[rings.count / 4].strength, 0.25, accuracy: 0.0001)
    }

    func testABlurTakesTheDetailOfTextAwayAlongAnEaseInAcrossTheHalo() {
        let rings = BackdropFade(size: 80, padding: 0, corner: 20, blur: 30).rings(in: area)
        let radius = { (ring: BackdropFade.Ring) in pow(ring.strength, SpotTokens.backdropBlurResponse) * 30 }
        let lost = { (ring: BackdropFade.Ring) in 1 - 1 / (1 + pow(radius(ring) / SpotTokens.backdropHalfDetailBlur, SpotTokens.backdropDetailFalloff)) }
        XCTAssertEqual(rings.first?.strength, 0)
        XCTAssertEqual(rings.last?.strength, 1)
        XCTAssertEqual(lost(rings[rings.count / 2]), 0.25, accuracy: 0.001)
        XCTAssertEqual(lost(rings[rings.count / 4]), 0.0625, accuracy: 0.001)
    }

    func testThePaddingHoldsFullStrengthPastTheContent() {
        let rings = BackdropFade(size: 80, padding: 20, corner: 20, blur: nil).rings(in: area)
        XCTAssertEqual(rings.first?.rect, content.insetBy(dx: -80, dy: -80))
        XCTAssertEqual(rings.last?.rect, content.insetBy(dx: -20, dy: -20))
        XCTAssertEqual(rings.last?.strength, 1)
    }

    func testAPaddingTooCloseToTheSizeKeepsTheLeastFade() {
        let rings = BackdropFade(size: 30, padding: 74, corner: 20, blur: nil).rings(in: area)
        XCTAssertEqual(rings.first?.rect, content.insetBy(dx: -30, dy: -30))
        XCTAssertEqual(rings.last?.rect, content.insetBy(dx: -(30 - SpotTokens.backdropLeastFade), dy: -(30 - SpotTokens.backdropLeastFade)))
    }

    func testTheCornerOfEachRingGrowsFasterThanItsDistanceSoTheOuterEdgeIsRound() {
        for ring in BackdropFade(size: 80, padding: 0, corner: 20, blur: nil).rings(in: area) {
            XCTAssertEqual(ring.corner, 20 + SpotTokens.backdropCornerGrowth * (content.minX - ring.rect.minX), accuracy: 0.0001)
        }
        XCTAssertGreaterThan(SpotTokens.backdropCornerGrowth, 1)
    }
}
