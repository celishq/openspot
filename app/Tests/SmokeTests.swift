import XCTest
@testable import OpenspotCore

final class SmokeTests: XCTestCase {
    func testApiVersionIsOne() {
        XCTAssertEqual(OpenspotVersion.api, 1)
    }
}
