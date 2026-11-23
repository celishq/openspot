import XCTest
@testable import OpenspotCore

final class BackdropFadeTests: XCTestCase {
    private let content = CGRect(x: 90, y: 90, width: 400, height: 300)
    private var area: CGRect { content.insetBy(dx: -SpotTokens.halo, dy: -SpotTokens.halo) }

    func testTheFadeHasNoStrengthAtTheOuterEdgeOfTheHaloAndFullStrengthAtTheContent() {
        let rings = BackdropFade(size: 80, padding: 0, corner: 20, blur: nil, ease: 2, roundness: 2).rings(in: area)
        XCTAssertEqual(rings.first?.rect, content.insetBy(dx: -80, dy: -80))
        XCTAssertEqual(rings.first?.strength, 0)
        XCTAssertEqual(rings.last?.rect, content)
        XCTAssertEqual(rings.last?.strength, 1)
    }

    func testTheRingsSpreadEvenlyAcrossTheHalo() {
        let rings = BackdropFade(size: 80, padding: 0, corner: 20, blur: nil, ease: 2, roundness: 2).rings(in: area)
        let widths = zip(rings, rings.dropFirst()).map { $1.rect.minX - $0.rect.minX }
        for width in widths { XCTAssertEqual(width, widths[0], accuracy: 0.0001) }
    }

    func testATintGrowsEvenlyAcrossTheHalo() {
        let rings = BackdropFade(size: 80, padding: 0, corner: 20, blur: nil, ease: 2, roundness: 2).rings(in: area)
        XCTAssertEqual(rings[rings.count / 2].strength, 0.5, accuracy: 0.0001)
        XCTAssertEqual(rings[rings.count / 4].strength, 0.25, accuracy: 0.0001)
    }

    func testABlurGrowsByAnEvenRatioFromNothingToItsFullRadius() {
        let rings = BackdropFade(size: 80, padding: 0, corner: 20, blur: 16, ease: 1, roundness: 2).rings(in: area)
        let radii = rings.map { pow($0.strength, SpotTokens.backdropBlurResponse) * 16 + SpotTokens.backdropLeastBlur }
        let ratios = zip(radii, radii.dropFirst()).map { $1 / $0 }
        XCTAssertEqual(rings.first?.strength, 0)
        XCTAssertEqual(rings.last?.strength ?? 0, 1, accuracy: 0.0001)
        for ratio in ratios { XCTAssertEqual(ratio, ratios[0], accuracy: 0.0001) }
    }

    func testALargerEaseKeepsTheBlurSmallFurtherIntoTheHalo() {
        let even = BackdropFade(size: 80, padding: 0, corner: 20, blur: 16, ease: 1, roundness: 2).rings(in: area)
        let eased = BackdropFade(size: 80, padding: 0, corner: 20, blur: 16, ease: 2, roundness: 2).rings(in: area)
        XCTAssertLessThan(eased[even.count / 2].strength, even[even.count / 2].strength / 2)
        XCTAssertEqual(eased.last?.strength ?? 0, 1, accuracy: 0.0001)
    }

    func testThePaddingHoldsFullStrengthPastTheContent() {
        let rings = BackdropFade(size: 80, padding: 20, corner: 20, blur: nil, ease: 2, roundness: 2).rings(in: area)
        XCTAssertEqual(rings.first?.rect, content.insetBy(dx: -80, dy: -80))
        XCTAssertEqual(rings.last?.rect, content.insetBy(dx: -20, dy: -20))
        XCTAssertEqual(rings.last?.strength, 1)
    }

    func testAPaddingTooCloseToTheSizeKeepsTheLeastFade() {
        let rings = BackdropFade(size: 30, padding: 74, corner: 20, blur: nil, ease: 2, roundness: 2).rings(in: area)
        XCTAssertEqual(rings.first?.rect, content.insetBy(dx: -30, dy: -30))
        XCTAssertEqual(rings.last?.rect, content.insetBy(dx: -(30 - SpotTokens.backdropLeastFade), dy: -(30 - SpotTokens.backdropLeastFade)))
    }

    func testTheCornerOfEachRingGrowsByTheRoundnessOfItsDistance() {
        for ring in BackdropFade(size: 80, padding: 0, corner: 20, blur: nil, ease: 2, roundness: 2).rings(in: area) {
            XCTAssertEqual(ring.corner, 20 + 2 * (content.minX - ring.rect.minX), accuracy: 0.0001)
        }
    }
}
