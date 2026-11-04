import XCTest
@testable import OpenspotCore

final class OpenspotVersionTests: XCTestCase {
    func testApiVersionIsOne() {
        XCTAssertEqual(OpenspotVersion.api, 1)
    }
}
