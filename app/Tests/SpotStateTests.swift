import XCTest
@testable import OpenspotCore

final class SpotStateTests: XCTestCase {
    private let header = SpotState(title: "Name", subtitle: "From header")

    private func state(_ text: String) throws -> SpotState {
        SpotState(output: Frame(text: text), header: header)
    }

    func testAFrameOfAScriptCannotMoveItsCardOnOrOffTheGrid() throws {
        let hidden = SpotState(title: "Name", isOnGrid: false)

        XCTAssertFalse(SpotState(output: Frame(text: "shown=true"), header: hidden).isOnGrid)
        XCTAssertTrue(try state("shown=false").isOnGrid)
    }

    func testActiveInTheHeadSaysWhetherTheCardIsOnAndWinsOverTheMainSwitch() throws {
        XCTAssertEqual(try state("frame=\ndetail=25m left\nactive=true\n\ntext=off\ntitle=Turn off").on, true)
        XCTAssertEqual(try state("frame=\ndetail=Off\nactive=false").on, false)
        XCTAssertEqual(try state("frame=\nactive=false\n\nswitch=power\nclass=card:flex\nvalue=true").on, false)
        XCTAssertEqual(try state("frame=\ndetail=Off\n\nswitch=power\nclass=card:flex\nvalue=true").on, true)
        XCTAssertEqual(try state("detail=Off").on, nil)
    }

    func testAFrameWithNoGridKeepsTheHeader() {
        let hidden = SpotState(title: "Name", isOnGrid: false)

        XCTAssertFalse(SpotState(output: Frame(text: "title=New"), header: hidden).isOnGrid)
        XCTAssertFalse(SpotState(output: Frame(text: ""), header: hidden).isOnGrid)
    }

    func testAChangedStateStaysOffTheGrid() throws {
        let hidden = SpotState(title: "Name", level: 1, isOnGrid: false)
        let block = Frame(text: "switch=power\nclass=card:flex\nvalue=true")

        XCTAssertFalse(hidden.taking(block).isOnGrid)
        XCTAssertFalse(hidden.showing(title: "Work", detail: nil).isOnGrid)
        XCTAssertFalse(hidden.withLevel(2).isOnGrid)
    }

    func testReadsAToggleStateUnderTheWordsOfTheHeader() throws {
        let state = try state("switch=wifi\nclass=card:flex\ntitle=Wi-Fi\ndetail=VIRGIN-telco_5668\nvalue=true")
        XCTAssertEqual(state.title, "Name")
        XCTAssertEqual(state.subtitle, "From header")
        XCTAssertEqual(state.on, true)
    }

    func testReadsASliderState() throws {
        let state = try state("field=display\ntype=slider\ntitle=Display\nvalue=70\nmin=0\nmax=100")
        XCTAssertEqual(state.level, 70)
        XCTAssertEqual(state.min, 0)
        XCTAssertEqual(state.max, 100)
    }

    func testAStateTakesFromTheHeaderWhatItLeavesOut() throws {
        let state = try state("switch=power\nclass=card:flex\nvalue=true")
        XCTAssertEqual(state.title, "Name")
        XCTAssertEqual(state.subtitle, "From header")
    }

    func testSettingASliderLevelClampsToItsRange() {
        let state = SpotState(title: "Display", level: 50, min: 0, max: 100)
        XCTAssertEqual(state.withLevel(140).level, 100)
        XCTAssertEqual(state.withLevel(-5).level, 0)
        XCTAssertEqual(state.withLevel(33).level, 33)
    }
}
