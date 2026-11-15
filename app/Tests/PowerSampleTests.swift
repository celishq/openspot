import XCTest
@testable import OpenspotCore

final class PowerSampleTests: XCTestCase {
    func testAnotherPercentOrAnotherSourceRaisesAPowerChangeAndTheSameSampleRaisesNone() {
        let first = PowerSample(source: "battery", percent: 80)

        XCTAssertEqual(PowerSample(source: "battery", percent: 79).event(after: first), .named(SpotEvent.powerChange, value: "battery"))
        XCTAssertEqual(PowerSample(source: "ac", percent: 80).event(after: first), .named(SpotEvent.powerChange, value: "ac"))
        XCTAssertNil(PowerSample(source: "battery", percent: 80).event(after: first))
        XCTAssertNil(PowerSample(source: "ac", percent: nil).event(after: PowerSample(source: "ac", percent: nil)))
    }
}
