import XCTest
@testable import OpenspotCore

final class MissedSearchTests: XCTestCase {
    func testASearchThatFoundNothingIsHeldFoldedUntilItIsTaken() {
        var missed = MissedSearch()

        missed.landed(" Tímezone ", found: false)

        XCTAssertEqual(missed.take(), "timezone")
        XCTAssertNil(missed.take())
    }

    func testAShorterSearchKeepsTheLongestAndALongerOneReplacesIt() {
        var missed = MissedSearch()

        missed.landed("timezone", found: false)
        missed.landed("time", found: true)
        missed.landed("tim", found: false)
        XCTAssertEqual(missed.text, "timezone")

        missed.landed("timezones", found: false)
        XCTAssertEqual(missed.text, "timezones")
    }

    func testANewSearchThatFoundSomethingDropsIt() {
        var missed = MissedSearch()

        missed.landed("xyzzy", found: false)
        missed.landed("coffee", found: true)

        XCTAssertNil(missed.text)
    }

    func testAShortSearchOrACommandIsNeverHeld() {
        var missed = MissedSearch()

        missed.landed("zq", found: false)
        XCTAssertNil(missed.text)
        missed.landed("/zzz", found: false)
        XCTAssertNil(missed.text)
    }
}
