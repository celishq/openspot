import CoreGraphics
import XCTest
@testable import OpenspotCore

final class BackdropFadePictureTests: XCTestCase {
    private let fade = BackdropFade(size: 80, padding: 0, corner: 20, blur: 8, ease: 2, roundness: 2, inset: 40)
    private let size = CGSize(width: 580, height: 700.5)
    private let scale: CGFloat = 0.5

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
            XCTAssertLessThanOrEqual(try largestDifference(from: tall, to: area), 8, "\(area)")
            XCTAssertLessThanOrEqual(try largestDifference(from: area, to: tall), 8, "back from \(area)")
        }
    }

    func testAnAreaWithoutAStraightBandIsDrawnAfresh() {
        let tall = CGRect(x: 0, y: 0, width: 580, height: 700)
        XCTAssertNil(fade.slices(from: tall, to: CGRect(x: 0, y: 0, width: 580, height: 380), size: size, scale: scale))
        XCTAssertNil(fade.slices(from: tall, to: CGRect(x: 0, y: 0, width: 380, height: 700), size: size, scale: scale))
        XCTAssertNil(fade.slices(from: tall, to: CGRect(x: 150.5, y: 250.25, width: 300, height: 300), size: size, scale: scale))
    }
}
