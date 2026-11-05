import XCTest
@testable import OpenspotCore

final class SpotStateTests: XCTestCase {
    private let header = SpotState(title: "Name", subtitle: "From header")

    private func state(_ text: String) throws -> SpotState {
        SpotState(block: try XCTUnwrap(TextBlock.blocks(in: text).first), header: header)
    }

    func testReadsAToggleState() throws {
        let state = try state("title=Wi-Fi\ndetail=VIRGIN-telco_5668\non=true")
        XCTAssertEqual(state.title, "Wi-Fi")
        XCTAssertEqual(state.subtitle, "VIRGIN-telco_5668")
        XCTAssertEqual(state.on, true)
    }

    func testReadsASliderState() throws {
        let state = try state("title=Display\nlevel=70\nmin=0\nmax=100")
        XCTAssertEqual(state.level, 70)
        XCTAssertEqual(state.min, 0)
        XCTAssertEqual(state.max, 100)
    }

    func testAStateTakesFromTheHeaderWhatItLeavesOut() throws {
        let state = try state("on=true")
        XCTAssertEqual(state.title, "Name")
        XCTAssertEqual(state.subtitle, "From header")
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
