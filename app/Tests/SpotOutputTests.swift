import XCTest
@testable import OpenspotCore

final class SpotOutputTests: XCTestCase {
    func testAKeptOutputHoldsItsRowsOnlyAsItemsAndKeepsAllElseItShows() {
        let output = SpotOutput(text: "title=T\ntoast=Hi\n\nrow=a\ntitle=A\n\nrow=b\ntitle=B\n\ntext=m\ntitle=3\n\nbutton=go\ntitle=Go\n")

        let kept = output.withoutBlocks()

        XCTAssertTrue(kept.rows.isEmpty)
        XCTAssertEqual(kept.items, output.items)
        XCTAssertEqual(kept.parts, output.parts)
        XCTAssertEqual(kept.actions, output.actions)
        XCTAssertEqual(kept.summary, output.summary)
        XCTAssertEqual(kept.value, output.value)
        XCTAssertEqual(kept.kind, output.kind)
        XCTAssertEqual(kept.toast, "Hi")
    }

    func testAScriptPrintsWhetherRecentPicksMoveUp() {
        let plain = SpotOutput(text: "row=a\ntitle=A\n")
        let printed = SpotOutput(text: "recents=false\n\nrow=a\ntitle=A\n")

        XCTAssertTrue(plain.keepsRecent)
        XCTAssertFalse(printed.keepsRecent)
        XCTAssertEqual(printed.errors, [])
    }

    func testSortsBlocksByTheKeyThatSaysWhatTheyAre() {
        let output = SpotOutput(text: """
        title=Caffeinate

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
            SpotItem(title: "Safari", subtitle: "Browser", run: "/Applications/Safari.app", picture: .file("/Applications/Safari.app")),
            SpotItem(title: "Off", run: "off", picture: .symbol("power"))
        ])
        XCTAssertEqual(output.actions, [CommandAction(id: "copy", title: "Copy", key: ActionKey(text: "cmd+return"), after: .close)])
        XCTAssertEqual(output.errors, [])
    }

    func testTheFirstKeyOfABlockNamesItsKind() {
        let output = SpotOutput(text: "title=Places\n\ndetail=Late\nrow=kyiv\ntitle=Kyiv\n\nrow=lviv\ntitle=Lviv\n")

        XCTAssertEqual(output.items.map(\.run), ["lviv"])
        XCTAssertEqual(output.errors, ["detail=Late"])
    }

    func testABlockOfAnUnknownKindBeforeTheHeadIsSkippedAndReported() {
        let output = SpotOutput(text: "badge=new\ntitle=New\n\ntitle=Mine\ntoast=Saved\n\ntext=a\ntitle=A\n")
        let alone = SpotOutput(text: "badge=new\ntitle=New\n")

        XCTAssertEqual(output.summary?.value("title"), "Mine")
        XCTAssertEqual(output.toast, "Saved")
        XCTAssertEqual(output.parts.map(\.id), ["a"])
        XCTAssertTrue(output.isPicture)
        XCTAssertEqual(output.errors, ["badge=new"])
        XCTAssertNil(alone.summary)
        XCTAssertFalse(alone.isPicture)
        XCTAssertEqual(alone.errors, ["badge=new"])
    }

    func testAnEffectIsAKeyOfTheOneHeadAtAnyPlace() {
        let head = SpotOutput(text: "toast=Saved\nlink=https://example.com\n")
        let after = SpotOutput(text: "row=a\ntitle=A\n\ntoast=Saved\nlink=https://example.com\n")
        let second = SpotOutput(text: "toast=Saved\n\nlink=https://example.com\n")

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
        let output = SpotOutput(text: """
        button=new
        title=New
        shortcut=cmd+n
        scope=spot
        form=true

        button=delete
        title=Delete
        close=true
        confirm=Delete this?
        """)

        XCTAssertEqual(output.actions, [
            CommandAction(id: "new", title: "New", key: ActionKey(text: "cmd+n"), scope: .spot, isForm: true),
            CommandAction(id: "delete", title: "Delete", after: .close, confirm: "Delete this?")
        ])
    }

    func testAnActionWithAnUnknownScopeIsAFaultThatNamesTheScopes() {
        let old = SpotOutput(text: "button=b\ntitle=B\nscope=command\n")
        let unknown = SpotOutput(text: "button=c\ntitle=C\nscope=world\n")

        XCTAssertEqual(old.actions, [])
        XCTAssertEqual(old.partFaults, ["the button b has scope=command, which Openspot no longer reads. Write scope=spot"])
        XCTAssertEqual(unknown.partFaults, ["the button c has an unknown scope: world. Use item or spot"])
        XCTAssertEqual(unknown.errors, [])
    }

    func testTheOpenActionSetsTheWordForEnterAndThePick() {
        let copy = SpotOutput(text: "button=open\ntitle=Copy\nclose=false\n")

        XCTAssertEqual(copy.actions, [])
        XCTAssertEqual(copy.openTitle, "Copy")
        XCTAssertEqual(copy.pick, .stay)
        XCTAssertEqual(SpotOutput(text: "").pick, .close)
    }

    func testAFormOnTheOpenActionAsksBeforeEachPick() {
        XCTAssertEqual(
            SpotOutput(text: "button=open\ntitle=Open in Zed\nform=true\n").pickForm,
            CommandAction(id: "open", title: "Open in Zed", after: .close, isForm: true)
        )
        XCTAssertEqual(
            SpotOutput(text: "button=open\nform=true\nclose=false\n").pickForm,
            CommandAction(id: "open", title: "Open", after: .stay, isForm: true)
        )
        XCTAssertNil(SpotOutput(text: "button=open\ntitle=Copy\n").pickForm)
    }

    func testReportsARowWithNoIdAndABlockThatSaysNothing() {
        let output = SpotOutput(text: "row=\ndetail=x\n\nnot an item\n\nrow=1\ntitle=Kept\n")

        XCTAssertEqual(output.errors, ["row=", "not an item"])
        XCTAssertEqual(output.items.map(\.title), ["Kept"])
    }

    func testASecondBlockOfTheSpotIsReported() {
        XCTAssertEqual(SpotOutput(text: "title=One\n\ntitle=Two\n").errors, ["title=Two"])
    }

    func testKeepsTheFirstItemOfEachRunValue() {
        XCTAssertEqual(SpotOutput(text: "row=same\ntitle=One\n\nrow=same\ntitle=Two\n").items.map(\.title), ["One"])
    }

    func testNoOutputIsNothing() {
        XCTAssertEqual(SpotOutput(text: ""), SpotOutput(text: "\n\n"))
        XCTAssertNil(SpotOutput(text: "").summary)
    }

    func testWhatItPrintsDecidesTheKindOfSpot() {
        XCTAssertEqual(SpotOutput(text: "").kind, .launch)
        XCTAssertEqual(SpotOutput(text: "title=Hi\n").kind, .launch)
        XCTAssertEqual(SpotOutput(text: "switch=power\nvalue=true\n").kind, .toggle)
        XCTAssertEqual(SpotOutput(text: "field=volume\ntype=slider\nvalue=7\n").kind, .slider)
        XCTAssertEqual(SpotOutput(text: "switch=power\nvalue=true\n\nrow=a\ntitle=A\n").kind, .list)
        XCTAssertEqual(SpotOutput(text: "button=new\ntitle=New\n").kind, .list)
    }

    func testWhatItPrintsDecidesTheKindOfMetric() throws {
        func kind(_ text: String) throws -> MetricKind {
            try XCTUnwrap(MetricValue(output: SpotOutput(text: text))).kind
        }

        XCTAssertEqual(try kind("text=m\ntitle=3\n"), .value)
        XCTAssertEqual(try kind("text=m\ntitle=3\nicon=star\ntone=good\n"), .value)
        XCTAssertEqual(try kind("text=m\ntitle=Up\ntone=good\n"), .status)
        XCTAssertEqual(try kind("graph=m\ntitle=84%\nvalue=0.84\n"), .gauge)
        XCTAssertEqual(try kind("graph=m\ntitle=2\nvalue=1\nvalue=2\n"), .trend)
        XCTAssertEqual(try kind("row=Build\n"), .rows)
    }

    func testAGraphReadsItsBarsFromValueLines() throws {
        let value = try XCTUnwrap(MetricValue(output: SpotOutput(text: "graph=m\ntitle=2\nmax=10\nvalue=1\nvalue=2\n")))

        XCTAssertEqual(value.kind, .trend)
        XCTAssertEqual(value.points, [1, 2])
        XCTAssertNil(value.value)
    }

    func testRowsCountThemselvesUnlessATitleIsPrinted() throws {
        let rows = "row=One\ndetail=2m\ntone=bad\n\nrow=Two\n"

        let counted = try XCTUnwrap(MetricValue(output: SpotOutput(text: rows)))
        let titled = try XCTUnwrap(MetricValue(output: SpotOutput(text: "text=m\ntitle=Many\n\n" + rows)))

        XCTAssertEqual(counted.title, "2")
        XCTAssertEqual(counted.rows, [.init(title: "One", detail: "2m", tone: .bad), .init(title: "Two")])
        XCTAssertEqual(titled.title, "Many")
    }

    func testATintIsAnUnknownKey() {
        XCTAssertEqual(SpotOutput(text: "text=m\ntitle=1\ntint=green\n").partFaults, ["the part m has an unknown key: tint"])
    }

    func testPrintingNothingHidesAMetric() {
        XCTAssertEqual(MetricValue(output: SpotOutput(text: ""))?.isHidden, true)
        XCTAssertEqual(MetricValue(output: SpotOutput(text: "button=copy\ntitle=Copy\n"))?.isHidden, true)
    }

    func testAReadingOfRowsCountsZeroWhenThereIsNothingToShow() throws {
        var reading = MetricReading(label: "Agents")
        reading.take(try XCTUnwrap(MetricValue(output: SpotOutput(text: "row=One\n"))))
        reading.take(try XCTUnwrap(MetricValue(output: SpotOutput(text: ""))))

        XCTAssertEqual(reading.kind, .rows)
        XCTAssertEqual(reading.value?.title, "0")
        XCTAssertNil(MenuBarMark(reading: reading))
    }

    func testAPrintedSymbolBeatsTheHeader() {
        XCTAssertEqual(MetricReading(label: "A", headerSymbol: "star").symbol, "star")
        XCTAssertEqual(MetricReading(label: "A", headerSymbol: "star", value: MetricValue(title: "1", symbol: "moon")).symbol, "moon")
    }

    func testAFormHasOneBlockForEachField() {
        let form = ItemForm(output: SpotOutput(text: """
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
        XCTAssertNil(ItemForm(output: SpotOutput(text: "field=a\ntitle=A\n")))
        XCTAssertNil(ItemForm(output: SpotOutput(text: "title=New\n\nfield=a\n")))
    }

    func testARowReadsEachKeyword() {
        let output = SpotOutput(text: "row=😀\ntitle=grinning face\nkeywords=happy, big smile,,\n")

        XCTAssertEqual(output.items.first?.keywords, ["happy", "big smile"])
    }

    func testAKeywordLineInARowNamesTheList() {
        let output = SpotOutput(text: "row=a\ntitle=A\nkeyword=happy\n")

        XCTAssertEqual(output.retired, ["The row a has keyword=happy, which Openspot no longer reads. Write keywords=a, b."])
    }

    func testATemplateOrASpotBlockIsSkippedAndReportedWhereverItIs() {
        let output = SpotOutput(text: "template=row\ngrid=pic name\npicture=pic\n\nspot=cpu\n\ntitle=Apps\n\nrow=a\ntitle=A\nname=A\n")

        XCTAssertEqual(output.errors, ["template=row", "spot=cpu"])
        XCTAssertEqual(output.summary?.value("title"), "Apps")
        XCTAssertEqual(output.parts.map(\.id), [])
        XCTAssertEqual(output.items.map(\.run), ["a"])
    }

    func testCardAndPadLinesDrawNothingAndACheckReportsThem() throws {
        let output = SpotOutput(text: "grid=a a\ncard=a\npad=7 8 9\n\ntext=a\ntitle=A\n")

        XCTAssertEqual(output.parts.map(\.id), ["a"])
        XCTAssertEqual(output.layout?.rows, [["a", "a"]])
        XCTAssertTrue(output.partFaults.contains("a sheet has no card key, so leave it out: each part draws its own box"), "\(output.partFaults)")
        XCTAssertTrue(output.partFaults.contains("a sheet has no pad key, so print a button for each key"), "\(output.partFaults)")
    }

    func testARowDrawsItsOwnKeysAndACheckReportsAs() throws {
        let output = SpotOutput(text: "row=r\ntitle=R\nas=big\nname=Big\n")

        let row = try XCTUnwrap(output.items.first)
        XCTAssertEqual(row, SpotItem(title: "R", run: "r"))
        XCTAssertTrue(output.partFaults.contains("the row r has as=, which Openspot no longer reads. A row draws its own keys"), "\(output.partFaults)")
    }

    func testAGraphOfOneValueIsAGaugeAFieldTypeIsItsInputAndAnOldKindIsReported() {
        let output = SpotOutput(text: "graph=g\nvalue=0.5\n\nfield=s\ntype=slider\nvalue=40\n\nfield=k\ntype=hotkey\nvalue=ctrl+k\n\nswitch=t\ntype=tick\n\nswitch=w\nlook=tick\n\ngauge=old\nvalue=1\n")

        XCTAssertEqual(output.parts.map(\.control), [.progress(level: 50), .slider(level: 40, min: 0, max: 100), .shortcut("ctrl+k"), .toggle(false), .toggle(false)])
        XCTAssertEqual(output.parts.map(\.look), [nil, nil, nil, .tick, nil])
        XCTAssertEqual(output.errors, ["gauge=old"])
    }

    func testSearchScriptInTheHeadNamesTheEventThatTookItsPlace() {
        let output = SpotOutput(text: "search=script\ngrid=rows\n\nrow=a\ntitle=A\n")

        XCTAssertEqual(output.retired, ["The head has search=script, which Openspot no longer reads. Write on=sheet.text in the header."])
    }

    func testEachOldOutputWordNamesTheWordThatTookItsPlace() {
        let output = SpotOutput(text: "gauge=g\nvalue=1\n\nslider=s\nvalue=4\n\nhotkey=k\nvalue=ctrl+k\n\nswitch=t\nlook=tick\n")

        XCTAssertEqual(output.retired, [
            "gauge=g is now a graph. Write graph=g with one value from 0 to 1.",
            "slider=s is now a field. Write field=s with type=slider.",
            "hotkey=k is now a field. Write field=k with type=hotkey.",
            "The switch t has look=tick, which Openspot no longer reads. Write type=tick."
        ])
        XCTAssertEqual(output.sheetFaults.filter { $0.contains("cannot read the block") }, [])
        XCTAssertTrue(output.sheetFaults.contains("slider=s is now a field. Write field=s with type=slider."))
    }
}
