import XCTest
@testable import OpenspotCore

final class SpotKindTests: XCTestCase {
    func testParsesEachKindName() {
        XCTAssertEqual(SpotKind(rawValue: "launch"), .launch)
        XCTAssertEqual(SpotKind(rawValue: "toggle"), .toggle)
        XCTAssertEqual(SpotKind(rawValue: "expand"), .expand)
        XCTAssertEqual(SpotKind(rawValue: "slider"), .slider)
    }

    func testRejectsAnUnknownKindName() {
        XCTAssertNil(SpotKind(rawValue: "media"))
    }
}
