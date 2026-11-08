import XCTest
@testable import OpenspotCore

final class CardFaceTests: XCTestCase {
    private let clock = """
    grid.wide=time power
    grid.large=time time power power
    grid.large=date date date date
    grid.tray=time

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

    func testTheTrayDrawingChoosesTheValueOfTheMenuBar() {
        XCTAssertEqual(MetricValue(output: PluginOutput(text: clock))?.title, "14:20")
    }

    func testACardDrawingThatNamesNoComponentIsAFault() {
        XCTAssertEqual(PluginOutput(text: "grid.wide=a b\n\ntext=a\ntitle=A\n").partFaults, ["the card drawing names b, which no component has"])
    }

    func testAChangeOnTheCardShowsBeforeTheAnswer() {
        let state = SpotState(output: PluginOutput(text: clock), header: SpotState(title: "Clock"))

        XCTAssertEqual(state.setting("true", of: "power").face.parts.last?.control, .toggle(true))
    }
}
