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

    switch=left
    title=Left
    detail=Connecting…
    value=false

    field=brightness
    type=slider
    value=80
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
        try XCTUnwrap(SheetParts(output: SpotOutput(text: text)))
    }

    func testAButtonThatOnlyACardDrawingPlacesIsAPartOfTheCardAndNoAction() {
        let output = SpotOutput(text: "grid.strip=next next next join-now\n\nnumber=next\nvalue=09:30\n\nbutton=join-now\ntitle=Join\n\nbutton=tick\ntitle=Mark as done\n")

        XCTAssertEqual(output.parts.map(\.id), ["next", "join-now"])
        XCTAssertEqual(output.actions.map(\.id), ["tick"])
        XCTAssertEqual(output.face.drawing(for: .strip), [["next", "next", "next", "join-now"]])
        XCTAssertEqual(output.partFaults, [])
    }

    func testATextOrANumberTakesAColourForItsBarAndOtherPartsDoNot() {
        let output = SpotOutput(text: "number=next\nvalue=09:30\ncolor=#1BADF8\n\ntext=work\ncolor=#ff9500\n\nnumber=odd\nvalue=1\ncolor=blue\n\ngraph=disk\nvalue=0.5\ncolor=#1BADF8\n")

        XCTAssertEqual(output.parts.map(\.color), ["#1BADF8", "#ff9500", nil, nil])
    }

    func testAViewBlockKeepsItsOwnKeysForItsViewAndOtherPartsKeepNone() {
        let output = SpotOutput(text: "title=Card\n\nview=steps\nstep=words\nword=flip\nword=column\n\ntext=note\ntitle=Hi\n")

        XCTAssertEqual(output.parts.first { $0.id == "steps" }?.values["word"], ["flip", "column"])
        XCTAssertEqual(output.parts.first { $0.id == "steps" }?.values["step"], ["words"])
        XCTAssertEqual(output.parts.first { $0.id == "note" }?.values, [:])
    }

    func testATextsToneColoursItsWordsAndAGaugeKeepsItsOwn() {
        let output = SpotOutput(text: "text=due\ndetail=Late\ntone=bad\n\ntext=now\ntitle=Standup\ntone=on\n\ngraph=disk\nvalue=0.9\ntone=bad\n")

        XCTAssertEqual(output.parts.map(\.textTone), [.bad, nil, nil])
        XCTAssertEqual(output.partFaults, ["the part now has an unknown tone: on"])
    }

    func testASetValueKeepsThePlacementOfTheParts() throws {
        var panel = try panel(lights)
        let placement = panel.placement

        panel.set("true", of: "left")
        panel.set("20", of: "brightness")
        panel.set("#ff0000", of: "color")

        XCTAssertEqual(panel.placement, placement)
    }

    func testAScriptThatPrintsPartsIsAList() {
        XCTAssertEqual(SpotOutput(text: lights).kind, .list)
        XCTAssertNil(SheetParts(output: SpotOutput(text: "row=a\ntitle=A\n")))
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

    func testEachKindKeepsItsDataInValue() throws {
        let parts = try panel("switch=wifi\nvalue=true\n\nfield=volume\ntype=slider\nvalue=40\nmax=100\n\nfield=name\nvalue=Ann\n\ngraph=history\nvalue=2\nvalue=4\n").parts

        XCTAssertEqual(parts.map(\.control), [
            .toggle(true), .slider(level: 40, min: 0, max: 100), .text("Ann", placeholder: nil, isReadOnly: false), .chart([2, 4])
        ])
    }

    func testOnLevelTextAndPointAreNoLongerTheDataOfAKind() throws {
        let parts = try panel("switch=wifi\non=true\n\nfield=volume\ntype=slider\nlevel=40\n\nfield=name\ntext=Ann\n\ngraph=history\npoint=2\n").parts

        XCTAssertEqual(parts.map(\.control), [.toggle(false), .slider(level: 0, min: 0, max: 100), .text("", placeholder: nil, isReadOnly: false), .chart([])])
        for (kind, key) in [("switch", "on"), ("slider", "level"), ("field", "text"), ("graph", "point")] {
            XCTAssertEqual(PartCatalog.faults(in: TextBlock(fields: [.init(key: kind, value: "a"), .init(key: key, value: "1")])), ["the part a has an unknown key: \(key)"])
        }
    }

    func testAMenuAndATextAreaReadTheirOptions() throws {
        let parts = try panel("""
        choice=source
        value=en

        option=auto
        title=Auto

        option=en
        title=English

        field=output
        value=one\\ntwo
        placeholder=Translation
        readonly=true
        """).parts

        XCTAssertEqual(parts[0].control, .menu([.init(id: "auto", title: "Auto"), .init(id: "en", title: "English")], value: "en"))
        XCTAssertEqual(parts[1].control, .text("one\ntwo", placeholder: "Translation", isReadOnly: true))
    }

    func testAChoiceTakesTheOptionBlocksAfterItWithEachTitleAndIconWhole() {
        let output = SpotOutput(text: "choice=c\nvalue=b\n\noption=a\ntitle=Team: 09:30\nicon=https://example.com/a.png\n\noption=b\n\nfield=f\n\noption=x\n")

        XCTAssertEqual(output.parts.map(\.id), ["c", "f"])
        XCTAssertEqual(output.parts.first?.control, .menu([.init(id: "a", title: "Team: 09:30", icon: "https://example.com/a.png"), .init(id: "b", title: "b")], value: "b"))
        XCTAssertEqual(output.errors, ["option=x"])
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
        var panel = try panel("field=input\nvalue=one\n\nfield=output\nvalue=old\n")
        let first = panel.set("two", of: "input")
        let second = panel.set("three", of: "input")

        XCTAssertFalse(panel.take(SpotOutput(text: "field=input\nvalue=two\n\nfield=output\nvalue=stale\n"), answering: first))
        XCTAssertEqual(panel.parts[1].control, .text("old", placeholder: nil, isReadOnly: false))
        XCTAssertTrue(panel.take(SpotOutput(text: "field=input\nvalue=three\n\nfield=output\nvalue=new\n"), answering: second))
        XCTAssertEqual(panel.parts[1].control, .text("new", placeholder: nil, isReadOnly: false))
    }

    func testAnAnswerKeepsTheTextThePersonIsEditing() throws {
        var panel = try panel("field=input\nvalue=one\n")
        let call = panel.set("two ", of: "input")

        panel.take(SpotOutput(text: "field=input\nvalue=two\n"), answering: call, keeping: "input")

        XCTAssertEqual(panel.parts[0].control, .text("two ", placeholder: nil, isReadOnly: false))
    }

    func testAPressCanReplaceAnyText() throws {
        var panel = try panel("field=input\nvalue=one\n")
        let call = panel.advance()

        panel.take(SpotOutput(text: "field=input\nvalue=swapped\n"), answering: call)

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
        XCTAssertEqual(SpotOutput(text: "text=a\nshortcut=cmd+escape\n").partFaults, ["the part a has an unknown key combination: cmd+escape"])
    }

    func testAButtonThatCannotBeAnActionIsAFaultThatSaysWhy() {
        let key = "the button b has shortcut=ctrl+k, which a button cannot take. Use cmd or shift with a letter, a digit, return, backspace or a comma, or escape"
        let action = SpotOutput(text: "text=t\n\nbutton=b\ntitle=B\nshortcut=ctrl+k\n\nbutton=c\nicon=trash\n\nrow=r\nshortcut=⌃⌥K\n")

        XCTAssertEqual(action.actions, [])
        XCTAssertEqual(action.unreadable, [])
        XCTAssertEqual(action.sheetFaults, [key, "the button c needs a title"])
        XCTAssertEqual(SpotOutput(text: "grid=b\n\nbutton=b\ntitle=B\nshortcut=ctrl+k\n").partFaults, [key])
    }

    func testASheetOfRowsDrawsKeysOnlyWhenItsDrawingPlacesAButtonWithAKey() throws {
        let rows = "repeat=files\n\nrow=a\ntitle=A\n\n"
        let drawn = try XCTUnwrap(SheetParts(output: SpotOutput(text: "grid=files\ngrid=cancel\n\n\(rows)button=cancel\nshortcut=escape\n")))
        let actions = SheetParts(output: SpotOutput(text: "grid=files\n\n\(rows)text=t\n\nbutton=reveal\nshortcut=cmd+return\n"))

        XCTAssertTrue(drawn.drawsKeys)
        XCTAssertEqual(actions?.drawsKeys, false)
    }

    func testAnEveryLineIsAnUnknownKindThatASheetSkips() throws {
        XCTAssertEqual(SpotOutput(text: "on=clock.5\n\ntext=a\ntitle=A\n").sheetFaults, ["cannot read the block that starts: on=clock.5"])
        XCTAssertEqual(try panel("on=clock.5\n\ntext=a\ntitle=A\n").parts.map(\.id), ["a"])
    }

    func testTheHintSaysThatAPressStopsARunningPart() throws {
        let sheet = try panel("grid=quit swap\n\nbutton=quit\ntitle=Quit\nshortcut=cmd+q\n\nbutton=swap\ntitle=Swap\nshortcut=cmd+s\n")

        XCTAssertEqual(sheet.hint(stopping: { $0.id == "quit" }), "⌘Q Stop   ⌘S Swap   Esc Close")
        XCTAssertEqual(sheet.hint(stopping: { _ in false }), sheet.hint)
    }

    func testTheCatalogReportsWhatAPartCannotHold() {
        XCTAssertEqual(SpotOutput(text: lights).partFaults, [])
        XCTAssertEqual(SpotOutput(text: "text=a\ncolour=red\n").partFaults, ["the part a has an unknown key: colour"])
        XCTAssertEqual(SpotOutput(text: "choice=a\noption=en:English\n").partFaults, ["the part a has option lines, which Openspot no longer reads. Print each option as a block after its choice, such as option=en with title=English"])
        XCTAssertEqual(SpotOutput(text: "choice=a\ncolor=red\n").partFaults, ["the part a needs a color as #rrggbb: red"])
        XCTAssertEqual(SpotOutput(text: "text=a\nshortcut=nope+a\n").partFaults, ["the part a has an unknown key combination: nope+a"])
        XCTAssertEqual(SpotOutput(text: "text=a\ntitle=A\ndetail=9%\nvalue=0.09\ntone=bad\n").partFaults, [])
        XCTAssertEqual(SpotOutput(text: "text=a\ntitle=A\ndetail=9%\nvalue=0.09\ntone=red\n").partFaults, ["the part a has an unknown tone: red"])
    }

    func testTheCallsOfAPanel() {
        XCTAssertEqual(SpotAction.set("left", to: "true").arguments, ["left", "true"])
        XCTAssertEqual(SpotAction.press("quit").arguments, ["quit"])
    }

    func testAPartOrAnActionCalledReadIsAFault() {
        XCTAssertEqual(SpotOutput(text: "text=read\ntitle=A\n").partFaults, ["a part cannot be called read"])
        XCTAssertEqual(SpotOutput(text: "button=read\ntitle=A\n").partFaults, ["an action cannot be called read"])
    }

    func testAPartOrAnActionWithAKeyOfStdinIsAFault() {
        for id in ["search", "form", "value"] {
            XCTAssertEqual(SpotOutput(text: "field=\(id)\nvalue=A\n").partFaults, ["a part cannot be called \(id), which stdin uses"])
            XCTAssertEqual(SpotOutput(text: "button=\(id)\ntitle=A\n").partFaults, ["an action cannot be called \(id), which stdin uses"])
            XCTAssertEqual(SpotOutput(text: "row=\(id)\ntitle=A\n").partFaults, [])
        }
    }

    func testAPartCanBeCalledCallOrArgBecauseAValueRidesInsideTheInputOfACall() {
        for id in ["call", "reason", "arg", "input"] {
            XCTAssertEqual(SpotOutput(text: "field=\(id)\nvalue=A\n").partFaults, [])
        }
    }

    func testAPartOrAnActionWithADefaultIdIsAFaultButAnOpenActionChangesThePick() {
        for id in ["open", "drop"] {
            XCTAssertEqual(SpotOutput(text: "text=\(id)\ntitle=A\n").partFaults, ["a part cannot be called \(id)"])
        }
        XCTAssertEqual(SpotOutput(text: "button=drop\ntitle=A\n").partFaults, ["an action cannot be called drop"])
        XCTAssertEqual(SpotOutput(text: "button=open\ntitle=Show\n").partFaults, [])
    }

    func testRunIsAnIdThatAScriptCanGiveAPartOrAnAction() {
        XCTAssertEqual(SpotOutput(text: "text=run\ntitle=A\n").partFaults, [])
        XCTAssertEqual(SpotOutput(text: "button=run\ntitle=A\n").partFaults, [])
    }

    func testArrowsSelectThePartsThatReturnCanUse() throws {
        var sheet = try panel("""
        grid=key
        grid=note
        grid=wifi
        grid=reload

        field=key
        type=hotkey
        title=Key
        value=ctrl+space

        text=note
        title=Note

        switch=wifi
        title=Wi-Fi
        value=true

        button=reload
        title=Reload
        """)

        XCTAssertEqual(sheet.selectedPart?.id, "key")
        sheet.moveLine(by: 1)
        XCTAssertEqual(sheet.selectedPart?.id, "wifi")
        sheet.moveLine(by: 1)
        sheet.moveLine(by: 1)
        XCTAssertEqual(sheet.selectedPart?.id, "reload")
        sheet.moveLine(by: -3)
        XCTAssertEqual(sheet.selectedPart?.id, "key")
    }

    func testASheetOpensWithItsFirstPartSelected() throws {
        let sheet = try panel("text=note\ntitle=Note\n\nfield=key\ntype=hotkey\nvalue=ctrl+space\n\nswitch=wifi\nvalue=true\n")

        XCTAssertEqual(sheet.selectedPart?.id, "key")
    }

    func testALineWithAValueCarriesALevelMarkInItsTone() throws {
        let part = try XCTUnwrap(try panel("text=left\ntitle=AirPods left\ndetail=12%\nvalue=0.12\ntone=bad\n").parts.first)

        XCTAssertEqual(part.control, SpotPart.Control.none)
        XCTAssertEqual(part.mark?.kind, .gauge)
        XCTAssertEqual(part.mark?.fill, 0.12)
        XCTAssertEqual(part.mark?.tone, .bad)
    }

    func testALevelRingsItsNumberWithNoPercentSignAndATrendOrAPlainLineDoesNot() throws {
        let parts = try panel("text=mac\ntitle=Mac\ndetail=80%\nvalue=0.8\n\ntext=cpu\ntitle=CPU\ndetail=30%\nmax=100\nvalue=3\n\ntext=swap\ntitle=Swap\ndetail=0 MB\n").parts

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
        let part = try XCTUnwrap(try panel("text=cpu\ntitle=All cores\ndetail=30%\nmax=100\nvalue=20\nvalue=40\n").parts.first)

        XCTAssertEqual(part.control, SpotPart.Control.none)
        XCTAssertEqual(part.mark?.kind, .trend)
        XCTAssertEqual(part.mark?.scaledPoints, [0.2, 0.4])
    }

    func testPointsWithNoDetailStillDrawAChartTile() throws {
        let part = try XCTUnwrap(try panel("graph=history\nvalue=2\nvalue=4\n").parts.first)

        XCTAssertEqual(part.control, .chart([2, 4]))
        XCTAssertNil(part.mark)
    }

    func testTheArrowsScrollASheetWithNothingToSelect() throws {
        let sheet = try panel("text=mac\ntitle=This Mac\ndetail=100%\n\ntext=swap\ntitle=Swap\ndetail=0 MB\n")

        XCTAssertTrue(sheet.scrollsByArrows)
    }

    func testTheArrowsDoNotScrollASheetWithAPartToSelect() throws {
        let sheet = try panel("text=mac\ntitle=This Mac\n\nfield=key\ntype=hotkey\nvalue=ctrl+space\n")

        XCTAssertFalse(sheet.scrollsByArrows)
    }

    func testTheSelectionSurvivesANewAnswerAndMovesOnWhenThePartEnds() throws {
        var sheet = try panel("field=key\ntype=hotkey\nvalue=ctrl+space\n")
        sheet.moveLine(by: 1)

        sheet.take(SpotOutput(text: "field=key\ntype=hotkey\nvalue=option+space\n"), answering: sheet.generation)
        XCTAssertEqual(sheet.selectedPart?.id, "key")

        sheet.take(SpotOutput(text: "switch=wifi\nvalue=true\n"), answering: sheet.generation)
        XCTAssertEqual(sheet.selectedPart?.id, "wifi")
    }

    func testAClearedSelectionGoesBackToTheFirstPart() throws {
        var sheet = try panel("field=key\ntype=hotkey\nvalue=ctrl+space\n\nswitch=wifi\nvalue=true\n")
        sheet.moveLine(by: 1)

        sheet.clearSelection()

        XCTAssertEqual(sheet.selectedPart?.id, "key")
    }

    func testANumberShowsItsValueLargeWithItsTitleAsTheLabel() throws {
        let part = try XCTUnwrap(SpotOutput(text: "grid=cpu cpu\ngrid=cpu cpu\n\nnumber=cpu\nvalue=42%\ntitle=CPU\n").parts.first)

        XCTAssertEqual(part.control, .metric("42%"))
        XCTAssertEqual(part.title, "CPU")
        XCTAssertEqual(MetricValue(output: SpotOutput(text: "number=cpu\nvalue=42%\ntitle=CPU\n")), MetricValue(title: "42%", detail: "CPU"))
    }

    func testAChoiceDrawnOverTwoLinesIsAListAndOverOneLineAMenu() throws {
        let choice = "choice=c\nvalue=a\n\noption=a\ntitle=A\n\noption=b\ntitle=B\n"
        let tall = try XCTUnwrap(SpotOutput(text: "grid=c\ngrid=c\n\n" + choice).parts.first)
        let short = try XCTUnwrap(SpotOutput(text: "grid=c\n\n" + choice).parts.first)
        var sheet = try XCTUnwrap(SheetParts(output: SpotOutput(text: "grid=c\ngrid=c\n\n" + choice)))

        XCTAssertEqual(tall.control, .list([.init(id: "a", title: "A"), .init(id: "b", title: "B")], value: "a"))
        XCTAssertEqual(short.control, .menu([.init(id: "a", title: "A"), .init(id: "b", title: "B")], value: "a"))
        sheet.take(SpotOutput(text: "grid=c\ngrid=c\n\nchoice=c\nvalue=a\n\noption=a\ntitle=A\n"), answering: sheet.generation)
        XCTAssertEqual(sheet.parts.first?.control, .list([.init(id: "a", title: "A")], value: "a"))
    }

    func testALookOnlyDrawsTheBox() {
        XCTAssertEqual(SpotOutput(text: "text=a\ntitle=A\nlook=large\n").partFaults, ["the part a has an unknown look: large"])
        XCTAssertEqual(SpotOutput(text: "text=a\ntitle=A\nlook=section\n").partFaults, ["the part a has an unknown look: section"])
        XCTAssertEqual(SpotOutput(text: "choice=a\nlook=list\n\noption=x\ntitle=X\n").partFaults, ["the part a has an unknown look: list"])
    }

    func testASwitchWithATickLookKeepsItsValue() throws {
        let part = try XCTUnwrap(SpotOutput(text: "switch=done\ntitle=Call mom\nvalue=true\ntype=tick\n").parts.first)

        XCTAssertEqual(part.look, .tick)
        XCTAssertEqual(part.control, .toggle(true))
        XCTAssertEqual(SpotOutput(text: "switch=done\nvalue=true\ntype=tick\n").partFaults, [])
    }

}
