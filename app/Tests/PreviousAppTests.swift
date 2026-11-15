import XCTest
@testable import OpenspotCore

final class PreviousAppTests: XCTestCase {
    func testAShowOverOpenspotKeepsTheAppBefore() {
        var previous = PreviousApp<String>()

        previous.show(over: "Safari", own: "Openspot")
        previous.show(over: "Openspot", own: "Openspot")

        XCTAssertEqual(previous.app, "Safari")
    }

    func testAShowOverAnotherAppRecordsIt() {
        var previous = PreviousApp<String>()

        previous.show(over: "Safari", own: "Openspot")
        previous.show(over: "Mail", own: "Openspot")

        XCTAssertEqual(previous.app, "Mail")
    }

    func testAShowOverNoAppForgetsTheAppBefore() {
        var previous = PreviousApp<String>()

        previous.show(over: "Safari", own: "Openspot")
        previous.show(over: nil, own: "Openspot")

        XCTAssertNil(previous.app)
    }
}
