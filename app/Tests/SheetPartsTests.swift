import XCTest
@testable import OpenspotCore

final class SheetPartsTests: XCTestCase {
    private let lights = """
    frame=
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
        try XCTUnwrap(SheetParts(output: Frame(text: text.placed)))
    }

    func testThePartsMarkTheAnswerToEachChangeAndAnEqualPollChangesNothing() throws {
        var parts = try panel(lights)
        let first = parts

        parts.take(Frame(text: lights.placed), answering: parts.generation)
        XCTAssertEqual(parts, first)

        parts.set("90", of: "brightness")
        parts.take(Frame(text: lights.placed), answering: parts.generation)
        let answered = parts.answered
        parts.take(Frame(text: lights.placed), answering: parts.generation - 1)

        XCTAssertNotEqual(answered, first.answered)
        XCTAssertEqual(parts.answered, answered)
    }

    func testThePartsKeepTheTimeOfTheLastChangeOfEachPictureWhenTheyArrive() throws {
        let folder = try temporaryFolder()
        let file = folder.appendingPathComponent("cover.png")
        try Data([1]).write(to: file)
        let changed = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.modificationDate: changed], ofItemAtPath: file.path)
        let missing = folder.appendingPathComponent("gone.png").path

        let parts = try XCTUnwrap(SheetParts(output: Frame(text: "picture=cover\nicon=\(file.path)\n\npicture=gone\nicon=\(missing)\n".placed)))

        XCTAssertEqual(parts.pictureTimes[file.path], changed.timeIntervalSince1970)
        XCTAssertNil(parts.pictureTimes[missing])
    }

    func testASetValueAndReadsOfThePicturesReadNoFile() throws {
        var parts = try XCTUnwrap(SheetParts(output: Frame(text: "picture=cover\nicon=/tmp/openspot-cover.png\n\nfield=note\nvalue=a\n".placed)))
        let reads = PictureFile.reads

        parts.set("b", of: "note")
        for _ in 0..<10 { _ = parts.pictureTimes["/tmp/openspot-cover.png"] }

        XCTAssertEqual(PictureFile.reads, reads)
    }

    func testAButtonThatOnlyACardDrawingPlacesIsAPartOfTheCardAndNoAction() {
        let outputCheck = FrameCheck(text: "frame=\ngrid.strip=next next next join-now\n\nnumber=next\nvalue=09:30\n\nbutton=join-now\ntitle=Join\n\nbutton=tick\ntitle=Mark as done\n".placed)
        let output = outputCheck.output

        XCTAssertEqual(output.face.parts.map(\.id), ["next", "join-now"])
        XCTAssertEqual(output.actions.map(\.id), ["tick"])
        XCTAssertEqual(output.face.drawing(for: .strip), [["next", "next", "next", "join-now"]])
        XCTAssertEqual(outputCheck.partFaults, [])
    }

    func testATextOrANumberTakesAColourForItsBarAndOtherPartsDoNot() {
        let output = Frame(text: "number=next\nvalue=09:30\ncolor=#1BADF8\n\ntext=work\ncolor=#ff9500\n\nnumber=odd\nvalue=1\ncolor=blue\n\nswitch=disk\nvalue=true\ncolor=#1BADF8\n".placed)

        XCTAssertEqual(output.parts.map(\.color), ["#1BADF8", "#ff9500", nil, nil])
    }

    func testAViewBlockKeepsItsOwnKeysForItsViewAndOtherPartsKeepNone() {
        let output = Frame(text: "frame=\ntitle=Card\ngrid=steps\ngrid=note\n\nview=steps\nstep=words\nword=flip\nword=column\n\ntext=note\ntitle=Hi\n")

        XCTAssertEqual(output.parts.first { $0.id == "steps" }?.values["word"], ["flip", "column"])
        XCTAssertEqual(output.parts.first { $0.id == "steps" }?.values["step"], ["words"])
        XCTAssertEqual(output.parts.first { $0.id == "note" }?.values, [:])
    }

    func testAViewBlockAlsoGetsEachRowOfItsFrameWithItsKeysInOrder() {
        let output = Frame(text: "frame=\ngrid=gallery\ngrid=note\n\nview=gallery\nmode=all\n\ntext=a\ntitle=One\ntag=x\ntag=y\n\ntext=b\ndetail=two\\nlines\n\ntext=note\ntitle=Hi\n")

        let gallery = output.parts.first { $0.id == "gallery" }
        XCTAssertEqual(gallery?.items, [["text", "a", "title", "One", "tag", "x", "tag", "y"], ["text", "b", "detail", "two\nlines"]])
        XCTAssertEqual(gallery?.values, ["view": ["gallery"], "mode": ["all"]])
        XCTAssertEqual(output.parts.first { $0.id == "note" }?.items, [])
        XCTAssertEqual(output.items.map(\.run), ["a", "b"])
    }

    func testTheRowsOfAFrameAreBuiltOnceForAllItsViewBlocks() {
        let output = Frame(text: "frame=\ngrid=one\ngrid=two\n\nview=one\n\nview=two\n\ntext=a\ntitle=One\n\ntext=b\n")

        let places = output.parts.map { $0.items.withUnsafeBufferPointer { $0.baseAddress } }

        XCTAssertEqual(output.parts.map(\.items.count), [2, 2])
        XCTAssertEqual(places[0], places[1])
    }

    func testAViewBlockOfAFrameWithNoRowGetsNoRows() {
        let output = Frame(text: "frame=\ngrid=gallery\n\nview=gallery\nmode=all\n")

        XCTAssertEqual(output.parts.first?.values, ["view": ["gallery"], "mode": ["all"]])
        XCTAssertEqual(output.parts.first?.items, [])
    }

    func testATextsToneColoursItsWordsAndANumberKeepsItsOwn() {
        let outputCheck = FrameCheck(text: "frame=\ngrid=late\ngrid=now\ngrid=disk\ngrid=disk\n\ntext=late\ndetail=Late\ntone=bad\n\ntext=now\ntitle=Standup\ntone=on\n\nnumber=disk\nvalue=90\nmax=100\ntone=bad\n")
        let output = outputCheck.output

        XCTAssertEqual(output.parts.map(\.textTone), [.bad, nil, nil])
        XCTAssertEqual(outputCheck.partFaults, ["the part now has an unknown tone: on"])
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
        XCTAssertEqual(Frame(text: lights.placed).kind, .list)
        XCTAssertNil(SheetParts(output: Frame(text: "text=a\ntitle=A\n")))
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
        let parts = try panel("switch=wifi\nvalue=true\n\nfield=volume\ntype=slider\nvalue=40\nmax=100\n\nfield=name\nvalue=Ann\n\nnumber=history\nvalue=2\nvalue=4\n").parts

        XCTAssertEqual(parts.dropLast().map(\.control), [
            .toggle(true), .slider(level: 40, min: 0, max: 100), .text("Ann", placeholder: nil, isReadOnly: false)
        ])
        XCTAssertEqual(parts.last?.number?.points, [2, 4])
    }

    func testOnLevelTextAndPointAreNoLongerTheDataOfAKind() throws {
        let parts = try panel("switch=wifi\non=true\n\nfield=volume\ntype=slider\nlevel=40\n\nfield=name\ntext=Ann\n\nnumber=history\npoint=2\n").parts

        XCTAssertEqual(parts.dropLast().map(\.control), [.toggle(false), .slider(level: 0, min: 0, max: 100), .text("", placeholder: nil, isReadOnly: false)])
        XCTAssertEqual(parts.last?.number?.points, [])
        for (kind, key) in [("switch", "on"), ("field", "level"), ("field", "text"), ("number", "point")] {
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
        let output = Frame(text: "choice=c\nvalue=b\n\noption=a\ntitle=Team: 09:30\nicon=https://example.com/a.png\n\noption=b\n\nfield=f\n\noption=x\n".placed)

        XCTAssertEqual(output.parts.map(\.id), ["c", "f"])
        XCTAssertEqual(output.parts.first?.control, .menu([.init(id: "a", title: "Team: 09:30", icon: "https://example.com/a.png"), .init(id: "b", title: "b")], value: "b"))
        XCTAssertEqual(output.errors, ["option=x"])
    }

    func testValuesGoToTheScriptAsOneBlock() throws {
        var panel = try panel(lights)
        panel.set("true", of: "left")
        panel.set("20", of: "brightness")

        let block = try XCTUnwrap(TextBlock.blocks(in: Message(.show, inputs: panel.inputs).text ?? "").first)

        XCTAssertNil(block.value("input.lights"))
        XCTAssertEqual(block.value("input.left"), "true")
        XCTAssertEqual(block.value("input.brightness"), "20")
        XCTAssertEqual(block.value("input.color"), "#00ff00")
        XCTAssertNil(block.value("input.battery"))
    }

    func testAnOlderAnswerIsDropped() throws {
        var panel = try panel("field=input\nvalue=one\n\nfield=output\nvalue=old\n")
        let first = panel.set("two", of: "input")
        let second = panel.set("three", of: "input")

        XCTAssertFalse(panel.take(Frame(text: "field=input\nvalue=two\n\nfield=output\nvalue=stale\n".placed), answering: first))
        XCTAssertEqual(panel.parts[1].control, .text("old", placeholder: nil, isReadOnly: false))
        XCTAssertTrue(panel.take(Frame(text: "field=input\nvalue=three\n\nfield=output\nvalue=new\n".placed), answering: second))
        XCTAssertEqual(panel.parts[1].control, .text("new", placeholder: nil, isReadOnly: false))
    }

    func testAnAnswerKeepsTheTextThePersonIsEditing() throws {
        var panel = try panel("field=input\nvalue=one\n")
        let call = panel.set("two ", of: "input")

        panel.take(Frame(text: "field=input\nvalue=two\n".placed), answering: call, keeping: "input")

        XCTAssertEqual(panel.parts[0].control, .text("two ", placeholder: nil, isReadOnly: false))
    }

    func testAPressCanReplaceAnyText() throws {
        var panel = try panel("field=input\nvalue=one\n")
        let call = panel.advance()

        panel.take(Frame(text: "field=input\nvalue=swapped\n".placed), answering: call)

        XCTAssertEqual(panel.parts[0].control, .text("swapped", placeholder: nil, isReadOnly: false))
    }

    func testTheHintListsTheKeysOfItsParts() throws {
        XCTAssertEqual(try panel(lights).hint, "⌘Q Quit   Esc Close")
        XCTAssertEqual(try panel("frame=\ngrid=swap\n\nbutton=swap\nicon=arrow.up.arrow.down\nshortcut=cmd+shift+s\n").hint, "⇧⌘S Swap   Esc Close")
    }

    func testAButtonCanTakeEscapeAndThenTheHintHasNoCloseOfItsOwn() throws {
        let sheet = try panel("frame=\ngrid=cancel remove\n\nbutton=cancel\ntitle=Cancel\nshortcut=escape\n\nbutton=remove\ntitle=Move to Trash\nshortcut=cmd+return\n")

        XCTAssertEqual(sheet.parts.first?.key, ActionKey(name: "escape"))
        XCTAssertEqual(sheet.hint, "Esc Cancel   ⌘⏎ Move to Trash")
        XCTAssertEqual(FrameCheck(text: "text=a\nshortcut=cmd+escape\n".placed).partFaults, ["the part a has an unknown key combination: cmd+escape"])
    }

    func testAButtonThatCannotBeAnActionIsAFaultThatSaysWhy() {
        let key = "the button b has shortcut=ctrl+k, which a button cannot take. Use cmd or shift with a letter, a digit, return, backspace or a comma, or escape"
        let actionCheck = FrameCheck(text: "frame=\ngrid=t\n\ntext=t\n\nbutton=b\ntitle=B\nshortcut=ctrl+k\n\nbutton=c\nicon=trash\n\ntext=r\nshortcut=⌃⌥K\n")
        let action = actionCheck.output

        XCTAssertEqual(action.actions, [])
        XCTAssertEqual(action.errors, [])
        XCTAssertEqual(actionCheck.sheetFaults, [key, "the button c needs a title"])
        XCTAssertEqual(FrameCheck(text: "frame=\ngrid=b\n\nbutton=b\ntitle=B\nshortcut=ctrl+k\n".placed).partFaults, [key])
    }

    func testASheetOfRowsDrawsKeysOnlyWhenItsDrawingPlacesAButtonWithAKey() throws {
        let rows = "repeat=files\n\ntext=a\ntitle=A\n\n"
        let drawn = try XCTUnwrap(SheetParts(output: Frame(text: "frame=\ngrid=files\ngrid=cancel\n\n\(rows)button=cancel\nshortcut=escape\n".placed)))
        let actions = SheetParts(output: Frame(text: "frame=\ngrid=files\ngrid=t\n\n\(rows)text=t\n\nbutton=reveal\nshortcut=cmd+return\n".placed))

        XCTAssertTrue(drawn.drawsKeys)
        XCTAssertEqual(actions?.drawsKeys, false)
    }

    func testAnEveryLineIsAnUnknownKindThatASheetSkips() throws {
        XCTAssertEqual(FrameCheck(text: "on=clock.5\n\ntext=a\ntitle=A\n".placed).sheetFaults, ["cannot read the block that starts: on=clock.5"])
        XCTAssertEqual(try panel("on=clock.5\n\ntext=a\ntitle=A\n").parts.map(\.id), ["a"])
    }

    func testTheHintSaysThatAPressStopsARunningPart() throws {
        let sheet = try panel("frame=\ngrid=quit swap\n\nbutton=quit\ntitle=Quit\nshortcut=cmd+q\n\nbutton=swap\ntitle=Swap\nshortcut=cmd+s\n")

        XCTAssertEqual(sheet.hint(stopping: { $0.id == "quit" }), "⌘Q Stop   ⌘S Swap   Esc Close")
        XCTAssertEqual(sheet.hint(stopping: { _ in false }), sheet.hint)
    }

    func testTheCatalogReportsWhatAPartCannotHold() {
        XCTAssertEqual(FrameCheck(text: lights.placed).partFaults, [])
        XCTAssertEqual(FrameCheck(text: "text=a\ncolour=red\n".placed).partFaults, ["the part a has an unknown key: colour"])
        XCTAssertEqual(FrameCheck(text: "choice=a\noption=en:English\n".placed).partFaults, ["the part a has an unknown key: option"])
        XCTAssertEqual(FrameCheck(text: "choice=a\ncolor=red\n".placed).partFaults, ["the part a needs a color as #rrggbb: red"])
        XCTAssertEqual(FrameCheck(text: "text=a\nshortcut=nope+a\n".placed).partFaults, ["the part a has an unknown key combination: nope+a"])
        XCTAssertEqual(FrameCheck(text: "text=a\ntitle=A\ndetail=9%\ntone=bad\n".placed).partFaults, [])
        XCTAssertEqual(FrameCheck(text: "text=a\ntitle=A\ndetail=9%\ntone=red\n".placed).partFaults, ["the part a has an unknown tone: red"])
    }

    func testTheCallsOfAPanel() {
        XCTAssertEqual(SpotAction.set("left", to: "true").arguments, ["left", "true"])
        XCTAssertEqual(SpotAction.press("quit").arguments, ["quit"])
    }

    func testAPartOrAnActionCalledShowIsAFault() {
        XCTAssertEqual(FrameCheck(text: "text=show\ntitle=A\n".placed).partFaults, ["a part cannot be called show"])
        XCTAssertEqual(FrameCheck(text: "button=show\ntitle=A\n".placed).partFaults, ["an action cannot be called show"])
    }

    func testAPartCanBeCalledCallOrArgBecauseAValueRidesInsideTheInputOfACall() {
        for id in ["call", "reason", "arg", "input"] {
            XCTAssertEqual(FrameCheck(text: "field=\(id)\nvalue=A\n".placed).partFaults, [])
        }
    }

    func testAPartOrAnActionWithADefaultIdIsAFaultButAnOpenActionChangesThePick() {
        for id in ["open", "drop"] {
            XCTAssertEqual(FrameCheck(text: "text=\(id)\ntitle=A\n".placed).partFaults, ["a part cannot be called \(id)"])
        }
        XCTAssertEqual(FrameCheck(text: "button=drop\ntitle=A\n".placed).partFaults, ["an action cannot be called drop"])
        XCTAssertEqual(FrameCheck(text: "button=open\ntitle=Show\n".placed).partFaults, [])
    }

    func testRunIsAnIdThatAScriptCanGiveAPartOrAnAction() {
        XCTAssertEqual(FrameCheck(text: "text=run\ntitle=A\n".placed).partFaults, [])
        XCTAssertEqual(FrameCheck(text: "button=run\ntitle=A\n".placed).partFaults, [])
    }

    func testArrowsSelectThePartsThatReturnCanUse() throws {
        var sheet = try panel("""
        frame=
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

    func testALineWithNoIconKeepsTheIconColumnOnlyInAListWhereALineHasOne() throws {
        let list = try XCTUnwrap(SheetParts(output: Frame(text: "frame=\ngrid.large=cpu all top\n\nsection=cpu\ntitle=CPU\n\ntext=all\ntitle=All\nicon=cpu\n\ntext=top\ntitle=launchd\n")))
        let plain = try XCTUnwrap(SheetParts(output: Frame(text: "frame=\ngrid.large=top\n\ntext=top\ntitle=launchd\n")))
        let drawn = try panel("frame=\ngrid=all top\n\ntext=all\ntitle=All\nicon=cpu\n\ntext=top\ntitle=launchd\n")

        XCTAssertEqual(list.parts.map(list.keepsIconColumn), [false, false, true])
        XCTAssertEqual(plain.parts.map(plain.keepsIconColumn), [false])
        XCTAssertEqual(drawn.parts.map(drawn.keepsIconColumn), [false, false])
    }

    func testPointsWithNoDetailStillDrawANumberSeries() throws {
        let part = try XCTUnwrap(try panel("number=history\nvalue=2\nvalue=4\n").parts.first)

        XCTAssertEqual(part.number?.points, [2, 4])
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

        sheet.take(Frame(text: "field=key\ntype=hotkey\nvalue=option+space\n".placed), answering: sheet.generation)
        XCTAssertEqual(sheet.selectedPart?.id, "key")

        sheet.take(Frame(text: "switch=wifi\nvalue=true\n".placed), answering: sheet.generation)
        XCTAssertEqual(sheet.selectedPart?.id, "wifi")
    }

    func testAClearedSelectionGoesBackToTheFirstPart() throws {
        var sheet = try panel("field=key\ntype=hotkey\nvalue=ctrl+space\n\nswitch=wifi\nvalue=true\n")
        sheet.moveLine(by: 1)

        sheet.clearSelection()

        XCTAssertEqual(sheet.selectedPart?.id, "key")
    }

    func testANumberShowsItsValueLargeWithItsTitleAsTheLabel() throws {
        let part = try XCTUnwrap(Frame(text: "frame=\ngrid=cpu cpu\ngrid=cpu cpu\n\nnumber=cpu\nvalue=42%\ntitle=CPU\n".placed).parts.first)

        XCTAssertEqual(part.number?.text, "42%")
        XCTAssertEqual(part.title, "CPU")
        XCTAssertEqual(MetricValue(output: Frame(text: "number=cpu\nvalue=42%\ntitle=CPU\n".placed)), MetricValue(title: "42%", detail: "CPU", number: .of("value=42%")))
    }

    func testAChoiceDrawnOverTwoLinesIsAListAndOverOneLineAMenu() throws {
        let choice = "choice=c\nvalue=a\n\noption=a\ntitle=A\n\noption=b\ntitle=B\n"
        let tall = try XCTUnwrap(Frame(text: "frame=\ngrid=c\ngrid=c\n\n" + choice).parts.first)
        let short = try XCTUnwrap(Frame(text: "frame=\ngrid=c\n\n" + choice).parts.first)
        var sheet = try XCTUnwrap(SheetParts(output: Frame(text: "frame=\ngrid=c\ngrid=c\n\n" + choice)))

        XCTAssertEqual(tall.control, .list([.init(id: "a", title: "A"), .init(id: "b", title: "B")], value: "a"))
        XCTAssertEqual(short.control, .menu([.init(id: "a", title: "A"), .init(id: "b", title: "B")], value: "a"))
        sheet.take(Frame(text: "frame=\ngrid=c\ngrid=c\n\nchoice=c\nvalue=a\n\noption=a\ntitle=A\n".placed), answering: sheet.generation)
        XCTAssertEqual(sheet.parts.first?.control, .list([.init(id: "a", title: "A")], value: "a"))
    }

    func testALookOnlyDrawsTheBox() {
        XCTAssertEqual(FrameCheck(text: "text=a\ntitle=A\nlook=large\n".placed).partFaults, ["the part a has an unknown look: large"])
        XCTAssertEqual(FrameCheck(text: "text=a\ntitle=A\nlook=section\n".placed).partFaults, ["the part a has an unknown look: section"])
        XCTAssertEqual(FrameCheck(text: "choice=a\nlook=list\n\noption=x\ntitle=X\n".placed).partFaults, ["the part a has an unknown look: list"])
    }

    func testASwitchWithATickLookKeepsItsValue() throws {
        let part = try XCTUnwrap(Frame(text: "switch=done\ntitle=Call mom\nvalue=true\ntype=tick\n".placed).parts.first)

        XCTAssertEqual(part.look, .tick)
        XCTAssertEqual(part.control, .toggle(true))
        XCTAssertEqual(FrameCheck(text: "switch=done\nvalue=true\ntype=tick\n".placed).partFaults, [])
    }


    private let treeForm = """
    frame=
    class=gap-part

    field=name
    title=Name
    value=Ada

    box=foot
    class=flex-row gap-part

    switch=wifi
    parent=foot
    title=Wi-Fi
    value=true

    choice=look
    parent=foot
    value=a

    option=a
    title=A

    button=save
    parent=foot
    title=Save

    number=battery
    value=84
    max=100
    """

    private let treeList = """
    frame=
    class=gap-part

    field=find
    type=search

    button=top
    title=Top

    items=list

    text=a
    parent=list
    title=Apple

    text=b
    parent=list
    title=Banana

    button=forget
    parent=list
    title=Forget
    shortcut=cmd+f

    button=add
    title=Add
    """

    func testAWrittenTreeTakesTheBlocksInsideItsItemsAsTheItemsAndItsButtonsThereAsActions() throws {
        let output = Frame(text: treeList)
        let sheet = try XCTUnwrap(SheetParts(output: output))

        XCTAssertEqual(output.items.map(\.run), ["a", "b"])
        XCTAssertEqual(output.items.map(\.parent), [nil, nil])
        XCTAssertEqual(output.actions.map(\.id), ["forget"])
        XCTAssertEqual(output.parts.map(\.id), ["top", "add"])
        XCTAssertEqual(output.search, .local)
        XCTAssertTrue(sheet.showsRows)
        XCTAssertEqual(output.tree.node("list")?.style.grows, true)
    }

    func testTheFocusOfAWrittenTreeFollowsItsLinesAndARowIsOneLine() throws {
        var sheet = try XCTUnwrap(SheetParts(output: Frame(text: treeForm)))

        XCTAssertEqual(sheet.focusOrder.map(\.id), ["name", "wifi", "look", "save"])
        XCTAssertTrue(sheet.takesArrows)
        XCTAssertEqual(sheet.selectedPart?.id, "name")
        XCTAssertTrue(sheet.moveLine(by: 1))
        XCTAssertEqual(sheet.selectedPart?.id, "wifi")
        sheet.move(by: 2)
        XCTAssertEqual(sheet.selectedPart?.id, "save")
        XCTAssertTrue(sheet.moveLine(by: -1))
        XCTAssertEqual(sheet.selectedPart?.id, "name")
        XCTAssertFalse(sheet.moveLine(by: -1))
    }

    func testInAWrittenTreeOnlyThePartsAfterTheItemsTakeTheFocus() throws {
        var sheet = try XCTUnwrap(SheetParts(output: Frame(text: treeList)))

        XCTAssertNil(sheet.selectedPart)
        XCTAssertEqual(sheet.focusOrder.map(\.id), ["add"])
        XCTAssertTrue(sheet.leaveRows())
        XCTAssertEqual(sheet.selectedPart?.id, "add")
        XCTAssertTrue(sheet.moveLine(by: -1))
        XCTAssertNil(sheet.selectedPart)
    }
}
