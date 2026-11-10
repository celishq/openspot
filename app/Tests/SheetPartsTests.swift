import XCTest
@testable import OpenspotCore

final class SheetPartsTests: XCTestCase {
    private let lights = """
    grid=lights
    grid=left
    grid=brightness
    grid=color
    grid=battery
    grid=reload
    grid=quit

    section=lights
    title=Lights
    on=true

    switch=left
    title=Left
    detail=Connecting…
    on=false

    slider=brightness
    level=80
    max=100
    icon=sun.max

    choice=color
    color=#ff0000
    color=#00ff00
    value=#00ff00

    text=battery
    title=Battery
    detail=68%

    button=reload
    title=Reload
    icon=arrow.clockwise

    button=quit
    title=Quit
    shortcut=cmd+q
    close=true
    """

    private func panel(_ text: String) throws -> SheetParts {
        try XCTUnwrap(SheetParts(output: PluginOutput(text: text)))
    }

    func testAButtonThatOnlyACardDrawingPlacesIsAPartOfTheCardAndNoAction() {
        let output = PluginOutput(text: "grid.strip=next next next join-now\n\nnumber=next\nvalue=09:30\n\nbutton=join-now\ntitle=Join\n\nbutton=tick\ntitle=Mark as done\n")

        XCTAssertEqual(output.parts.map(\.id), ["next", "join-now"])
        XCTAssertEqual(output.actions.map(\.id), ["tick"])
        XCTAssertEqual(output.face.drawing(for: .strip), [["next", "next", "next", "join-now"]])
        XCTAssertEqual(output.partFaults, [])
    }

    func testATextOrANumberTakesAColourForItsBarAndOtherPartsDoNot() {
        let output = PluginOutput(text: "number=next\nvalue=09:30\ncolor=#1BADF8\n\ntext=work\ncolor=#ff9500\n\nnumber=odd\nvalue=1\ncolor=blue\n\ngauge=disk\nvalue=0.5\ncolor=#1BADF8\n")

        XCTAssertEqual(output.parts.map(\.color), ["#1BADF8", "#ff9500", nil, nil])
    }

    func testATextsToneColoursItsWordsAndAGaugeKeepsItsOwn() {
        let output = PluginOutput(text: "text=due\ndetail=Late\ntone=bad\n\ntext=now\ntitle=Standup\ntone=on\n\ngauge=disk\nvalue=0.9\ntone=bad\n")

        XCTAssertEqual(output.parts.map(\.textTone), [.bad, nil, nil])
    }

    func testAScriptThatPrintsPartsIsAList() {
        XCTAssertEqual(PluginOutput(text: lights).kind, .list)
        XCTAssertNil(SheetParts(output: PluginOutput(text: "row=a\ntitle=A\n")))
    }

    func testWhatABlockPrintsDecidesItsControl() throws {
        let parts = try panel(lights).parts

        XCTAssertEqual(parts.map(\.id), ["lights", "left", "brightness", "color", "battery", "reload", "quit"])
        XCTAssertTrue(parts[0].isSection)
        XCTAssertEqual(parts[1].control, .toggle(false))
        XCTAssertEqual(parts[2].control, .slider(level: 80, min: 0, max: 100))
        XCTAssertEqual(parts[3].control, .swatches(["#ff0000", "#00ff00"], value: "#00ff00"))
        XCTAssertEqual(parts[4].control, .none)
        XCTAssertEqual(parts[5].press, .symbol("arrow.clockwise"))
        XCTAssertEqual(parts[6].press, .line)
        XCTAssertTrue(parts[6].closes)
    }

    func testAMenuAndATextAreaReadTheirOptions() throws {
        let parts = try panel("""
        choice=source
        option=auto:Auto
        option=en:English
        value=en

        field=output
        text=one\\ntwo
        placeholder=Translation
        readonly=true
        """).parts

        XCTAssertEqual(parts[0].control, .menu([.init(id: "auto", title: "Auto"), .init(id: "en", title: "English")], value: "en"))
        XCTAssertEqual(parts[1].control, .text("one\ntwo", placeholder: "Translation", isReadOnly: true))
    }

    func testValuesGoToTheScriptAsOneBlock() throws {
        var panel = try panel(lights)
        panel.set("true", of: "left")
        panel.set("20", of: "brightness")

        let block = try XCTUnwrap(TextBlock.blocks(in: panel.values).first)

        XCTAssertNil(block.value("lights"))
        XCTAssertEqual(block.value("left"), "true")
        XCTAssertEqual(block.value("brightness"), "20")
        XCTAssertEqual(block.value("color"), "#00ff00")
        XCTAssertNil(block.value("battery"))
    }

    func testAnOlderAnswerIsDropped() throws {
        var panel = try panel("field=input\ntext=one\n\nfield=output\ntext=old\n")
        let first = panel.set("two", of: "input")
        let second = panel.set("three", of: "input")

        XCTAssertFalse(panel.take(PluginOutput(text: "field=input\ntext=two\n\nfield=output\ntext=stale\n"), answering: first))
        XCTAssertEqual(panel.parts[1].control, .text("old", placeholder: nil, isReadOnly: false))
        XCTAssertTrue(panel.take(PluginOutput(text: "field=input\ntext=three\n\nfield=output\ntext=new\n"), answering: second))
        XCTAssertEqual(panel.parts[1].control, .text("new", placeholder: nil, isReadOnly: false))
    }

    func testAnAnswerKeepsTheTextThePersonIsEditing() throws {
        var panel = try panel("field=input\ntext=one\n")
        let call = panel.set("two ", of: "input")

        panel.take(PluginOutput(text: "field=input\ntext=two\n"), answering: call, keeping: "input")

        XCTAssertEqual(panel.parts[0].control, .text("two ", placeholder: nil, isReadOnly: false))
    }

    func testAPressCanReplaceAnyText() throws {
        var panel = try panel("field=input\ntext=one\n")
        let call = panel.advance()

        panel.take(PluginOutput(text: "field=input\ntext=swapped\n"), answering: call)

        XCTAssertEqual(panel.parts[0].control, .text("swapped", placeholder: nil, isReadOnly: false))
    }

    func testTheHintListsTheKeysOfItsParts() throws {
        XCTAssertEqual(try panel(lights).hint, "⌘Q Quit   Esc Close")
        XCTAssertEqual(try panel("grid=swap\n\nbutton=swap\nicon=arrow.up.arrow.down\nshortcut=cmd+shift+s\n").hint, "⌘⇧S Swap   Esc Close")
    }

    func testAButtonCanTakeEscapeAndThenTheHintHasNoCloseOfItsOwn() throws {
        let sheet = try panel("grid=cancel remove\n\nbutton=cancel\ntitle=Cancel\nshortcut=escape\n\nbutton=remove\ntitle=Move to Trash\nshortcut=cmd+return\n")

        XCTAssertEqual(sheet.parts.first?.key, ActionKey(name: "escape"))
        XCTAssertEqual(sheet.hint, "Esc Cancel   ⌘⏎ Move to Trash")
        XCTAssertEqual(PluginOutput(text: "text=a\nshortcut=cmd+escape\n").partFaults, ["the part a has an unknown key combination: cmd+escape"])
    }

    func testASheetOfRowsDrawsKeysOnlyWhenItsDrawingPlacesAButtonWithAKey() throws {
        let rows = "repeat=files\n\nrow=a\ntitle=A\n\n"
        let drawn = try XCTUnwrap(SheetParts(output: PluginOutput(text: "grid=files\ngrid=cancel\n\n\(rows)button=cancel\nshortcut=escape\n")))
        let actions = SheetParts(output: PluginOutput(text: "grid=files\n\n\(rows)text=t\n\nbutton=reveal\nshortcut=cmd+return\n"))

        XCTAssertTrue(drawn.drawsKeys)
        XCTAssertEqual(actions?.drawsKeys, false)
    }

    func testAnEveryLineIsAnUnknownKeyThatASheetSkips() throws {
        XCTAssertEqual(PluginOutput(text: "every=5\n\ntext=a\ntitle=A\n").sheetFaults, [])
        XCTAssertEqual(try panel("every=5\n\ntext=a\ntitle=A\n").parts.map(\.id), ["a"])
    }

    func testTheHintSaysThatAPressStopsARunningPart() throws {
        let sheet = try panel("grid=quit swap\n\nbutton=quit\ntitle=Quit\nshortcut=cmd+q\n\nbutton=swap\ntitle=Swap\nshortcut=cmd+s\n")

        XCTAssertEqual(sheet.hint(stopping: { $0.id == "quit" }), "⌘Q Stop   ⌘S Swap   Esc Close")
        XCTAssertEqual(sheet.hint(stopping: { _ in false }), sheet.hint)
    }

    func testTheCatalogReportsWhatAPartCannotHold() {
        XCTAssertEqual(PluginOutput(text: lights).partFaults, [])
        XCTAssertEqual(PluginOutput(text: "text=a\ncolour=red\n").partFaults, ["the part a has an unknown key: colour"])
        XCTAssertEqual(PluginOutput(text: "choice=a\noption=English\n").partFaults, ["the part a needs an option as id:title: English"])
        XCTAssertEqual(PluginOutput(text: "choice=a\ncolor=red\n").partFaults, ["the part a needs a color as #rrggbb: red"])
        XCTAssertEqual(PluginOutput(text: "text=a\nshortcut=nope+a\n").partFaults, ["the part a has an unknown key combination: nope+a"])
        XCTAssertEqual(PluginOutput(text: "text=a\ntitle=A\ndetail=9%\nvalue=0.09\ntone=bad\n").partFaults, [])
        XCTAssertEqual(PluginOutput(text: "text=a\ntitle=A\ndetail=9%\nvalue=0.09\ntone=red\n").partFaults, ["the part a has an unknown tone: red"])
    }

    func testTheCatalogNamesEachControl() {
        for word in ["`switch`", "`slider`", "`choice`", "`field`", "`hotkey`", "`button`", "`text`", "`number`", "`graph`", "`picture`", "`gauge`", "`pad=", "`card=", "`repeat=", "`icon="] {
            XCTAssertTrue(PartCatalog.text.contains(word), word)
        }
    }

    func testTheCallsOfAPanel() {
        XCTAssertEqual(SpotAction.set("left", to: "true").arguments, ["left", "true"])
        XCTAssertEqual(SpotAction.press("quit").arguments, ["quit"])
    }

    func testAPartOrAnActionCalledReadIsAFault() {
        XCTAssertEqual(PluginOutput(text: "text=read\ntitle=A\n").partFaults, ["a part cannot be called read"])
        XCTAssertEqual(PluginOutput(text: "pad=read go\n").partFaults, ["a part cannot be called read"])
        XCTAssertEqual(PluginOutput(text: "button=read\ntitle=A\n").partFaults, ["an action cannot be called read"])
    }

    func testAPartCalledCallOrArgIsAFaultBecauseAStayingScriptReadsThoseKeys() {
        for id in ["call", "reason", "arg"] {
            XCTAssertEqual(PluginOutput(text: "field=\(id)\ntext=A\n").partFaults, ["a part cannot be called \(id)"])
        }
    }

    func testAPartOrAnActionWithADefaultIdIsAFaultButAnOpenActionChangesThePick() {
        for id in ["run", "open", "drop"] {
            XCTAssertEqual(PluginOutput(text: "text=\(id)\ntitle=A\n").partFaults, ["a part cannot be called \(id)"])
        }
        for id in ["run", "drop"] {
            XCTAssertEqual(PluginOutput(text: "button=\(id)\ntitle=A\n").partFaults, ["an action cannot be called \(id)"])
        }
        XCTAssertEqual(PluginOutput(text: "button=open\ntitle=Show\n").partFaults, [])
    }

    func testArrowsSelectThePartsThatReturnCanUse() throws {
        var sheet = try panel("""
        grid=key
        grid=note
        grid=wifi
        grid=reload

        hotkey=key
        title=Key
        value=ctrl+space

        text=note
        title=Note

        switch=wifi
        title=Wi-Fi
        on=true

        button=reload
        title=Reload
        """)

        XCTAssertEqual(sheet.selectedPart?.id, "key")
        sheet.move(by: 1)
        XCTAssertEqual(sheet.selectedPart?.id, "wifi")
        sheet.move(by: 1)
        sheet.move(by: 1)
        XCTAssertEqual(sheet.selectedPart?.id, "reload")
        sheet.move(by: -3)
        XCTAssertEqual(sheet.selectedPart?.id, "key")
    }

    func testASheetOpensWithItsFirstPartSelected() throws {
        let sheet = try panel("text=note\ntitle=Note\n\nhotkey=key\nvalue=ctrl+space\n\nswitch=wifi\non=true\n")

        XCTAssertEqual(sheet.selectedPart?.id, "key")
    }

    func testASheetWithATextAreaKeepsItsArrows() throws {
        var sheet = try panel("field=note\ntext=Hello\n\nbutton=reload\ntitle=Reload\n")

        sheet.move(by: 1)

        XCTAssertFalse(sheet.takesArrows)
        XCTAssertNil(sheet.selectedPart)
    }

    func testALineWithAValueCarriesALevelMarkInItsTone() throws {
        let part = try XCTUnwrap(try panel("text=left\ntitle=AirPods left\ndetail=12%\nvalue=0.12\ntone=bad\n").parts.first)

        XCTAssertEqual(part.control, SpotPart.Control.none)
        XCTAssertEqual(part.mark?.kind, .gauge)
        XCTAssertEqual(part.mark?.fill, 0.12)
        XCTAssertEqual(part.mark?.tone, .bad)
    }

    func testALevelRingsItsNumberWithNoPercentSignAndATrendOrAPlainLineDoesNot() throws {
        let parts = try panel("text=mac\ntitle=Mac\ndetail=80%\nvalue=0.8\n\ntext=cpu\ntitle=CPU\ndetail=30%\npoint=3\n\ntext=swap\ntitle=Swap\ndetail=0 MB\n").parts

        XCTAssertEqual(parts.map(\.ringWords), ["80", nil, nil])
    }

    func testALineWithNoIconKeepsTheIconColumnOnlyInAListWhereALineHasOne() throws {
        let list = try panel("section=cpu\ntitle=CPU\n\ntext=all\ntitle=All\nicon=cpu\n\ntext=top\ntitle=launchd\n")
        let plain = try panel("text=top\ntitle=launchd\n")
        let drawn = try panel("grid=all top\n\ntext=all\ntitle=All\nicon=cpu\n\ntext=top\ntitle=launchd\n")

        XCTAssertEqual(list.parts.map(list.keepsIconColumn), [false, false, true])
        XCTAssertEqual(plain.parts.map(plain.keepsIconColumn), [false])
        XCTAssertEqual(drawn.parts.map(drawn.keepsIconColumn), [false, false])
    }

    func testALineWithPointsAndADetailCarriesATrendMark() throws {
        let part = try XCTUnwrap(try panel("text=cpu\ntitle=All cores\ndetail=30%\nmax=100\npoint=20\npoint=40\n").parts.first)

        XCTAssertEqual(part.control, SpotPart.Control.none)
        XCTAssertEqual(part.mark?.kind, .trend)
        XCTAssertEqual(part.mark?.scaledPoints, [0.2, 0.4])
    }

    func testPointsWithNoDetailStillDrawAChartTile() throws {
        let part = try XCTUnwrap(try panel("graph=history\npoint=2\npoint=4\n").parts.first)

        XCTAssertEqual(part.control, .chart([2, 4]))
        XCTAssertNil(part.mark)
    }

    func testTheArrowsScrollASheetWithNothingToSelect() throws {
        let sheet = try panel("text=mac\ntitle=This Mac\ndetail=100%\n\ntext=swap\ntitle=Swap\ndetail=0 MB\n")

        XCTAssertTrue(sheet.scrollsByArrows)
    }

    func testTheArrowsDoNotScrollASheetWithAPartToSelect() throws {
        let sheet = try panel("text=mac\ntitle=This Mac\n\nhotkey=key\nvalue=ctrl+space\n")

        XCTAssertFalse(sheet.scrollsByArrows)
    }

    func testTheSelectionSurvivesANewAnswerAndMovesOnWhenThePartEnds() throws {
        var sheet = try panel("hotkey=key\nvalue=ctrl+space\n")
        sheet.move(by: 1)

        sheet.take(PluginOutput(text: "hotkey=key\nvalue=option+space\n"), answering: sheet.generation)
        XCTAssertEqual(sheet.selectedPart?.id, "key")

        sheet.take(PluginOutput(text: "switch=wifi\non=true\n"), answering: sheet.generation)
        XCTAssertEqual(sheet.selectedPart?.id, "wifi")
    }

    func testAClearedSelectionGoesBackToTheFirstPart() throws {
        var sheet = try panel("hotkey=key\nvalue=ctrl+space\n\nswitch=wifi\non=true\n")
        sheet.move(by: 1)

        sheet.clearSelection()

        XCTAssertEqual(sheet.selectedPart?.id, "key")
    }

    func testANumberShowsItsValueLargeWithItsTitleAsTheLabel() throws {
        let part = try XCTUnwrap(PluginOutput(text: "grid=cpu cpu\ngrid=cpu cpu\n\nnumber=cpu\nvalue=42%\ntitle=CPU\n").parts.first)

        XCTAssertEqual(part.control, .metric("42%"))
        XCTAssertEqual(part.title, "CPU")
        XCTAssertEqual(MetricValue(output: PluginOutput(text: "number=cpu\nvalue=42%\ntitle=CPU\n")), MetricValue(title: "42%", detail: "CPU"))
    }

    func testAChoiceDrawnOverTwoLinesIsAListAndOverOneLineAMenu() throws {
        let choice = "choice=c\noption=a:A\noption=b:B\nvalue=a\n"
        let tall = try XCTUnwrap(PluginOutput(text: "grid=c\ngrid=c\n\n" + choice).parts.first)
        let short = try XCTUnwrap(PluginOutput(text: "grid=c\n\n" + choice).parts.first)
        var sheet = try XCTUnwrap(SheetParts(output: PluginOutput(text: "grid=c\ngrid=c\n\n" + choice)))

        XCTAssertEqual(tall.control, .list([.init(id: "a", title: "A"), .init(id: "b", title: "B")], value: "a"))
        XCTAssertEqual(short.control, .menu([.init(id: "a", title: "A"), .init(id: "b", title: "B")], value: "a"))
        sheet.merge(PluginOutput(text: "choice=c\noption=a:A\nvalue=a\n"))
        XCTAssertEqual(sheet.parts.first?.control, .list([.init(id: "a", title: "A")], value: "a"))
    }

    func testALookOnlyDrawsTheBox() {
        XCTAssertEqual(PluginOutput(text: "text=a\ntitle=A\nlook=large\n").partFaults, ["the part a has an unknown look: large"])
        XCTAssertEqual(PluginOutput(text: "text=a\ntitle=A\nlook=section\n").partFaults, ["the part a has an unknown look: section"])
        XCTAssertEqual(PluginOutput(text: "choice=a\noption=x:X\nlook=list\n").partFaults, ["the part a has an unknown look: list"])
    }

    func testASwitchWithATickLookKeepsItsValueAndATemplateSlotTakesIt() throws {
        let part = try XCTUnwrap(PluginOutput(text: "switch=done\ntitle=Call mom\non=true\nlook=tick\n").parts.first)
        let template = try XCTUnwrap(RowTemplate(block: TextBlock(fields: [.init(key: "template", value: "reminder"), .init(key: "switch", value: "done"), .init(key: "done.look", value: "tick")])))
        let item = try XCTUnwrap(SpotItem(block: try XCTUnwrap(TextBlock.blocks(in: "row=reminder:1\ntitle=Buy milk\ndone=false\ndone.title=Buy milk\n").first)))
        let slot = try XCTUnwrap(template.parts(of: item).first)

        XCTAssertEqual(part.look, .tick)
        XCTAssertEqual(part.control, .toggle(true))
        XCTAssertEqual(PluginOutput(text: "switch=done\non=true\nlook=tick\n").partFaults, [])
        XCTAssertEqual(slot.look, .tick)
        XCTAssertEqual(slot.control, .toggle(false))
        XCTAssertEqual(slot.title, "Buy milk")
        XCTAssertTrue(PartCatalog.text.contains("`look=tick`"))
        XCTAssertTrue(PartCatalog.text.contains("`color=#1BADF8`"))
        XCTAssertTrue(PartCatalog.text.contains("`tone=good`, `warn` or `bad` on a text"))
    }

}
