import XCTest
@testable import OpenspotCore

final class CardFaceTests: XCTestCase {
    private let clock = """
    grid.wide=time power
    grid.large=time time power power
    grid.large=date date date date
    value=time

    text=date
    title=Sunday

    text=time
    title=14:20

    switch=power
    title=Alarm
    on=false
    """

    func testACardTakesTheDrawingOfItsSizeOrTheNearestSmallerOne() {
        let face = PluginOutput(text: clock).face

        XCTAssertNil(face.drawing(for: .small))
        XCTAssertEqual(face.drawing(for: .wide), [["time", "power"]])
        XCTAssertEqual(face.drawing(for: .square), [["time", "power"]])
        XCTAssertEqual(face.drawing(for: .strip), [["time", "power"]])
        XCTAssertEqual(face.drawing(for: .large), [["time", "time", "power", "power"], ["date", "date", "date", "date"]])
        XCTAssertEqual(face.parts.map(\.id), ["date", "time", "power"])
    }

    func testTheHeadNamesTheValueThatTheMenuBarShows() {
        XCTAssertEqual(MetricValue(output: PluginOutput(text: clock))?.title, "14:20")
    }

    func testWithNoNameTheOnlyValueStandsForTheSpotAndTwoStandForNone() {
        XCTAssertEqual(MetricValue(output: PluginOutput(text: "text=a\ntitle=A\n\nbutton=b\ntitle=B\n"))?.title, "A")
        XCTAssertNil(PluginOutput(text: "text=a\ntitle=A\n\ntext=b\ntitle=B\n").value)
    }

    func testTheNamedSwitchSaysWhetherTheCardIsOnWhereverItPrints() {
        let text = "value=power\n\nswitch=other\non=false\n\nswitch=power\non=true\n"
        XCTAssertEqual(SpotState(output: PluginOutput(text: text), header: SpotState(title: "Clock")).on, true)
        XCTAssertNil(SpotState(output: PluginOutput(text: "switch=a\non=true\n\nswitch=b\non=false\n"), header: SpotState(title: "Clock")).on)
    }

    func testANameThatNoValueHasAndAnUnknownPlaceAreFaults() {
        XCTAssertEqual(PluginOutput(text: "value=gone\n\nbutton=go\n").partFaults, ["the head names the value gone, which no text, number, gauge, graph, switch or slider has"])
        XCTAssertEqual(PluginOutput(text: "grid.tray=a\n\ntext=a\ntitle=A\n").partFaults, ["the head draws grid.tray, which is not a place"])
    }

    func testACardDrawingThatNamesNoComponentIsAFault() {
        XCTAssertEqual(PluginOutput(text: "grid.wide=a b\n\ntext=a\ntitle=A\n").partFaults, ["the card drawing names b, which no component has"])
    }

    func testAChangeOnTheCardShowsBeforeTheAnswer() {
        let state = SpotState(output: PluginOutput(text: clock), header: SpotState(title: "Clock"))

        XCTAssertEqual(state.setting("true", of: "power").face.parts.last?.control, .toggle(true))
    }
}
