import XCTest
@testable import OpenspotCore

final class SpotStateTests: XCTestCase {
    private let header = SpotState(title: "Name", subtitle: "From header")

    private func state(_ text: String) throws -> SpotState {
        SpotState(output: SpotOutput(text: text), header: header)
    }

    func testAFrameOfAScriptCannotMoveItsCardOnOrOffTheGrid() throws {
        let hidden = SpotState(title: "Name", isOnGrid: false)

        XCTAssertFalse(SpotState(output: SpotOutput(text: "grid=true"), header: hidden).isOnGrid)
        XCTAssertTrue(try state("grid=false").isOnGrid)
    }

    func testAReadKeepsEachValueOfItsHeadForAViewAndAChangeKeepsThem() throws {
        let head = try XCTUnwrap(TextBlock.blocks(in: "title=3\npoint=1\npoint=0\npoint=2").first)
        let read = SpotState(output: SpotOutput(text: head.text), header: header).holding(head)
        let block = SpotOutput(text: "switch=power\nvalue=true")

        XCTAssertEqual(SpotState(output: SpotOutput(text: head.text), header: header).values, [:])
        XCTAssertEqual(read.values, ["title": ["3"], "point": ["1", "0", "2"]])
        XCTAssertEqual(read.taking(block).values, read.values)
        XCTAssertEqual(read.showing(title: "Busy", detail: nil).values, read.values)
    }

    func testActiveInTheHeadSaysWhetherTheCardIsOnAndWinsOverTheMainSwitch() throws {
        XCTAssertEqual(try state("detail=25m left\nactive=true\n\nrow=off\ntitle=Turn off").on, true)
        XCTAssertEqual(try state("detail=Off\nactive=false").on, false)
        XCTAssertEqual(try state("active=false\n\nswitch=power\nvalue=true").on, false)
        XCTAssertEqual(try state("detail=Off\n\nswitch=power\nvalue=true").on, true)
        XCTAssertEqual(try state("detail=Off").on, nil)
    }

    func testAFrameWithNoGridKeepsTheHeader() {
        let hidden = SpotState(title: "Name", isOnGrid: false)

        XCTAssertFalse(SpotState(output: SpotOutput(text: "title=New"), header: hidden).isOnGrid)
        XCTAssertFalse(SpotState(output: SpotOutput(text: ""), header: hidden).isOnGrid)
    }

    func testAChangedStateStaysOffTheGrid() throws {
        let hidden = SpotState(title: "Name", level: 1, isOnGrid: false)
        let block = SpotOutput(text: "switch=power\nvalue=true")

        XCTAssertFalse(hidden.taking(block).isOnGrid)
        XCTAssertFalse(hidden.showing(title: "Work", detail: nil).isOnGrid)
        XCTAssertFalse(hidden.withLevel(2).isOnGrid)
    }

    func testReadsAToggleState() throws {
        let state = try state("switch=wifi\ntitle=Wi-Fi\ndetail=VIRGIN-telco_5668\nvalue=true")
        XCTAssertEqual(state.title, "Wi-Fi")
        XCTAssertEqual(state.subtitle, "VIRGIN-telco_5668")
        XCTAssertEqual(state.on, true)
    }

    func testReadsASliderState() throws {
        let state = try state("field=display\ntype=slider\ntitle=Display\nvalue=70\nmin=0\nmax=100")
        XCTAssertEqual(state.level, 70)
        XCTAssertEqual(state.min, 0)
        XCTAssertEqual(state.max, 100)
    }

    func testAStateTakesFromTheHeaderWhatItLeavesOut() throws {
        let state = try state("switch=power\nvalue=true")
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
