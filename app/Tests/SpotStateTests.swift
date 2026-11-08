import XCTest
@testable import OpenspotCore

final class SpotStateTests: XCTestCase {
    private let header = SpotState(title: "Name", subtitle: "From header")

    private func state(_ text: String) throws -> SpotState {
        SpotState(output: PluginOutput(text: text), header: header)
    }

    func testAFrameOfAScriptCannotMoveItsCardOnOrOffTheGrid() throws {
        let hidden = SpotState(title: "Name", isOnGrid: false)

        XCTAssertFalse(SpotState(output: PluginOutput(text: "grid=true"), header: hidden).isOnGrid)
        XCTAssertTrue(try state("grid=false").isOnGrid)
    }

    func testAReadSetsTheSizeOfItsCardAndAChangeKeepsIt() throws {
        let read = try state("size=large")
        let block = PluginOutput(text: "switch=power\non=true")

        XCTAssertNil(header.size)
        XCTAssertEqual(read.size, .large)
        XCTAssertEqual(read.taking(block).size, .large)
        XCTAssertEqual(read.showing(title: "Busy", detail: nil).size, .large)
        XCTAssertEqual(read.withLevel(2).size, .large)
    }

    func testAReadKeepsEachValueOfItsHeadForAViewAndAChangeKeepsThem() throws {
        let head = try XCTUnwrap(TextBlock.blocks(in: "title=3\npoint=1\npoint=0\npoint=2").first)
        let read = SpotState(output: PluginOutput(text: head.text), header: header).holding(head)
        let block = PluginOutput(text: "switch=power\non=true")

        XCTAssertEqual(SpotState(output: PluginOutput(text: head.text), header: header).values, [:])
        XCTAssertEqual(read.values, ["title": ["3"], "point": ["1", "0", "2"]])
        XCTAssertEqual(read.taking(block).values, read.values)
        XCTAssertEqual(read.showing(title: "Busy", detail: nil).values, read.values)
    }

    func testAFrameWithNoGridKeepsTheHeader() {
        let hidden = SpotState(title: "Name", isOnGrid: false)

        XCTAssertFalse(SpotState(output: PluginOutput(text: "title=New"), header: hidden).isOnGrid)
        XCTAssertFalse(SpotState(output: PluginOutput(text: ""), header: hidden).isOnGrid)
    }

    func testAChangedStateStaysOffTheGrid() throws {
        let hidden = SpotState(title: "Name", level: 1, isOnGrid: false)
        let block = PluginOutput(text: "switch=power\non=true")

        XCTAssertFalse(hidden.taking(block).isOnGrid)
        XCTAssertFalse(hidden.showing(title: "Work", detail: nil).isOnGrid)
        XCTAssertFalse(hidden.withLevel(2).isOnGrid)
    }

    func testReadsAToggleState() throws {
        let state = try state("switch=wifi\ntitle=Wi-Fi\ndetail=VIRGIN-telco_5668\non=true")
        XCTAssertEqual(state.title, "Wi-Fi")
        XCTAssertEqual(state.subtitle, "VIRGIN-telco_5668")
        XCTAssertEqual(state.on, true)
    }

    func testReadsASliderState() throws {
        let state = try state("slider=display\ntitle=Display\nlevel=70\nmin=0\nmax=100")
        XCTAssertEqual(state.level, 70)
        XCTAssertEqual(state.min, 0)
        XCTAssertEqual(state.max, 100)
    }

    func testAStateTakesFromTheHeaderWhatItLeavesOut() throws {
        let state = try state("switch=power\non=true")
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
