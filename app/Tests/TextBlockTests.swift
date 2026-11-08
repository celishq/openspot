import XCTest
@testable import OpenspotCore

final class TextBlockTests: XCTestCase {
    func testABlankLineEndsABlock() {
        let blocks = TextBlock.blocks(in: "title=One\n\n\ntitle=Two\n")

        XCTAssertEqual(blocks.map { $0.value("title") }, ["One", "Two"])
    }

    func testALineOfWhiteSpaceEndsABlock() {
        let blocks = TextBlock.blocks(in: "title=One\n \t\u{00A0}\r\ntitle=Two")

        XCTAssertEqual(blocks.map { $0.value("title") }, ["One", "Two"])
    }

    func testABackslashThatEscapesNothingStays() {
        XCTAssertEqual(TextBlock.blocks(in: "a=one\\")[0].value("a"), "one\\")
        XCTAssertEqual(TextBlock.blocks(in: "a=\\")[0].value("a"), "\\")
        XCTAssertEqual(TextBlock.blocks(in: "a=\\t")[0].value("a"), "\\t")
    }

    func testALineKeepsItsCharactersAroundAnEscape() {
        XCTAssertEqual(TextBlock.blocks(in: #"é=ñ\n日本\\語"#)[0].value("é"), "ñ\n日本\\語")
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

    func testANumberAndAFlagSkipABadValue() {
        let block = TextBlock.blocks(in: "a=0.5\nb=wide\nc=nan\nd=true\ne=maybe\nf=false")[0]

        XCTAssertEqual(block.number("a"), 0.5)
        XCTAssertNil(block.number("b"))
        XCTAssertNil(block.number("c"))
        XCTAssertEqual(block.flag("d"), true)
        XCTAssertNil(block.flag("e"))
        XCTAssertEqual(block.flag("f"), false)
    }

    func testAMetricReadsItsKeys() {
        let output = PluginOutput(text: """
        text=m
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
        detail=failing
        tone=bad

        row=Docs
        """)

        XCTAssertEqual(MetricValue(output: output), MetricValue(
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
        XCTAssertNil(MetricValue(output: PluginOutput(text: "text=m\ndetail=Only")))
        XCTAssertEqual(MetricValue(output: PluginOutput(text: "text=m\ntitle=A\ntone=purple\nfuture=key")), MetricValue(title: "A"))
    }

    func testAnItemNeedsARowAndARun() {
        XCTAssertNil(SpotItem(block: TextBlock.blocks(in: "row=Only")[0]))
        XCTAssertNil(SpotItem(block: TextBlock.blocks(in: "run=only")[0]))
        XCTAssertEqual(
            SpotItem(block: TextBlock.blocks(in: "row=A\nrun=a\ndetail=B\nsymbol=s\nfile=/f\nimage=/i\nhides=x\nhides=y")[0]),
            SpotItem(title: "A", subtitle: "B", run: "a", symbol: "s", file: "/f", image: "/i", hides: ["x", "y"])
        )
    }
}
