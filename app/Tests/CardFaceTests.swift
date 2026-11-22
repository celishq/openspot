import XCTest
@testable import OpenspotCore

final class CardFaceTests: XCTestCase {
    private let clock = """
    frame=
    class=gap-part

    box=top
    class=hidden wide:flex large:flex bar:flex flex-row gap-part

    text=time
    parent=top
    class=bar:flex
    title=14:20

    switch=power
    parent=top
    class=bar:hidden
    title=Alarm
    value=false

    text=date
    class=hidden large:flex
    title=Sunday
    """

    func testACardDrawsOnlyTheNodesThatShowOnItsSize() {
        let face = Frame(text: clock).face

        XCTAssertFalse(face.draws(on: .small))
        XCTAssertTrue(face.draws(on: .wide))
        XCTAssertEqual(face.tree.shown(in: Style.Variant.card(.wide)), ["top", "time", "power"])
        XCTAssertEqual(face.tree.shown(in: Style.Variant.card(.large)), ["top", "time", "power", "date"])
        XCTAssertEqual(face.parts.map(\.id), ["time", "power", "date"])
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

    func testTheOneValueBlockOutsideTheItemsIsTheValueOfTheCard() {
        let outputCheck = FrameCheck(text: "frame=\nclass=gap-part\n\nswitch=power\nvalue=true\n\nitems=list\n\ntext=bar\nparent=list\ntitle=Bar\n")
        let output = outputCheck.output
        XCTAssertEqual(output.value?.value("switch"), "power")
        XCTAssertEqual(outputCheck.partFaults, [])
    }

    func testMainAndAnUnknownPlaceAreFaults() {
        XCTAssertEqual(FrameCheck(text: "frame=\nmain=gone\n\nbutton=go\ntitle=Go\n").partFaults, ["the root has an unknown key: main"])
        XCTAssertEqual(FrameCheck(text: "frame=\ngrid.wide=a\n\ntext=a\ntitle=A\n").partFaults, ["the root has an unknown key: grid.wide"])
        XCTAssertEqual(FrameCheck(text: "frame=\ngrid=a\n\ntext=a\ntitle=A\n").partFaults, ["the root has an unknown key: grid"])
    }

    func testAChangeOnTheCardShowsBeforeTheAnswer() {
        let state = SpotState(output: Frame(text: clock), header: SpotState(title: "Clock"))

        XCTAssertEqual(state.setting("true", of: "power").face.parts.first { $0.id == "power" }?.control, .toggle(true))
    }

    func testAnAnswerThatDrawsALargeCardIsOneCardWhosePressSendsItsValue() {
        let answer = Frame(text: """
        frame=

        number=answer
        class=large:flex
        value=1234.5
        display=1,234.5
        """)

        XCTAssertEqual(answer.answers(asCard: true).map(\.run), ["1234.5"])
        XCTAssertEqual(answer.answers(asCard: true).first?.title, "1,234.5")
        XCTAssertEqual(answer.answers(asCard: true).first?.card?.face.answerSize, .large)
        XCTAssertEqual(answer.answers(asCard: true).first?.card?.face.parts.last?.number?.text, "1,234.5")
    }

    func testAnAnswerCardTakesTheWordForEnterFromItsOpenButton() {
        let answer = Frame(text: "frame=\n\nnumber=a\nclass=large:flex\nvalue=14\n\nbutton=open\ntitle=Copy\nscope=spot\n")

        XCTAssertEqual(answer.answers(asCard: true).first?.openTitle, "Copy")
    }

    func testANumberDrawsItsUnitFaintWhereItShows() {
        let price = Frame(text: "frame=\nclass=gap-part\n\nnumber=a\nvalue=13.46\ndisplay=$13.46\nunit=$\n").parts.first
        let plain = Frame(text: "frame=\nclass=gap-part\n\nnumber=a\nvalue=14\n").parts.first

        XCTAssertEqual(price?.numberPieces.map(\.text), ["$", "13.46"])
        XCTAssertEqual(price?.numberPieces.map(\.isUnit), [true, false])
        XCTAssertEqual(plain?.numberPieces.map(\.text), ["14"])
        XCTAssertEqual(FrameCheck(text: "number=a\nvalue=1\nunit=kg\n").partFaults, [])
    }

    func testAnAnswerWithNoMainValueOrNoFullWidthDrawingIsItsRows() {
        let noMain = Frame(text: "frame=\n\nnumber=a\nclass=strip:flex\nvalue=1\n\nnumber=b\nclass=strip:flex\nvalue=2\n\nitems=list\n\ntext=r\nparent=list\ntitle=R\n")
        let wide = Frame(text: "frame=\n\nnumber=a\nclass=wide:flex\nvalue=1\n\nitems=list\n\ntext=r\nparent=list\ntitle=R\n")
        let strip = Frame(text: "frame=\n\nnumber=a\nclass=strip:flex\nvalue=1\n")

        XCTAssertEqual(noMain.answers(asCard: true).map(\.run), ["r"])
        XCTAssertEqual(wide.answers(asCard: true).map(\.run), ["r"])
        XCTAssertEqual(strip.answers(asCard: true).first?.card?.face.answerSize, .strip)
    }
}
