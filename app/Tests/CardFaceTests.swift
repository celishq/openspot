import XCTest
@testable import OpenspotCore

final class CardFaceTests: XCTestCase {
    private let clock = """
    grid.wide=time power
    grid.large=time time power power
    grid.large=date date date date
    main=time

    text=date
    title=Sunday

    text=time
    title=14:20

    switch=power
    title=Alarm
    value=false
    """

    func testACardTakesTheDrawingOfItsSizeOrTheNearestSmallerOne() {
        let face = SpotOutput(text: clock).face

        XCTAssertNil(face.drawing(for: .small))
        XCTAssertEqual(face.drawing(for: .wide), [["time", "power"]])
        XCTAssertEqual(face.drawing(for: .square), [["time", "power"]])
        XCTAssertEqual(face.drawing(for: .strip), [["time", "power"]])
        XCTAssertEqual(face.drawing(for: .large), [["time", "time", "power", "power"], ["date", "date", "date", "date"]])
        XCTAssertNil(face.layout(for: .small))
        XCTAssertEqual(face.layout(for: .square), WidgetLayout(drawing: ["time power"], size: .square))
        XCTAssertEqual(face.layout(for: .large), WidgetLayout(drawing: ["time time power power", "date date date date"], size: .large))
        XCTAssertEqual(face.parts.map(\.id), ["date", "time", "power"])
    }

    func testTheHeadNamesTheValueThatTheMenuBarShows() {
        XCTAssertEqual(MetricValue(output: SpotOutput(text: clock))?.title, "14:20")
    }

    func testWithNoNameTheOnlyValueStandsForTheSpotAndTwoStandForNone() {
        XCTAssertEqual(MetricValue(output: SpotOutput(text: "text=a\ntitle=A\n\nbutton=b\ntitle=B\n"))?.title, "A")
        XCTAssertNil(SpotOutput(text: "text=a\ntitle=A\n\ntext=b\ntitle=B\n").value)
    }

    func testOnlyTheMainSwitchSaysWhetherTheCardIsOn() {
        XCTAssertNil(SpotState(output: SpotOutput(text: "on=true\ndetail=Awake\n"), header: SpotState(title: "Clock")).on)
    }

    func testTheNamedSwitchSaysWhetherTheCardIsOnWhereverItPrints() {
        let text = "main=power\n\nswitch=other\nvalue=false\n\nswitch=power\nvalue=true\n"
        XCTAssertEqual(SpotState(output: SpotOutput(text: text), header: SpotState(title: "Clock")).on, true)
        XCTAssertNil(SpotState(output: SpotOutput(text: "switch=a\nvalue=true\n\nswitch=b\nvalue=false\n"), header: SpotState(title: "Clock")).on)
    }

    func testANameThatNoValueHasAndAnUnknownPlaceAreFaults() {
        XCTAssertEqual(SpotOutput(text: "main=gone\n\nbutton=go\ntitle=Go\n").partFaults, ["the head names gone as main, which no text, number, gauge, graph, switch or slider has"])
        XCTAssertEqual(SpotOutput(text: "grid.tray=a\n\ntext=a\ntitle=A\n").partFaults, ["the head draws grid.tray, which is not a place"])
    }

    func testACardDrawingThatNamesNoComponentIsAFault() {
        XCTAssertEqual(SpotOutput(text: "grid.wide=a b\n\ntext=a\ntitle=A\n").partFaults, ["the card drawing names b, which no component has"])
    }

    func testAChangeOnTheCardShowsBeforeTheAnswer() {
        let state = SpotState(output: SpotOutput(text: clock), header: SpotState(title: "Clock"))

        XCTAssertEqual(state.setting("true", of: "power").face.parts.last?.control, .toggle(true))
    }

    func testAnAnswerThatDrawsALargeCardIsOneCardWhosePressSendsItsMainValue() {
        let answer = SpotOutput(text: """
        grid.large=sum sum sum sum
        grid.large=answer answer answer answer
        main=answer

        text=sum
        title=1000 + 234.5

        number=answer
        value=1234.5
        display=1,234.5
        """)

        XCTAssertEqual(answer.answers.map(\.run), ["1234.5"])
        XCTAssertEqual(answer.answers.first?.title, "1,234.5")
        XCTAssertEqual(answer.answers.first?.card?.face.answerSize, .large)
        XCTAssertEqual(answer.answers.first?.card?.face.parts.last?.control, .metric("1,234.5"))
    }

    func testAnAnswerWithNoMainValueOrNoFullWidthDrawingIsItsRows() {
        let noMain = SpotOutput(text: "grid.strip=a b\n\nnumber=a\nvalue=1\n\nnumber=b\nvalue=2\n\nrow=r\ntitle=R\n")
        let wide = SpotOutput(text: "grid.wide=a\n\nnumber=a\nvalue=1\n\nrow=r\ntitle=R\n")
        let strip = SpotOutput(text: "grid.strip=a\n\nnumber=a\nvalue=1\n")

        XCTAssertEqual(noMain.answers.map(\.run), ["r"])
        XCTAssertEqual(wide.answers.map(\.run), ["r"])
        XCTAssertEqual(strip.answers.first?.card?.face.answerSize, .strip)
    }
}
