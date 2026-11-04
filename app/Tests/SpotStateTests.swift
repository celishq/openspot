import XCTest
@testable import OpenspotCore

final class SpotStateTests: XCTestCase {
    func testDecodesAToggleState() throws {
        let json = #"{"title": "Wi-Fi", "subtitle": "VIRGIN-telco_5668", "on": true}"#
        let state = try JSONDecoder().decode(SpotState.self, from: Data(json.utf8))
        XCTAssertEqual(state.title, "Wi-Fi")
        XCTAssertEqual(state.subtitle, "VIRGIN-telco_5668")
        XCTAssertEqual(state.on, true)
    }

    func testDecodesASliderState() throws {
        let json = #"{"title": "Display", "level": 70, "min": 0, "max": 100}"#
        let state = try JSONDecoder().decode(SpotState.self, from: Data(json.utf8))
        XCTAssertEqual(state.level, 70)
        XCTAssertEqual(state.min, 0)
        XCTAssertEqual(state.max, 100)
    }

    func testDecodesExpandItems() throws {
        let json = #"{"title": "Wi-Fi", "items": [{"title": "Office 5G", "run": "networksetup -setairportnetwork en0 Office"}]}"#
        let state = try JSONDecoder().decode(SpotState.self, from: Data(json.utf8))
        XCTAssertEqual(state.items, [SpotItem(title: "Office 5G", run: "networksetup -setairportnetwork en0 Office")])
    }

    func testAdjustingASliderMovesItWithinItsRange() {
        let state = SpotState(title: "Display", level: 95, min: 0, max: 100)
        XCTAssertEqual(state.adjusted(by: 10).level, 100)
        XCTAssertEqual(state.adjusted(by: -10).level, 85)
    }

    func testAdjustingASliderStopsAtZero() {
        let state = SpotState(title: "Sound", level: 4, min: 0, max: 100)
        XCTAssertEqual(state.adjusted(by: -10).level, 0)
    }

    func testSettingASliderLevelClampsToItsRange() {
        let state = SpotState(title: "Display", level: 50, min: 0, max: 100)
        XCTAssertEqual(state.withLevel(140).level, 100)
        XCTAssertEqual(state.withLevel(-5).level, 0)
        XCTAssertEqual(state.withLevel(33).level, 33)
    }
}
