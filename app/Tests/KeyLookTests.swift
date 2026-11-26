import XCTest
@testable import OpenspotCore

final class KeyLookTests: XCTestCase {
    private func assertLook(_ key: String, shape: Float, pattern: Float, facets: Float, angle: Float, firstStop: SIMD3<Float>, dots: Int) {
        let look = KeyLook(key: key)
        XCTAssertEqual(look.shape, shape)
        XCTAssertEqual(look.pattern, pattern)
        XCTAssertEqual(look.facets, facets)
        XCTAssertEqual(look.angle, angle, accuracy: 0.0001)
        XCTAssertEqual(look.stops[0].x, firstStop.x, accuracy: 0.0001)
        XCTAssertEqual(look.stops[0].y, firstStop.y, accuracy: 0.0001)
        XCTAssertEqual(look.stops[0].z, firstStop.z, accuracy: 0.0001)
        XCTAssertEqual(look.emblem.count, dots)
    }

    func testAKeyGivesTheLookTheMockUpGivesIt() {
        assertLook("npub1x7k2m9q4w8e3r6t5y0u2i7o9p3a5s8d1f4g6h2j8k3l5z7c9v", shape: 1, pattern: 4, facets: 70, angle: 3.589, firstStop: SIMD3(0.36, 0.0954, 4.0224), dots: 17)
        assertLook("npub1qz8f3k2m4n6p8r0t2v4x6z8b0d2f4h6j8l0n2q4s6u8w0y2a4c6e", shape: 0, pattern: 1, facets: 240, angle: 4.5616, firstStop: SIMD3(0.8, 0.147, 0.3291), dots: 14)
    }
}
