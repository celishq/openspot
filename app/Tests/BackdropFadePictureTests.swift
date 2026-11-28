import CoreGraphics
import XCTest
@testable import OpenspotCore

final class BackdropFadePictureTests: XCTestCase {
    private let fade = BackdropFade(size: 80, padding: 0, corner: 20, blur: 8, ease: 2, roundness: 2, inset: 40)
    private let size = CGSize(width: 580, height: 700.5)
    private let scale = SpotTokens.backdropMaskScale

    private func bytes(_ image: CGImage?) -> [UInt8] {
        guard let image, let data = image.dataProvider?.data as Data? else { return [] }
        return [UInt8](data)
    }

    private func largestDifference(from drawn: CGRect, to area: CGRect) throws -> Int {
        let picture = try XCTUnwrap(fade.picture(of: drawn, size: size, scale: scale))
        let slices = try XCTUnwrap(fade.slices(from: drawn, to: area, size: size, scale: scale), "no slices from \(drawn) to \(area)")
        let built = bytes(BackdropFade.image(of: picture, slices: slices))
        let fresh = bytes(fade.picture(of: area, size: size, scale: scale)?.makeImage())
        XCTAssertEqual(built.count, fresh.count)
        return zip(built, fresh).map { abs(Int($0) - Int($1)) }.max() ?? .max
    }

    func testAMaskBuiltFromAnotherAreaMatchesOneDrawnForItsOwnArea() throws {
        let tall = CGRect(x: 30, y: 0, width: 520, height: 700)
        let areas = [
            CGRect(x: 30, y: 0, width: 520, height: 500),
            CGRect(x: 30, y: 0, width: 520, height: 690.3),
            CGRect(x: 60, y: 40, width: 400, height: 450),
            CGRect(x: 100.5, y: 150.25, width: 420, height: 430),
            CGRect(x: 0, y: 0, width: 580, height: 700)
        ]
        for area in areas {
            XCTAssertLessThanOrEqual(try largestDifference(from: tall, to: area), 9, "\(area)")
            XCTAssertLessThanOrEqual(try largestDifference(from: area, to: tall), 9, "back from \(area)")
        }
    }

    func testAFadeAtTheBackdropScaleStaysWithinEightLevelsOfOneAtHalfScale() throws {
        let area = CGRect(x: 30, y: 0, width: 520, height: 700)
        let fine = try XCTUnwrap(fade.picture(of: area, size: size, scale: 0.5))
        let coarse = try XCTUnwrap(fade.picture(of: area, size: size, scale: SpotTokens.backdropMaskScale))
        let fineAlpha = alpha(fine)
        let coarseAlpha = alpha(coarse)
        let ratio = Double(SpotTokens.backdropMaskScale) / 0.5
        var largest = 0
        for y in 0..<fine.height {
            for x in 0..<fine.width {
                let sampled = sample(coarseAlpha, width: coarse.width, height: coarse.height, x: (Double(x) + 0.5) * ratio - 0.5, y: (Double(y) + 0.5) * ratio - 0.5)
                largest = max(largest, abs(Int(sampled.rounded()) - Int(fineAlpha[y * fine.width + x])))
            }
        }
        XCTAssertLessThan(SpotTokens.backdropMaskScale, 0.5)
        XCTAssertLessThanOrEqual(largest, 8)
    }

    private func alpha(_ picture: CGContext) -> [UInt8] {
        let data = picture.data!.assumingMemoryBound(to: UInt8.self)
        return (0..<picture.height).flatMap { y in (0..<picture.width).map { x in data[y * picture.bytesPerRow + x * 4 + 3] } }
    }

    private func sample(_ alpha: [UInt8], width: Int, height: Int, x: Double, y: Double) -> Double {
        let x = min(max(x, 0), Double(width - 1))
        let y = min(max(y, 0), Double(height - 1))
        let left = Int(x), top = Int(y)
        let right = min(left + 1, width - 1), bottom = min(top + 1, height - 1)
        let dx = x - Double(left), dy = y - Double(top)
        let value = { (column: Int, row: Int) in Double(alpha[row * width + column]) }
        let upper = value(left, top) * (1 - dx) + value(right, top) * dx
        let lower = value(left, bottom) * (1 - dx) + value(right, bottom) * dx
        return upper * (1 - dy) + lower * dy
    }

    func testAnAreaWithoutAStraightBandIsDrawnAfresh() {
        let tall = CGRect(x: 0, y: 0, width: 580, height: 700)
        XCTAssertNil(fade.slices(from: tall, to: CGRect(x: 0, y: 0, width: 580, height: 380), size: size, scale: scale))
        XCTAssertNil(fade.slices(from: tall, to: CGRect(x: 0, y: 0, width: 380, height: 700), size: size, scale: scale))
        XCTAssertNil(fade.slices(from: tall, to: CGRect(x: 150.5, y: 250.25, width: 300, height: 300), size: size, scale: scale))
    }
}
