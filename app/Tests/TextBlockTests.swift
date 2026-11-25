import XCTest
@testable import OpenspotCore

final class TextBlockTests: XCTestCase {
    func testPatchingALongListReadsTheIdOfEachBlockAFewTimes() {
        let blocks = (0..<2000).map { TextBlock(fields: [.init(key: "item", value: "r\($0)")]) } + [TextBlock(fields: [.init(key: "item", value: "r7"), .init(key: "title", value: "Seven")])]
        var reads = 0

        let merged = TextBlock.patching([], with: blocks) { block in
            reads += 1
            return block.value("item")
        }

        XCTAssertEqual(merged.count, 2000)
        XCTAssertEqual(merged[7].value("title"), "Seven")
        XCTAssertLessThan(reads, 3 * blocks.count)
    }

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
        let output = Frame(text: """
        frame=
        class=gap-part

        text=m
        title=6 open
        detail=Today
        icon=star
        tone=warn

        items=list

        item=Fix "tray"
        parent=list
        detail=failing
        tone=bad

        item=Docs
        parent=list
        """)

        XCTAssertEqual(MetricValue(output: output), MetricValue(
            title: "6 open",
            detail: "Today",
            symbol: "star",
            tone: .warn,
            rows: [.init(title: "Fix \"tray\"", detail: "failing", tone: .bad), .init(title: "Docs")]
        ))
    }

    func testAMetricSkipsABadToneAndNeedsATitle() {
        XCTAssertNil(MetricValue(output: Frame(text: "text=m\ndetail=Only")))
        XCTAssertEqual(MetricValue(output: Frame(text: "text=m\ntitle=A\ntone=purple\nfuture=key")), MetricValue(title: "A"))
    }

    func testAnItemNeedsAnIdAndTakesItAsItsTitleWhenItHasNone() {
        XCTAssertEqual(Frame(text: "item=").items, [])
        XCTAssertEqual(Frame(text: "item=😀").items.first?.title, "😀")
        XCTAssertEqual(
            Frame(text: "item=a\ntitle=A\ndetail=B\nicon=/f\nhides=x\nhides=y").items,
            [SpotItem(title: "A", subtitle: "B", run: "a", picture: .file("/f"), hides: ["x", "y"])]
        )
    }

    func testASeriesItemDrawsABarForEachPointUpToItsMaxWithAGapForADash() throws {
        let bars = try XCTUnwrap(Frame(text: "items=list\n\nbox=used\nparent=list\ntitle=Used\n\nseries=a\nparent=used\nvalue=2,-,4").items.first)
        let capped = try XCTUnwrap(Frame(text: "series=a\nvalue=2,4\nmax=8").items.first)
        let check = try XCTUnwrap(Frame(text: "item=a\nvalue=true").items.first)

        XCTAssertEqual(bars.number?.scaledPoints, [0.5, nil, 1])
        XCTAssertEqual(bars.number?.text, "4")
        XCTAssertEqual(bars.section, "Used")
        XCTAssertFalse(bars.isOn)
        XCTAssertEqual(capped.number?.scaledPoints, [0.25, 0.5])
        XCTAssertNil(check.number)
        XCTAssertEqual(Frame(text: "series=a\nvalue=nan,2").items.first?.number?.scaledPoints, [nil, 1])
        XCTAssertTrue(check.isOn)
    }

    func testAListTitlesTheFirstRowOfEachSectionUntilASearch() {
        let items = ["a Used", "b Used", "c Failing", "d"].map { word in
            let parts = word.split(separator: " ").map(String.init)
            return SpotItem(title: parts[0], run: parts[0], section: parts.count > 1 ? parts[1] : nil)
        }
        var list = ItemList(items: items)

        XCTAssertEqual(list.sectionStarts, ["a": "Used", "c": "Failing"])
        XCTAssertEqual(list.lineCount, list.shown.count + 2)
        XCTAssertEqual(list.run(at: 0), "a")
        XCTAssertNil(list.run(at: list.shown.count))
        _ = list.search("b")
        XCTAssertEqual(list.sectionStarts, [:])
        XCTAssertEqual(list.lineCount, list.shown.count)
    }

    func testAnItemShowsItsPathAsItsSpotThenItsPlace() {
        let spot = Spot(id: "s", name: "System Settings", url: URL(fileURLWithPath: "/settings.sh"))
        let volume = Frame(text: "item=v\ntitle=Volume\ndetail=Loud\nplace=Sound").items.first

        XCTAssertEqual(volume?.place, "Sound")
        XCTAssertEqual(volume?.path(in: spot), "System Settings › Sound")
        XCTAssertEqual(SpotItem(title: "Sound", subtitle: "Loud", run: "s").path(in: spot), "System Settings")
    }
}
