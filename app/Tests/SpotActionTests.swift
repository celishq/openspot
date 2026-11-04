import XCTest
@testable import OpenspotCore

final class SpotActionTests: XCTestCase {
    func testTogglingAnOffSpotSendsOn() {
        let state = SpotState(title: "Focus", on: false)
        XCTAssertEqual(SpotAction.toggle(state).arguments, ["on"])
    }

    func testTogglingAnOnSpotSendsOff() {
        let state = SpotState(title: "Wi-Fi", on: true)
        XCTAssertEqual(SpotAction.toggle(state).arguments, ["off"])
    }

    func testASliderLevelIsSentAsARoundedNumber() {
        XCTAssertEqual(SpotAction.level(69.6).arguments, ["70"])
    }

    func testARunSendsNoArguments() {
        XCTAssertEqual(SpotAction.run.arguments, [])
    }
}
