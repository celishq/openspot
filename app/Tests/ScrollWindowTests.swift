import XCTest
@testable import OpenspotCore

final class ScrollWindowTests: XCTestCase {
    private let window = ScrollWindow(top: 100, bottom: 400, viewHeight: 500, contentHeight: 1000)

    func testASpanInTheClearPartDoesNotMove() {
        XCTAssertEqual(window.offset(showing: 150...300, from: 0), 0)
    }

    func testASpanBelowTheClearPartScrollsUpUntilItsBottomShows() {
        XCTAssertEqual(window.offset(showing: 500...600, from: 0), 200)
    }

    func testASpanAboveTheClearPartScrollsDownUntilItsTopShows() {
        XCTAssertEqual(window.offset(showing: 250...300, from: 300), 150)
    }

    func testTheOffsetStopsAtTheTopOfTheContent() {
        XCTAssertEqual(window.offset(showing: 50...100, from: 300), 0)
    }

    func testTheOffsetStopsAtTheEndOfTheContent() {
        XCTAssertEqual(window.offset(showing: 900...1000, from: 0), 500)
    }

    func testContentThatFitsNeverScrolls() {
        let short = ScrollWindow(top: 100, bottom: 400, viewHeight: 500, contentHeight: 300)
        XCTAssertEqual(short.offset(showing: 450...480, from: 0), 0)
    }
}
