import XCTest
@testable import OpenspotCore

final class AccountHandleTests: XCTestCase {
    func testAHandleIsThreeToTwentyOfLowercaseLettersDigitsDashAndUnderscore() {
        XCTAssertEqual(AccountHandle("tony_p-2")?.text, "tony_p-2")
        XCTAssertNil(AccountHandle("to"))
        XCTAssertNil(AccountHandle(String(repeating: "a", count: 21)))
        XCTAssertNil(AccountHandle("Tony"))
        XCTAssertNil(AccountHandle("tony p"))
        XCTAssertNil(AccountHandle("tony.p"))
    }
}
