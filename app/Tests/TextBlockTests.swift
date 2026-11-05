import XCTest
@testable import OpenspotCore

final class TextBlockTests: XCTestCase {
    func testABlankLineEndsABlock() {
        let blocks = TextBlock.blocks(in: "title=One\n\n\ntitle=Two\n")

        XCTAssertEqual(blocks.map { $0.value("title") }, ["One", "Two"])
    }

    func testALineSplitsAtItsFirstEquals() {
        XCTAssertEqual(TextBlock.blocks(in: "run=a=b")[0].value("run"), "a=b")
    }

    func testALineWithNoKeyIsSkipped() {
        let block = TextBlock.blocks(in: "nonsense\n=x\ntitle=Kept")[0]

        XCTAssertEqual(block.fields, [.init(key: "title", value: "Kept")])
    }

    func testAnEmptyValueCountsAsNoValue() {
        XCTAssertNil(TextBlock.blocks(in: "detail=\ntitle=One")[0].value("detail"))
    }

    func testTheEscapesGiveANewLineAndABackslash() {
        XCTAssertEqual(TextBlock.blocks(in: #"text=one\ntwo\\n\t"#)[0].value("text"), "one\ntwo\\n\\t")
    }

    func testACarriageReturnEndsALineToo() {
        XCTAssertEqual(TextBlock.blocks(in: "title=One\r\ndetail=Two\r\n")[0].value("title"), "One")
    }

    func testTheTextKeepsEveryValueExactly() {
        let text = "Say \"héllo\" \\ now\r\n\tthen\n\\n $HOME\n"
        let block = TextBlock(fields: [.init(key: "content", value: text), .init(key: "title", value: "")])

        XCTAssertEqual(TextBlock.blocks(in: block.text)[0].fields.first?.value, text)
        XCTAssertTrue(block.text.hasSuffix("title=\n"))
    }

    func testARepeatedKeyGivesEachValue() {
        XCTAssertEqual(TextBlock.blocks(in: "point=1\ntitle=x\npoint=2")[0].values("point"), ["1", "2"])
    }

    func testAGroupStartsAtItsKeyAndTakesTheLinesAfterIt() {
        let block = TextBlock.blocks(in: """
        row.detail=lost
        row=One
        row.detail=first
        row=Two
        title=Not a row
        row.tone=bad
        """)[0]

        let rows = block.groups("row")

        XCTAssertEqual(rows.map { $0.value("row") }, ["One", "Two"])
        XCTAssertEqual(rows[0].value("detail"), "first")
        XCTAssertEqual(rows[1].value("tone"), "bad")
        XCTAssertNil(rows[1].value("title"))
    }

    func testANumberAndAFlagSkipABadValue() {
        let block = TextBlock.blocks(in: "a=0.5\nb=wide\nc=nan\nd=true\ne=maybe\nf=false")[0]

        XCTAssertEqual(block.number("a"), 0.5)
        XCTAssertNil(block.number("b"))
        XCTAssertNil(block.number("c"))
        XCTAssertEqual(block.flag("d"), true)
        XCTAssertNil(block.flag("e"))
        XCTAssertEqual(block.flag("f"), false)
    }

    func testAMetricReadsEachOfItsKeys() {
        let block = TextBlock.blocks(in: """
        title=6 open
        detail=Today
        symbol=star
        tone=warn
        value=0.5
        point=1
        point=wide
        point=3
        max=9
        row=Fix "tray"
        row.detail=failing
        row.tone=bad
        row=Docs
        """)[0]

        XCTAssertEqual(MetricValue(block: block), MetricValue(
            title: "6 open",
            detail: "Today",
            symbol: "star",
            tone: .warn,
            value: 0.5,
            points: [1, 3],
            max: 9,
            rows: [.init(title: "Fix \"tray\"", detail: "failing", tone: .bad), .init(title: "Docs")]
        ))
    }

    func testAMetricSkipsABadToneAndNeedsATitle() {
        XCTAssertNil(MetricValue(block: TextBlock.blocks(in: "detail=Only")[0]))
        XCTAssertEqual(MetricValue(block: TextBlock.blocks(in: "title=A\ntone=purple\nfuture=key")[0]), MetricValue(title: "A"))
    }

    func testAnItemNeedsATitleAndARun() {
        XCTAssertNil(SpotItem(block: TextBlock.blocks(in: "title=Only")[0]))
        XCTAssertNil(SpotItem(block: TextBlock.blocks(in: "run=only")[0]))
        XCTAssertEqual(
            SpotItem(block: TextBlock.blocks(in: "title=A\nrun=a\nsubtitle=B\nsymbol=s\nfile=/f\nimage=/i\nhides=x\nhides=y")[0]),
            SpotItem(title: "A", subtitle: "B", run: "a", symbol: "s", file: "/f", image: "/i", hides: ["x", "y"])
        )
    }

    func testAFormReadsItsFields() {
        let block = TextBlock.blocks(in: #"""
        title=New
        field=name
        field.label=Name
        field.required=true
        field.placeholder=Weather
        field=text
        field.label=Text
        field.type=multiline
        field.value=one\ntwo
        field=odd
        field.label=Odd
        field.type=dial
        """#)[0]

        XCTAssertEqual(ItemForm(block: block), ItemForm(title: "New", fields: [
            .init(name: "name", label: "Name", required: true, placeholder: "Weather"),
            .init(name: "text", label: "Text", type: .multiline, value: "one\ntwo"),
            .init(name: "odd", label: "Odd")
        ]))
    }

    func testAFormNeedsATitleAndALabelForEachField() {
        XCTAssertNil(ItemForm(block: TextBlock.blocks(in: "field=a\nfield.label=A")[0]))
        XCTAssertNil(ItemForm(block: TextBlock.blocks(in: "title=New\nfield=a")[0]))
    }
}
