import XCTest
@testable import OpenspotCore

@MainActor
final class CallerTokensTests: SpotRunsCase {
    func testACallWithNoTokenOrAnUnknownOneIsThePersons() {
        XCTAssertNil(runs.tokens.caller(of: nil))
        XCTAssertNil(runs.tokens.caller(of: "0123456789abcdef0123456789abcdef"))
    }
}
