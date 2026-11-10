import XCTest
@testable import OpenspotCore

final class PluginOutputTests: XCTestCase {
    func testAScriptPrintsWhoSearchesItsRowsAndWhetherRecentPicksMoveUp() {
        let plain = PluginOutput(text: "row=a\ntitle=A\n")
        let printed = PluginOutput(text: "search=script\nrecents=false\n\nrow=a\ntitle=A\n")

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

        button=copy
        title=Copy
        shortcut=cmd+return
        close=true

        row=/Applications/Safari.app
        title=Safari
        detail=Browser
        icon=/Applications/Safari.app

        row=off
        title=Off
        icon=power
        """)

        XCTAssertEqual(output.summary?.value("title"), "Caffeinate")
        XCTAssertEqual(output.items, [
            SpotItem(title: "Safari", subtitle: "Browser", run: "/Applications/Safari.app", iconFile: "/Applications/Safari.app"),
            SpotItem(title: "Off", run: "off", symbol: "power")
        ])
        XCTAssertEqual(output.actions, [CommandAction(id: "copy", title: "Copy", key: ActionKey(text: "cmd+return"), after: .close)])
        XCTAssertEqual(output.errors, [])
    }

    func testTheFirstKeyOfABlockNamesItsKind() {
        let output = PluginOutput(text: "title=Places\n\ndetail=Late\nrow=kyiv\ntitle=Kyiv\n\nrow=lviv\ntitle=Lviv\n")

        XCTAssertEqual(output.items.map(\.run), ["lviv"])
        XCTAssertEqual(output.errors, ["detail=Late"])
    }

    func testAnEffectIsAKeyOfTheOneHeadAtAnyPlace() {
        let head = PluginOutput(text: "toast=Saved\nlink=https://example.com\n")
        let after = PluginOutput(text: "row=a\ntitle=A\n\ntoast=Saved\nlink=https://example.com\n")
        let second = PluginOutput(text: "toast=Saved\n\nlink=https://example.com\n")

        XCTAssertEqual(head.toast, "Saved")
        XCTAssertEqual(head.link, "https://example.com")
        XCTAssertEqual(after.toast, "Saved")
        XCTAssertEqual(after.link, "https://example.com")
        XCTAssertEqual(after.items.map(\.run), ["a"])
        XCTAssertEqual(after.errors, [])
        XCTAssertNil(second.link)
        XCTAssertEqual(second.errors, ["link=https://example.com"])
    }

    func testReadsEachKeyOfAnAction() {
        let output = PluginOutput(text: """
        button=new
        title=New
        shortcut=cmd+n
        scope=command
        form=true

        button=delete
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
        XCTAssertEqual(PluginOutput(text: "button=a\n").errors, ["button=a"])
        XCTAssertEqual(PluginOutput(text: "button=b\ntitle=B\nshortcut=ctrl+b\n").errors, ["button=b"])
        XCTAssertEqual(PluginOutput(text: "button=c\ntitle=C\nscope=world\n").errors, ["button=c"])
    }

    func testTheOpenActionSetsTheWordForEnterAndThePick() {
        let copy = PluginOutput(text: "button=open\ntitle=Copy\nclose=false\n")

        XCTAssertEqual(copy.actions, [])
        XCTAssertEqual(copy.primary, "Copy")
        XCTAssertEqual(copy.pick, .stay)
        XCTAssertEqual(PluginOutput(text: "").pick, .close)
    }

    func testAFormOnTheOpenActionAsksBeforeEachPick() {
        XCTAssertEqual(
            PluginOutput(text: "button=open\ntitle=Open in Zed\nform=true\n").pickForm,
            CommandAction(id: "open", title: "Open in Zed", after: .close, isForm: true)
        )
        XCTAssertEqual(
            PluginOutput(text: "button=open\nform=true\nclose=false\n").pickForm,
            CommandAction(id: "open", title: "Open", after: .stay, isForm: true)
        )
        XCTAssertNil(PluginOutput(text: "button=open\ntitle=Copy\n").pickForm)
    }

    func testReportsARowWithNoIdAndABlockThatSaysNothing() {
        let output = PluginOutput(text: "row=\ndetail=x\n\nnot an item\n\nrow=1\ntitle=Kept\n")

        XCTAssertEqual(output.errors, ["row=", "not an item"])
        XCTAssertEqual(output.items.map(\.title), ["Kept"])
    }

    func testASecondBlockOfTheSpotIsReported() {
        XCTAssertEqual(PluginOutput(text: "title=One\n\ntitle=Two\n").errors, ["title=Two"])
    }

    func testKeepsTheFirstItemOfEachRunValue() {
        XCTAssertEqual(PluginOutput(text: "row=same\ntitle=One\n\nrow=same\ntitle=Two\n").items.map(\.title), ["One"])
    }

    func testNoOutputIsNothing() {
        XCTAssertEqual(PluginOutput(text: ""), PluginOutput(text: "\n\n"))
        XCTAssertNil(PluginOutput(text: "").summary)
    }

    func testWhatItPrintsDecidesTheKindOfSpot() {
        XCTAssertEqual(PluginOutput(text: "").kind, .launch)
        XCTAssertEqual(PluginOutput(text: "title=Hi\n").kind, .launch)
        XCTAssertEqual(PluginOutput(text: "switch=power\non=true\n").kind, .toggle)
        XCTAssertEqual(PluginOutput(text: "slider=volume\nlevel=7\n").kind, .slider)
        XCTAssertEqual(PluginOutput(text: "switch=power\non=true\n\nrow=a\ntitle=A\n").kind, .list)
        XCTAssertEqual(PluginOutput(text: "button=new\ntitle=New\n").kind, .list)
    }

    func testWhatItPrintsDecidesTheKindOfMetric() throws {
        func kind(_ text: String) throws -> MetricKind {
            try XCTUnwrap(MetricValue(output: PluginOutput(text: text))).kind
        }

        XCTAssertEqual(try kind("text=m\ntitle=3\n"), .value)
        XCTAssertEqual(try kind("text=m\ntitle=3\nicon=star\ntone=good\n"), .value)
        XCTAssertEqual(try kind("text=m\ntitle=Up\ntone=good\n"), .status)
        XCTAssertEqual(try kind("gauge=m\ntitle=84%\nvalue=0.84\n"), .gauge)
        XCTAssertEqual(try kind("graph=m\ntitle=2\npoint=1\npoint=2\n"), .trend)
        XCTAssertEqual(try kind("row=Build\n"), .rows)
    }

    func testRowsCountThemselvesUnlessATitleIsPrinted() throws {
        let rows = "row=One\ndetail=2m\ntone=bad\n\nrow=Two\n"

        let counted = try XCTUnwrap(MetricValue(output: PluginOutput(text: rows)))
        let titled = try XCTUnwrap(MetricValue(output: PluginOutput(text: "text=m\ntitle=Many\n\n" + rows)))

        XCTAssertEqual(counted.title, "2")
        XCTAssertEqual(counted.rows, [.init(title: "One", detail: "2m", tone: .bad), .init(title: "Two")])
        XCTAssertEqual(titled.title, "Many")
    }

    func testAMetricCanSetATintAndAnUnknownOneIsSkipped() {
        XCTAssertEqual(MetricValue(output: PluginOutput(text: "text=m\ntitle=1\ntint=green\n"))?.tint, .green)
        XCTAssertNil(MetricValue(output: PluginOutput(text: "text=m\ntitle=1\ntint=beige\n"))?.tint)
    }

    func testPrintingNothingHidesAMetric() {
        XCTAssertEqual(MetricValue(output: PluginOutput(text: ""))?.isHidden, true)
        XCTAssertEqual(MetricValue(output: PluginOutput(text: "button=copy\ntitle=Copy\n"))?.isHidden, true)
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
        title=Text
        type=multiline
        value=one\\ntwo
        required=true
        placeholder=Say it

        field=name
        title=Name
        """))

        XCTAssertEqual(form, ItemForm(title: "New", fields: [
            .init(name: "text", label: "Text", type: .multiline, value: "one\ntwo", required: true, placeholder: "Say it"),
            .init(name: "name", label: "Name")
        ]))
    }

    func testAFormNeedsATitleAndALabelForEachField() {
        XCTAssertNil(ItemForm(output: PluginOutput(text: "field=a\ntitle=A\n")))
        XCTAssertNil(ItemForm(output: PluginOutput(text: "title=New\n\nfield=a\n")))
    }

    func testARowReadsEachKeyword() {
        let output = PluginOutput(text: "row=😀\ntitle=grinning face\nkeyword=happy\nkeyword=smile\n")

        XCTAssertEqual(output.items.first?.keywords, ["happy", "smile"])
    }
}
