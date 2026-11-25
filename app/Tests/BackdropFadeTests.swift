import XCTest
@testable import OpenspotCore

final class BackdropFadeTests: XCTestCase {
    private let content = CGRect(x: 90, y: 90, width: 400, height: 300)
    private var area: CGRect { content.insetBy(dx: -SpotTokens.halo, dy: -SpotTokens.halo) }

    func testTheFadeHasNoStrengthAtTheOuterEdgeOfTheHaloAndFullStrengthAtTheContent() {
        let rings = BackdropFade(size: 80, padding: 0, corner: 20, blur: nil, ease: 2, roundness: 2, inset: 40).rings(in: area)
        XCTAssertEqual(rings.first?.rect, content.insetBy(dx: -80, dy: -80))
        XCTAssertEqual(rings.first?.strength, 0)
        XCTAssertEqual(rings.last?.rect, content)
        XCTAssertEqual(rings.last?.strength, 1)
    }

    func testTheRingsSpreadEvenlyAcrossTheHalo() {
        let rings = BackdropFade(size: 80, padding: 0, corner: 20, blur: nil, ease: 2, roundness: 2, inset: 40).rings(in: area)
        let widths = zip(rings, rings.dropFirst()).map { $1.rect.minX - $0.rect.minX }
        for width in widths { XCTAssertEqual(width, widths[0], accuracy: 0.0001) }
    }

    func testATintGrowsEvenlyAcrossTheHalo() {
        let rings = BackdropFade(size: 80, padding: 0, corner: 20, blur: nil, ease: 2, roundness: 2, inset: 40).rings(in: area)
        XCTAssertEqual(rings[rings.count / 2].strength, 0.5, accuracy: 0.0001)
        XCTAssertEqual(rings[rings.count / 4].strength, 0.25, accuracy: 0.0001)
    }

    func testABlurGrowsByAnEvenRatioFromNothingToItsFullRadius() {
        let rings = BackdropFade(size: 80, padding: 0, corner: 20, blur: 16, ease: 1, roundness: 2, inset: 40).rings(in: area)
        let radii = rings.map { pow($0.strength, SpotTokens.backdropBlurResponse) * 16 + SpotTokens.backdropLeastBlur }
        let ratios = zip(radii, radii.dropFirst()).map { $1 / $0 }
        XCTAssertEqual(rings.first?.strength, 0)
        XCTAssertEqual(rings.last?.strength ?? 0, 1, accuracy: 0.0001)
        for ratio in ratios { XCTAssertEqual(ratio, ratios[0], accuracy: 0.0001) }
    }

    func testALargerEaseKeepsTheBlurSmallFurtherIntoTheHalo() {
        let even = BackdropFade(size: 80, padding: 0, corner: 20, blur: 16, ease: 1, roundness: 2, inset: 40).rings(in: area)
        let eased = BackdropFade(size: 80, padding: 0, corner: 20, blur: 16, ease: 2, roundness: 2, inset: 40).rings(in: area)
        XCTAssertLessThan(eased[even.count / 2].strength, even[even.count / 2].strength / 2)
        XCTAssertEqual(eased.last?.strength ?? 0, 1, accuracy: 0.0001)
    }

    func testThePaddingHoldsFullStrengthPastTheContent() {
        let rings = BackdropFade(size: 80, padding: 20, corner: 20, blur: nil, ease: 2, roundness: 2, inset: 40).rings(in: area)
        XCTAssertEqual(rings.first?.rect, content.insetBy(dx: -80, dy: -80))
        XCTAssertEqual(rings.last?.rect, content.insetBy(dx: -20, dy: -20))
        XCTAssertEqual(rings.last?.strength, 1)
    }

    func testAPaddingTooCloseToTheSizeKeepsTheLeastFade() {
        let rings = BackdropFade(size: 30, padding: 74, corner: 20, blur: nil, ease: 2, roundness: 2, inset: 40).rings(in: area)
        XCTAssertEqual(rings.first?.rect, content.insetBy(dx: -30, dy: -30))
        XCTAssertEqual(rings.last?.rect, content.insetBy(dx: -(30 - SpotTokens.backdropLeastFade), dy: -(30 - SpotTokens.backdropLeastFade)))
    }

    func testTheCornerOfEachRingGrowsByTheRoundnessOfItsDistance() {
        for ring in BackdropFade(size: 80, padding: 0, corner: 20, blur: nil, ease: 2, roundness: 2, inset: 40).rings(in: area) {
            XCTAssertEqual(ring.corner, 20 + 2 * (content.minX - ring.rect.minX), accuracy: 0.0001)
        }
    }

    func testABlurReachesItsFullRadiusUnderTheContentSoTextFadesOutAtItsEdge() {
        let rings = BackdropFade(size: 80, padding: 0, corner: 20, blur: 8, ease: 2, roundness: 2, inset: 40).rings(in: area)
        XCTAssertEqual(rings.first?.rect, content.insetBy(dx: -80, dy: -80))
        XCTAssertEqual(rings.last?.rect, content.insetBy(dx: 40, dy: 40))
        XCTAssertEqual(rings.last?.strength ?? 0, 1, accuracy: 0.0001)
        XCTAssertEqual(rings.last?.corner, 0)
    }

    func testACornerIsAtMostHalfTheSideOfItsRing() {
        let short = CGRect(x: 0, y: 0, width: 580, height: 240)
        for ring in BackdropFade(size: 80, padding: 0, corner: 20, blur: nil, ease: 2, roundness: 2, inset: 40).rings(in: short) {
            XCTAssertLessThanOrEqual(ring.corner, min(ring.rect.width, ring.rect.height) / 2)
        }
    }

    func testAShorterAreaKeepsTheRowsAboveTheSplitAndMovesTheRowsBelowItByTheDifference() {
        let fade = BackdropFade(size: 80, padding: 0, corner: 20, blur: 8, ease: 2, roundness: 2, inset: 40)
        let tall = CGRect(x: 30, y: 0, width: 580, height: 700)
        let short = CGRect(x: 30, y: 0, width: 580, height: 500)
        guard let stretch = fade.stretch(from: tall, to: short, height: 700, scale: 0.5) else { return XCTFail("no stretch") }
        XCTAssertEqual(CGFloat(stretch.shift) / 0.5, tall.height - short.height)
        let split = CGFloat(stretch.split) / 0.5
        XCTAssertEqual(fade.stretch(from: tall, to: short, height: 700.5, scale: 0.5)?.split, stretch.split + 1)
        for (low, high) in zip(fade.rings(in: short), fade.rings(in: tall)) {
            XCTAssertEqual(low.rect.minY, high.rect.minY)
            XCTAssertEqual(low.rect.maxY + tall.height - short.height, high.rect.maxY)
            XCTAssertEqual(low.corner, high.corner)
            XCTAssertEqual(low.strength, high.strength)
            XCTAssertLessThanOrEqual(low.rect.minY + low.corner, split)
            XCTAssertGreaterThanOrEqual(low.rect.maxY - low.corner, split)
        }
    }

    func testTheShiftRoundsTheDifferenceToWholeRows() {
        let fade = BackdropFade(size: 80, padding: 0, corner: 20, blur: nil, ease: 2, roundness: 2, inset: 40)
        let stretch = fade.stretch(from: CGRect(x: 0, y: 0, width: 580, height: 700), to: CGRect(x: 0, y: 0, width: 580, height: 498.6), height: 700, scale: 0.5)
        XCTAssertEqual(stretch?.shift, 101)
    }

    func testAnAreaWithoutAStraightBandIsNotStretched() {
        let fade = BackdropFade(size: 80, padding: 0, corner: 20, blur: nil, ease: 2, roundness: 2, inset: 40)
        XCTAssertNil(fade.stretch(from: CGRect(x: 0, y: 0, width: 580, height: 700), to: CGRect(x: 0, y: 0, width: 580, height: 380), height: 700, scale: 0.5))
    }

    func testAnAreaOfAnotherSpanOrTallerThanThePictureIsNotStretched() {
        let fade = BackdropFade(size: 80, padding: 0, corner: 20, blur: nil, ease: 2, roundness: 2, inset: 40)
        let tall = CGRect(x: 0, y: 0, width: 580, height: 700)
        XCTAssertNil(fade.stretch(from: tall, to: CGRect(x: 10, y: 0, width: 580, height: 500), height: 700, scale: 0.5))
        XCTAssertNil(fade.stretch(from: tall, to: CGRect(x: 0, y: 0, width: 600, height: 500), height: 700, scale: 0.5))
        XCTAssertNil(fade.stretch(from: tall, to: CGRect(x: 0, y: 0, width: 580, height: 720), height: 700, scale: 0.5))
    }

    func testAnAreaWhoseStraightBandStartsAboveThePictureIsNotStretched() {
        let fade = BackdropFade(size: 80, padding: 0, corner: 20, blur: nil, ease: 2, roundness: 2, inset: 40)
        let tall = CGRect(x: 0, y: -600, width: 580, height: 1300)
        XCTAssertNil(fade.stretch(from: tall, to: CGRect(x: 0, y: -600, width: 580, height: 1100), height: 700, scale: 0.5))
    }
}
