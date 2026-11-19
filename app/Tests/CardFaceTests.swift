import XCTest
@testable import OpenspotCore

final class CardFaceTests: XCTestCase {
    private let clock = """
    frame=
    grid.wide=time power
    grid.large=time time power power
    grid.large=date date date date
    grid.bar=time

    text=date
    title=Sunday

    text=time
    title=14:20

    switch=power
    title=Alarm
    value=false
    """

    func testACardTakesTheDrawingOfItsSizeOrTheNearestSmallerOne() {
        let face = Frame(text: clock).face

        XCTAssertNil(face.drawing(for: .small))
        XCTAssertEqual(face.drawing(for: .wide), [["time", "power"]])
        XCTAssertEqual(face.drawing(for: .square), [["time", "power"]])
        XCTAssertEqual(face.drawing(for: .strip), [["time", "power"]])
        XCTAssertEqual(face.drawing(for: .large), [["time", "time", "power", "power"], ["date", "date", "date", "date"]])
        XCTAssertNil(face.layout(for: .small))
        XCTAssertEqual(face.layout(for: .square), CardLayout(drawing: ["time power"], size: .square))
        XCTAssertEqual(face.layout(for: .large), CardLayout(drawing: ["time time power power", "date date date date"], size: .large))
        XCTAssertEqual(face.parts.map(\.id), ["date", "time", "power"])
    }

    func testTheBarLayoutNamesTheValueThatTheMenuBarShows() {
        let output = Frame(text: clock)

        XCTAssertTrue(output.hasBar)
        XCTAssertEqual(MetricValue(output: output.barred)?.title, "14:20")
        XCTAssertNil(output.value)
    }

    func testWithNoNameTheOnlyValueStandsForTheSpotAndTwoStandForNone() {
        XCTAssertEqual(MetricValue(output: Frame(text: "text=a\ntitle=A\n\nbutton=b\ntitle=B\n"))?.title, "A")
        XCTAssertNil(Frame(text: "text=a\ntitle=A\n\ntext=b\ntitle=B\n").value)
    }

    func testOnlyTheMainSwitchSaysWhetherTheCardIsOn() {
        XCTAssertNil(SpotState(output: Frame(text: "on=true\ndetail=Awake\n"), header: SpotState(title: "Clock")).on)
    }

    func testOnlyASwitchThatIsTheWholeCardSaysWhetherTheCardIsOn() {
        let state = { (text: String) in SpotState(output: Frame(text: text), header: SpotState(title: "Clock")).on }
        XCTAssertEqual(state("switch=power\nvalue=true\n"), true)
        XCTAssertNil(state("switch=power\nvalue=true\n\ntext=a\ntitle=A\n"))
        XCTAssertNil(state("switch=power\nvalue=true\n\ntext=bar\ntitle=Bar\n"))
        XCTAssertNil(state("frame=\nmain=power\n\nswitch=power\nvalue=true\n\ntext=bar\ntitle=Bar\n"))
        XCTAssertNil(SpotState(title: "Clock").taking(Frame(text: "frame=\nmain=power\n\nswitch=power\nvalue=true\n\ntext=bar\ntitle=Bar\n")).on)
    }

    func testTheOneValueBlockThatALayoutPlacesIsTheValueOfTheCard() {
        let outputCheck = FrameCheck(text: "frame=\ngrid=power\n\nswitch=power\nvalue=true\n\ntext=bar\ntitle=Bar\n")
        let output = outputCheck.output
        XCTAssertEqual(output.value?.value("switch"), "power")
        XCTAssertEqual(outputCheck.partFaults, [])
    }

    func testMainAndAnUnknownPlaceAreFaults() {
        XCTAssertEqual(FrameCheck(text: "frame=\nmain=gone\n\nbutton=go\ntitle=Go\n").partFaults, ["the root has an unknown key: main"])
        XCTAssertEqual(FrameCheck(text: "frame=\ngrid.tray=a\n\ntext=a\ntitle=A\n").partFaults, ["the root draws grid.tray, which is not a place"])
    }

    func testACardDrawingThatNamesNoComponentIsAFault() {
        XCTAssertEqual(FrameCheck(text: "frame=\ngrid.wide=a b\n\ntext=a\ntitle=A\n").partFaults, ["the card drawing names b, which no component has"])
    }

    func testAChangeOnTheCardShowsBeforeTheAnswer() {
        let state = SpotState(output: Frame(text: clock), header: SpotState(title: "Clock"))

        XCTAssertEqual(state.setting("true", of: "power").face.parts.last?.control, .toggle(true))
    }

    func testAnAnswerThatDrawsALargeCardIsOneCardWhosePressSendsItsValue() {
        let answer = Frame(text: """
        frame=
        grid.large=answer answer answer answer
        grid.large=answer answer answer answer

        number=answer
        value=1234.5
        display=1,234.5
        """)

        XCTAssertEqual(answer.answers.map(\.run), ["1234.5"])
        XCTAssertEqual(answer.answers.first?.title, "1,234.5")
        XCTAssertEqual(answer.answers.first?.card?.face.answerSize, .large)
        XCTAssertEqual(answer.answers.first?.card?.face.parts.last?.control, .number("1,234.5", unit: nil))
    }

    func testAnAnswerCardTakesTheWordForEnterFromItsOpenButton() {
        let answer = Frame(text: "frame=\ngrid.large=a\n\nnumber=a\nvalue=14\n\nbutton=open\ntitle=Copy\n")

        XCTAssertEqual(answer.answers.first?.openTitle, "Copy")
    }

    func testANumberDrawsItsUnitFaintWhereItShows() {
        let price = Frame(text: "frame=\ngrid.large=a\n\nnumber=a\nvalue=13.46\ndisplay=$13.46\nunit=$\n").parts.first
        let plain = Frame(text: "frame=\ngrid.large=a\n\nnumber=a\nvalue=14\n").parts.first

        XCTAssertEqual(price?.numberPieces.map(\.text), ["$", "13.46"])
        XCTAssertEqual(price?.numberPieces.map(\.isUnit), [true, false])
        XCTAssertEqual(plain?.numberPieces.map(\.text), ["14"])
        XCTAssertEqual(FrameCheck(text: "number=a\nvalue=1\nunit=kg\n").partFaults, [])
    }

    func testAnAnswerWithNoMainValueOrNoFullWidthDrawingIsItsRows() {
        let noMain = Frame(text: "frame=\ngrid.strip=a b\n\nnumber=a\nvalue=1\n\nnumber=b\nvalue=2\n\ntext=r\ntitle=R\n")
        let wide = Frame(text: "frame=\ngrid.wide=a\n\nnumber=a\nvalue=1\n\ntext=r\ntitle=R\n")
        let strip = Frame(text: "frame=\ngrid.strip=a\n\nnumber=a\nvalue=1\n")

        XCTAssertEqual(noMain.answers.map(\.run), ["r"])
        XCTAssertEqual(wide.answers.map(\.run), ["r"])
        XCTAssertEqual(strip.answers.first?.card?.face.answerSize, .strip)
    }

    func testAOneLineDrawingIsAStrip() {
        XCTAssertEqual(CardLayout(drawing: ["a b c"]).size, .strip)
    }

    func testCellsKeepOneGapAndAWiderOneBetweenTheSides() throws {
        let room = CGSize(width: 300, height: 100)
        let hero = CardLayout(drawing: ["a a b b", "a a c c", "a a d d"])
        let rects = hero.slots.map { hero.rect(of: $0, in: room, gap: 8, sideGap: 20) }

        XCTAssertEqual(rects[1].minX - rects[0].maxX, 20, accuracy: 0.001)
        XCTAssertEqual(rects[2].minY - rects[1].maxY, 8, accuracy: 0.001)
        XCTAssertEqual(rects[3].maxY, 100, accuracy: 0.001)
        XCTAssertEqual(rects[3].maxX, 300, accuracy: 0.001)

        let three = CardLayout(drawing: ["a b c"])
        let cells = three.slots.map { three.rect(of: $0, in: room, gap: 8, sideGap: 20) }
        XCTAssertEqual(cells[1].minX - cells[0].maxX, 8, accuracy: 0.001)
        XCTAssertEqual(cells[0].width, cells[2].width, accuracy: 0.001)
        XCTAssertEqual(cells[2].maxX, 300, accuracy: 0.001)
    }

    func testEveryLayoutFillsItsSizeWithNoOverlap() {
        for layout in [["a"], ["a a b b", "a a c c", "a a d d"], ["a a b b"], ["a b c d"]].map({ CardLayout(drawing: $0) }) {
            var cells = Set<[Int]>()
            for slot in layout.slots {
                for row in slot.y0...slot.y1 {
                    for column in slot.x0...slot.x1 {
                        XCTAssertTrue(cells.insert([row, column]).inserted)
                    }
                }
            }
            XCTAssertEqual(cells.count, layout.columns * layout.rows)
        }
    }
}
