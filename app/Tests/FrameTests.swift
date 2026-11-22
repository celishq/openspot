import XCTest
@testable import OpenspotCore

final class FrameTests: XCTestCase {
    func testAScriptPrintsWhetherRecentPicksMoveUp() {
        let plain = Frame(text: "text=a\ntitle=A\n")
        let printed = Frame(text: "frame=\nrecents=false\n\ntext=a\ntitle=A\n")

        XCTAssertTrue(plain.keepsRecent)
        XCTAssertFalse(printed.keepsRecent)
        XCTAssertEqual(printed.errors, [])
    }

    func testSortsBlocksByTheKeyThatSaysWhatTheyAre() {
        let output = Frame(text: """
        frame=
        title=Caffeinate

        button=copy
        title=Copy
        shortcut=cmd+return
        close=true

        text=/Applications/Safari.app
        title=Safari
        detail=Browser
        icon=/Applications/Safari.app

        text=off
        title=Off
        icon=power
        """)

        XCTAssertEqual(output.root?.value("title"), "Caffeinate")
        XCTAssertEqual(output.items, [
            SpotItem(title: "Safari", subtitle: "Browser", run: "/Applications/Safari.app", picture: .file("/Applications/Safari.app")),
            SpotItem(title: "Off", run: "off", picture: .symbol("power"))
        ])
        XCTAssertEqual(output.actions, [CommandAction(id: "copy", title: "Copy", key: ActionKey(text: "cmd+return"), after: .close)])
        XCTAssertEqual(output.errors, [])
    }

    func testTheFirstKeyOfABlockNamesItsKind() {
        let output = Frame(text: "frame=\ntitle=Places\n\ndetail=Late\ntext=kyiv\ntitle=Kyiv\n\ntext=lviv\ntitle=Lviv\n")

        XCTAssertEqual(output.items.map(\.run), ["lviv"])
        XCTAssertEqual(output.errors, ["detail=Late"])
    }

    func testABlockOfAnUnknownKindBeforeTheRootIsSkippedAndReported() {
        let output = Frame(text: "badge=new\ntitle=New\n\nframe=\ntitle=Mine\n\ntext=a\ntitle=A\n")
        let alone = Frame(text: "badge=new\ntitle=New\n")

        XCTAssertEqual(output.root?.value("title"), "Mine")
        XCTAssertEqual(output.items.map(\.run), ["a"])
        XCTAssertTrue(output.isPicture)
        XCTAssertEqual(output.errors, ["badge=new"])
        XCTAssertNil(alone.root)
        XCTAssertFalse(alone.isPicture)
        XCTAssertEqual(alone.errors, ["badge=new"])
    }

    func testABlockThatStartsWithAKeyOfTheRootButNotFrameIsAnUnknownKind() {
        let output = Frame(text: "title=Mine\nclass=gap-part\n\ntoast=Saved\n\ntext=a\ntitle=A\n")

        XCTAssertNil(output.root)
        XCTAssertNil(output.perLine)
        XCTAssertEqual(output.items.map(\.run), ["a"])
        XCTAssertEqual(output.errors, ["title=Mine", "toast=Saved"])
    }

    func testTheRootIsTheBlockThatStartsWithFrameAtAnyPlaceAndItsRouteMayBeEmpty() {
        let first = Frame(text: "frame=\ntitle=Mine\nrecents=false\n\ntext=a\ntitle=A\n")
        let after = Frame(text: "text=a\ntitle=A\n\nframe=photo/12\nrecents=false\n")

        XCTAssertEqual(first.root?.value("title"), "Mine")
        XCTAssertFalse(first.keepsRecent)
        XCTAssertFalse(after.keepsRecent)
        XCTAssertEqual(after.items.map(\.run), ["a"])
        XCTAssertEqual(first.errors + after.errors, [])
    }

    func testReadsEachKeyOfAnAction() {
        let output = Frame(text: """
        button=new
        title=New
        shortcut=cmd+n
        scope=spot
        form=true

        button=delete
        title=Delete
        confirm=Delete this?
        """)

        XCTAssertEqual(output.actions, [
            CommandAction(id: "new", title: "New", key: ActionKey(text: "cmd+n"), scope: .spot, after: .close, isForm: true),
            CommandAction(id: "delete", title: "Delete", after: .close, confirm: "Delete this?")
        ])
    }

    func testAnActionWithAnUnknownScopeIsAFaultThatNamesTheScopes() {
        let unknownCheck = FrameCheck(text: "button=c\ntitle=C\nscope=world\n")
        let unknown = unknownCheck.output

        XCTAssertEqual(unknownCheck.partFaults, ["the button c has an unknown scope: world. Use item or spot"])
        XCTAssertEqual(unknown.errors, [])
    }

    func testTheOpenActionSetsTheWordForEnterAndThePick() {
        let copy = Frame(text: "button=open\ntitle=Copy\nclose=false\n")

        XCTAssertEqual(copy.actions, [])
        XCTAssertEqual(copy.openTitle, "Copy")
        XCTAssertEqual(copy.pick, .stay)
        XCTAssertEqual(Frame(text: "").pick, .close)
    }

    func testAFormOnTheOpenActionAsksBeforeEachPick() {
        XCTAssertEqual(
            Frame(text: "button=open\ntitle=Open in Zed\nform=true\n").pickForm,
            CommandAction(id: "open", title: "Open in Zed", after: .close, isForm: true)
        )
        XCTAssertEqual(
            Frame(text: "button=open\nform=true\nclose=false\n").pickForm,
            CommandAction(id: "open", title: "Open", after: .stay, isForm: true)
        )
        XCTAssertNil(Frame(text: "button=open\ntitle=Copy\n").pickForm)
    }

    func testReportsARowWithNoIdAndABlockThatSaysNothing() {
        let output = Frame(text: "text=\ndetail=x\n\nnot an item\n\ntext=1\ntitle=Kept\n")

        XCTAssertEqual(output.errors, ["text=", "not an item"])
        XCTAssertEqual(output.items.map(\.title), ["Kept"])
    }

    func testASecondBlockOfTheSpotIsReported() {
        XCTAssertEqual(Frame(text: "frame=\ntitle=One\n\nframe=\ntitle=Two\n").errors, ["frame="])
    }

    func testALaterItemWithTheIdOfAnEarlierOnePatchesIt() {
        let items = Frame(text: "text=same\ntitle=One\ndetail=First\n\ntext=other\n\ntext=same\ntitle=Two\n").items

        XCTAssertEqual(items.map(\.title), ["Two", "other"])
        XCTAssertEqual(items.first?.subtitle, "First")
    }

    func testNoOutputIsNothing() {
        XCTAssertEqual(Frame(text: ""), Frame(text: "\n\n"))
        XCTAssertNil(Frame(text: "").root)
    }

    func testWhatItPrintsDecidesTheKindOfSpot() {
        XCTAssertEqual(Frame(text: "").kind, .list)
        XCTAssertEqual(Frame(text: "frame=\ntitle=Hi\n").kind, .list)
        XCTAssertEqual(Frame(text: "switch=power\nvalue=true\n").kind, .toggle)
        XCTAssertEqual(Frame(text: "field=volume\ntype=slider\nvalue=7\n").kind, .slider)
        XCTAssertEqual(Frame(text: "switch=power\nvalue=true\n\ntext=a\ntitle=A\n").kind, .list)
        XCTAssertEqual(Frame(text: "button=new\ntitle=New\n").kind, .list)
    }

    func testWhatItPrintsDecidesTheKindOfMetric() throws {
        func kind(_ text: String) throws -> MetricKind {
            try XCTUnwrap(MetricValue(output: Frame(text: text))).kind
        }

        XCTAssertEqual(try kind("text=m\ntitle=3\n"), .value)
        XCTAssertEqual(try kind("text=m\ntitle=3\nicon=star\ntone=good\n"), .value)
        XCTAssertEqual(try kind("text=m\ntitle=Up\ntone=good\n"), .status)
        XCTAssertEqual(try kind("number=m\nvalue=84\nmax=100\nunit=%\n"), .gauge)
        XCTAssertEqual(try kind("number=m\nvalue=1\nvalue=2\n"), .trend)
        XCTAssertEqual(try kind("text=Build\n\ntext=Test\n"), .rows)
    }

    func testANumberReadsItsBarsFromValueLines() throws {
        let value = try XCTUnwrap(MetricValue(output: Frame(text: "number=m\nmax=10\nvalue=1\nvalue=2\n")))

        XCTAssertEqual(value.kind, .trend)
        XCTAssertEqual(value.number?.points, [1, 2])
        XCTAssertNil(value.number?.fill)
    }

    func testRowsCountThemselvesUnlessATitleIsPrinted() throws {
        let rows = "text=One\ndetail=2m\ntone=bad\n\ntext=Two\n"

        let counted = try XCTUnwrap(MetricValue(output: Frame(text: rows)))
        let titled = try XCTUnwrap(MetricValue(output: Frame(text: "frame=\nclass=gap-part\n\ntext=m\ntitle=Many\n\nitems=list\n\ntext=One\nparent=list\n\ntext=Two\nparent=list\n")))

        XCTAssertEqual(counted.title, "2")
        XCTAssertEqual(counted.rows, [.init(title: "One", detail: "2m", tone: .bad), .init(title: "Two")])
        XCTAssertEqual(titled.title, "Many")
    }

    func testATintIsAnUnknownKey() {
        XCTAssertEqual(FrameCheck(text: "frame=\nclass=gap-part\n\ntext=m\ntitle=1\ntint=green\n").partFaults, ["the part m has an unknown key: tint"])
    }

    func testPrintingNothingHidesAMetric() {
        XCTAssertEqual(MetricValue(output: Frame(text: ""))?.isHidden, true)
        XCTAssertEqual(MetricValue(output: Frame(text: "button=copy\ntitle=Copy\n"))?.isHidden, true)
    }

    func testAReadingOfRowsCountsZeroWhenThereIsNothingToShow() throws {
        var reading = MetricReading(label: "Agents")
        reading.take(try XCTUnwrap(MetricValue(output: Frame(text: "text=One\n\ntext=Two\n"))))
        reading.take(try XCTUnwrap(MetricValue(output: Frame(text: ""))))

        XCTAssertEqual(reading.kind, .rows)
        XCTAssertEqual(reading.value?.title, "0")
        XCTAssertNil(MenuBarMark(reading: reading))
    }

    func testAPrintedSymbolBeatsTheHeader() {
        XCTAssertEqual(MetricReading(label: "A", headerSymbol: "star").symbol, "star")
        XCTAssertEqual(MetricReading(label: "A", headerSymbol: "star", value: MetricValue(title: "1", symbol: "moon")).symbol, "moon")
    }

    func testAFormHasOneBlockForEachField() {
        let form = ItemForm(output: Frame(text: """
        frame=
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
        XCTAssertNil(ItemForm(output: Frame(text: "field=a\ntitle=A\n")))
        XCTAssertNil(ItemForm(output: Frame(text: "frame=\ntitle=New\n\nfield=a\n")))
    }

    func testARowReadsEachKeyword() {
        let output = Frame(text: "text=😀\ntitle=grinning face\nkeywords=happy, big smile,,\n")

        XCTAssertEqual(output.items.first?.keywords, ["happy", "big smile"])
    }

    func testCardAndPadLinesDrawNothing() throws {
        let output = Frame(text: "frame=\nclass=gap-part\ncard=a\npad=7 8 9\n\ntext=a\ntitle=A\n")

        XCTAssertEqual(output.parts.map(\.id), ["a"])
        XCTAssertEqual(output.tree.children, ["a"])
    }

    func testABlockThatNamesAKindOfTheAppItselfIsUnreadable() {
        let outputCheck = FrameCheck(text: "gauge=g\nvalue=1\n\nslider=s\nvalue=4\n\nhotkey=k\nvalue=ctrl+k\n")
        let output = outputCheck.output

        XCTAssertEqual(output.parts, [])
        XCTAssertEqual(outputCheck.sheetFaults.filter { $0.hasPrefix("cannot read the block") }, [
            "cannot read the block that starts: gauge=g",
            "cannot read the block that starts: slider=s",
            "cannot read the block that starts: hotkey=k"
        ])
    }

    func testARowDrawsItsOwnKeys() throws {
        let output = Frame(text: "text=r\ntitle=R\nas=big\nname=Big\n")

        let row = try XCTUnwrap(output.items.first)
        XCTAssertEqual(row, SpotItem(title: "R", run: "r", fields: [.init(key: "text", value: "r"), .init(key: "title", value: "R"), .init(key: "as", value: "big"), .init(key: "name", value: "Big")]))
    }

    func testANumberWithAMaxFillsAFieldTypeIsItsInputAndAnOldKindIsReported() throws {
        let output = Frame(text: "frame=\nclass=gap-part\n\nnumber=g\nvalue=50\nmax=100\n\nfield=s\ntype=slider\nvalue=40\n\nfield=k\ntype=hotkey\nvalue=ctrl+k\n\nswitch=t\ntype=tick\n\nswitch=w\nlook=tick\n\ngauge=old\nvalue=1\n")

        XCTAssertEqual(try XCTUnwrap(output.parts.first?.number).fill, 0.5)
        XCTAssertEqual(output.parts.dropFirst().map(\.control), [.slider(level: 40, min: 0, max: 100), .shortcut("ctrl+k"), .toggle(false), .toggle(false)])
        XCTAssertEqual(output.parts.map(\.isTick), [false, false, false, true, false])
        XCTAssertEqual(output.errors, ["gauge=old"])
    }

    func testASwitchItemIsAToggleThatShowsWhetherItIsOn() {
        let items = Frame(text: "switch=on\nvalue=true\n\nswitch=off\nvalue=false\n\ntext=picked\nvalue=true\n\ntext=plain\n").items

        XCTAssertEqual(items.map(\.isToggle), [true, true, false, false])
        XCTAssertEqual(items.map(\.isOn), [true, false, true, false])
    }
}
