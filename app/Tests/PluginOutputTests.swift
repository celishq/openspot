import XCTest
@testable import OpenspotCore

final class PluginOutputTests: XCTestCase {
    func testAScriptPrintsWhoSearchesItsRowsAndWhetherRecentPicksMoveUp() {
        let plain = PluginOutput(text: "row=A\nrun=a\n")
        let printed = PluginOutput(text: "search=script\nrecents=false\n\nrow=A\nrun=a\n")

        XCTAssertEqual(plain.search, .local)
        XCTAssertTrue(plain.keepsRecent)
        XCTAssertEqual(printed.search, .script)
        XCTAssertFalse(printed.keepsRecent)
        XCTAssertEqual(printed.errors, [])
    }

    func testSortsBlocksByTheKeyThatSaysWhatTheyAre() {
        let output = PluginOutput(text: """
        title=Caffeinate
        on=true

        action=copy
        title=Copy
        key=cmd+return
        close=true

        row=Safari
        detail=Browser
        run=/Applications/Safari.app
        file=/Applications/Safari.app

        row=Off
        run=off
        symbol=power
        """)

        XCTAssertEqual(output.summary?.value("title"), "Caffeinate")
        XCTAssertEqual(output.items, [
            SpotItem(title: "Safari", subtitle: "Browser", run: "/Applications/Safari.app", file: "/Applications/Safari.app"),
            SpotItem(title: "Off", run: "off", symbol: "power")
        ])
        XCTAssertEqual(output.actions, [CommandAction(id: "copy", title: "Copy", key: ActionKey(text: "cmd+return"), after: .close)])
        XCTAssertEqual(output.errors, [])
    }

    func testReadsEachKeyOfAnAction() {
        let output = PluginOutput(text: """
        action=new
        title=New
        key=cmd+n
        scope=command
        form=true

        action=delete
        title=Delete
        close=true
        confirm=Delete this?
        """)

        XCTAssertEqual(output.actions, [
            CommandAction(id: "new", title: "New", key: ActionKey(text: "cmd+n"), scope: .command, isForm: true),
            CommandAction(id: "delete", title: "Delete", after: .close, confirm: "Delete this?")
        ])
    }

    func testAnActionItCannotReadIsReportedByItsFirstLine() {
        XCTAssertEqual(PluginOutput(text: "action=a\n").errors, ["action=a"])
        XCTAssertEqual(PluginOutput(text: "action=b\ntitle=B\nkey=ctrl+b\n").errors, ["action=b"])
        XCTAssertEqual(PluginOutput(text: "action=c\ntitle=C\nscope=world\n").errors, ["action=c"])
    }

    func testTheOpenActionSetsTheWordForEnterAndThePick() {
        let copy = PluginOutput(text: "action=open\ntitle=Copy\nclose=false\n")

        XCTAssertEqual(copy.actions, [])
        XCTAssertEqual(copy.primary, "Copy")
        XCTAssertEqual(copy.pick, .stay)
        XCTAssertEqual(PluginOutput(text: "").pick, .close)
    }

    func testReportsARowWithNoRunAndABlockThatSaysNothing() {
        let output = PluginOutput(text: "row=Lost\ndetail=x\n\nnot an item\n\nrow=Kept\nrun=1\n")

        XCTAssertEqual(output.errors, ["row=Lost", "not an item"])
        XCTAssertEqual(output.items.map(\.title), ["Kept"])
    }

    func testASecondBlockOfTheSpotIsReported() {
        XCTAssertEqual(PluginOutput(text: "title=One\n\ntitle=Two\n").errors, ["title=Two"])
    }

    func testKeepsTheFirstItemOfEachRunValue() {
        XCTAssertEqual(PluginOutput(text: "row=One\nrun=same\n\nrow=Two\nrun=same\n").items.map(\.title), ["One"])
    }

    func testNoOutputIsNothing() {
        XCTAssertEqual(PluginOutput(text: ""), PluginOutput(text: "\n\n"))
        XCTAssertNil(PluginOutput(text: "").summary)
    }

    func testWhatItPrintsDecidesTheKindOfSpot() {
        XCTAssertEqual(PluginOutput(text: "").kind, .launch)
        XCTAssertEqual(PluginOutput(text: "title=Hi\n").kind, .launch)
        XCTAssertEqual(PluginOutput(text: "on=true\n").kind, .toggle)
        XCTAssertEqual(PluginOutput(text: "level=7\n").kind, .slider)
        XCTAssertEqual(PluginOutput(text: "on=true\n\nrow=A\nrun=a\n").kind, .list)
        XCTAssertEqual(PluginOutput(text: "action=new\ntitle=New\n").kind, .list)
    }

    func testWhatItPrintsDecidesTheKindOfMetric() throws {
        func kind(_ text: String) throws -> MetricKind {
            try XCTUnwrap(MetricValue(output: PluginOutput(text: text))).kind
        }

        XCTAssertEqual(try kind("title=3\n"), .value)
        XCTAssertEqual(try kind("title=3\nsymbol=star\ntone=good\n"), .value)
        XCTAssertEqual(try kind("title=Up\ntone=good\n"), .status)
        XCTAssertEqual(try kind("title=84%\nvalue=0.84\n"), .gauge)
        XCTAssertEqual(try kind("title=2\npoint=1\npoint=2\n"), .trend)
        XCTAssertEqual(try kind("row=Build\n"), .rows)
    }

    func testRowsCountThemselvesUnlessATitleIsPrinted() throws {
        let rows = "row=One\ndetail=2m\ntone=bad\n\nrow=Two\n"

        let counted = try XCTUnwrap(MetricValue(output: PluginOutput(text: rows)))
        let titled = try XCTUnwrap(MetricValue(output: PluginOutput(text: "title=Many\n\n" + rows)))

        XCTAssertEqual(counted.title, "2")
        XCTAssertEqual(counted.rows, [.init(title: "One", detail: "2m", tone: .bad), .init(title: "Two")])
        XCTAssertEqual(titled.title, "Many")
    }

    func testAMetricCanSetATintAndAnUnknownOneIsSkipped() {
        XCTAssertEqual(MetricValue(output: PluginOutput(text: "title=1\ntint=green\n"))?.tint, .green)
        XCTAssertNil(MetricValue(output: PluginOutput(text: "title=1\ntint=beige\n"))?.tint)
    }

    func testPrintingNothingHidesAMetric() {
        XCTAssertEqual(MetricValue(output: PluginOutput(text: ""))?.isHidden, true)
        XCTAssertEqual(MetricValue(output: PluginOutput(text: "action=copy\ntitle=Copy\n"))?.isHidden, true)
    }

    func testAReadingOfRowsCountsZeroWhenThereIsNothingToShow() throws {
        var reading = MetricReading(label: "Agents")
        reading.take(try XCTUnwrap(MetricValue(output: PluginOutput(text: "row=One\n"))))
        reading.take(try XCTUnwrap(MetricValue(output: PluginOutput(text: ""))))

        XCTAssertEqual(reading.kind, .rows)
        XCTAssertEqual(reading.value?.title, "0")
        XCTAssertNil(TrayMark(reading: reading))
    }

    func testAPrintedSymbolBeatsTheHeader() {
        XCTAssertEqual(MetricReading(label: "A", headerSymbol: "star").symbol, "star")
        XCTAssertEqual(MetricReading(label: "A", headerSymbol: "star", value: MetricValue(title: "1", symbol: "moon")).symbol, "moon")
    }

    func testAFormHasOneBlockForEachField() {
        let form = ItemForm(output: PluginOutput(text: """
        title=New

        field=text
        label=Text
        type=multiline
        value=one\\ntwo
        required=true
        placeholder=Say it

        field=name
        label=Name
        """))

        XCTAssertEqual(form, ItemForm(title: "New", fields: [
            .init(name: "text", label: "Text", type: .multiline, value: "one\ntwo", required: true, placeholder: "Say it"),
            .init(name: "name", label: "Name")
        ]))
    }

    func testAFormNeedsATitleAndALabelForEachField() {
        XCTAssertNil(ItemForm(output: PluginOutput(text: "field=a\nlabel=A\n")))
        XCTAssertNil(ItemForm(output: PluginOutput(text: "title=New\n\nfield=a\n")))
    }
}
