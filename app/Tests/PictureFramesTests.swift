import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import OpenspotCore

final class PictureFramesTests: XCTestCase {
    private func gif(width: Int, height: Int, delays: [Double]) throws -> String {
        let file = try temporaryFolder().appendingPathComponent("moving.gif")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(file as CFURL, UTType.gif.identifier as CFString, delays.count, nil))
        for (index, delay) in delays.enumerated() {
            let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setFillColor(CGColor(red: CGFloat(index % 2), green: 0, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            let properties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary
            CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), properties)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return file.path
    }

    func testAMovingGIFGivesEachFrameAndItsDelay() throws {
        let path = try gif(width: 20, height: 10, delays: [0.1, 0.2, 0.3])

        let frames = try XCTUnwrap(PictureFile(path: path).readFrames(shortSide: 100, bytes: 1 << 20))

        XCTAssertEqual(frames.images.count, 3)
        XCTAssertEqual(frames.delays, [0.1, 0.2, 0.3], accuracy: 0.001)
        XCTAssertEqual(frames.keyTimes, [0, 1.0 / 6, 0.5, 1], accuracy: 0.001)
        XCTAssertEqual(frames.size, CGSize(width: 20, height: 10))
    }

    func testAFrameWithNoDelayShowsForATenthOfASecond() throws {
        let path = try gif(width: 4, height: 4, delays: [0, 0.5])

        let frames = try XCTUnwrap(PictureFile(path: path).readFrames(shortSide: 100, bytes: 1 << 20))

        XCTAssertEqual(frames.delays, [0.1, 0.5], accuracy: 0.001)
    }

    func testAGIFOfOneFrameIsAStillPicture() throws {
        let path = try gif(width: 4, height: 4, delays: [0.1])

        XCTAssertNil(PictureFile(path: path).readFrames(shortSide: 100, bytes: 1 << 20))
    }

    func testFramesShrinkToTheShortSide() throws {
        let path = try gif(width: 200, height: 100, delays: [0.1, 0.1])

        let frames = try XCTUnwrap(PictureFile(path: path).readFrames(shortSide: 50, bytes: 1 << 20))

        XCTAssertEqual(frames.images.map(\.width), [100, 100])
        XCTAssertEqual(frames.images.map(\.height), [50, 50])
    }

    func testAllFramesFitInTheBytes() throws {
        let path = try gif(width: 100, height: 100, delays: [0.1, 0.1, 0.1, 0.1])
        let bytes = 4 * 32 * 32 * 4

        let frames = try XCTUnwrap(PictureFile(path: path).readFrames(shortSide: 100, bytes: bytes))

        XCTAssertLessThanOrEqual(frames.bytes, bytes)
        XCTAssertEqual(frames.images.map(\.width), [32, 32, 32, 32])
    }
}

private func XCTAssertEqual(_ actual: [Double], _ expected: [Double], accuracy: Double, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(actual.count, expected.count, file: file, line: line)
    for (got, want) in zip(actual, expected) { XCTAssertEqual(got, want, accuracy: accuracy, file: file, line: line) }
}
