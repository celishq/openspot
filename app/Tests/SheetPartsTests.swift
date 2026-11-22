import XCTest
@testable import OpenspotCore

final class SheetPartsTests: XCTestCase {
    private let lights = """
    frame=
    class=gap-part

    text=lights
    title=Lights
    class=font-section

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
    type=swatches
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

    func testAButtonThatOnlyTheCardShowsIsAPartOfTheCardAndNoAction() {
        let outputCheck = FrameCheck(text: "frame=\nclass=gap-part strip:flex-row\n\nnumber=next\nvalue=09:30\n\nbutton=join-now\ntitle=Join\nclass=hidden strip:flex\n\nitems=list\n\nbutton=tick\nparent=list\ntitle=Mark as done\n")
        let output = outputCheck.output

        XCTAssertEqual(output.face.tree.shown(in: Style.Variant.card(.strip)), ["next", "join-now", "list", "tick"])
        XCTAssertEqual(output.face.tree.shown(in: [.sheet]), ["next", "list", "tick"])
        XCTAssertEqual(output.actions.map(\.id), ["tick"])
        XCTAssertEqual(outputCheck.partFaults, [])
    }

    func testATextOrANumberTakesAColourForItsBarAndOtherPartsDoNot() {
        let output = Frame(text: "number=next\nvalue=09:30\ncolor=#1BADF8\n\ntext=work\ncolor=#ff9500\n\nnumber=odd\nvalue=1\ncolor=blue\n\nswitch=disk\nvalue=true\ncolor=#1BADF8\n".placed)

        XCTAssertEqual(output.parts.map(\.color), ["#1BADF8", "#ff9500", nil, nil])
    }

    private func views(_ names: String...) -> [BlockKind] {
        BlockKind.all + names.map { BlockKind(view: $0, source: "/spots/\($0).swift") }
    }

    func testAViewBlockKeepsItsOwnKeysForItsViewAndOtherPartsKeepNone() {
        let output = Frame(text: "frame=\ntitle=Card\nclass=gap-part\n\nsteps=steps\nstep=words\nword=flip\nword=column\n\ntext=note\ntitle=Hi\n", kinds: views("steps"))

        XCTAssertEqual(output.tree.node("steps")?.values["word"], ["flip", "column"])
        XCTAssertEqual(output.tree.node("steps")?.values["step"], ["words"])
        XCTAssertEqual(output.tree.node("note")?.values, [:])
    }

    func testAViewBlockAlsoGetsEachRowOfItsFrameWithItsKeysInOrder() {
        let output = Frame(text: "frame=\nclass=gap-part\n\ngallery=gallery\nmode=all\n\nitems=list\n\nitem=a\ntitle=One\ntag=x\ntag=y\nparent=list\n\nitem=b\ndetail=two\\nlines\nparent=list\n\ntext=note\ntitle=Hi\n", kinds: views("gallery"))

        XCTAssertEqual(output.rows, [["item", "a", "title", "One", "tag", "x", "tag", "y", "parent", "list"], ["item", "b", "detail", "two\nlines", "parent", "list"]])
        XCTAssertEqual(output.tree.node("gallery")?.values, ["gallery": ["gallery"], "mode": ["all"]])
        XCTAssertEqual(output.items.map(\.run), ["a", "b"])
    }

    func testAViewBlockOfAFrameWithNoRowGetsNoRows() {
        let output = Frame(text: "frame=\nclass=gap-part\n\ngallery=gallery\nmode=all\n", kinds: views("gallery"))

        XCTAssertEqual(output.tree.node("gallery")?.values, ["gallery": ["gallery"], "mode": ["all"]])
        XCTAssertEqual(output.rows, [])
    }

    func testAnUnknownToneIsAFault() {
        let outputCheck = FrameCheck(text: "frame=\nclass=gap-part\n\ntext=late\ndetail=Late\ntone=bad\n\ntext=now\ntitle=Standup\ntone=on\n\nnumber=disk\nvalue=90\nmax=100\ntone=bad\n")

        XCTAssertEqual(outputCheck.partFaults, ["the part now has an unknown tone: on"])
    }

    func testASetValueKeepsThePlacementOfTheParts() throws {
        var panel = try panel(lights)
        let height = panel.height

        panel.set("true", of: "left")
        panel.set("20", of: "brightness")
        panel.set("#ff0000", of: "color")

        XCTAssertEqual(panel.height, height)
    }

    func testASetValueReachesThePartThatTheTreeDraws() throws {
        var panel = try panel(lights)

        panel.set("true", of: "left")

        XCTAssertEqual(panel.tree.node("left")?.part?.control, .toggle(true))
        XCTAssertEqual(panel.inputs.first { $0.key == "left" }?.value, "true")
    }

    func testAScriptThatPrintsPartsIsAList() {
        XCTAssertEqual(Frame(text: lights.placed).kind, .list)
    }

    func testAListMakesASheetThatHoldsItsItemsAndDrawsNoParts() {
        let list = SheetParts(output: Frame(text: "text=a\ntitle=A\n"))

        XCTAssertTrue(list.showsRows)
        XCTAssertFalse(list.holdsParts)
    }

    func testWhatABlockPrintsDecidesItsControl() throws {
        let parts = try panel(lights).parts

        XCTAssertEqual(parts.map(\.id), ["lights", "left", "brightness", "color", "battery", "reload", "quit"])
        XCTAssertEqual(try panel(lights).tree.node("lights")?.style.font, .section)
        XCTAssertEqual(parts[1].control, .toggle(false))
        XCTAssertEqual(parts[2].control, .slider(level: 80, min: 0, max: 100))
        XCTAssertEqual(parts[3].control, .swatches(["#ff0000", "#00ff00"], value: "#00ff00"))
        XCTAssertEqual(parts[4].control, .none)
        XCTAssertEqual(parts[5].press, .line)
        XCTAssertEqual(parts[5].icon, .symbol("arrow.clockwise"))
        XCTAssertEqual(parts[6].press, .line)
        XCTAssertTrue(parts[6].closes)
    }

    func testEachKindKeepsItsDataInValue() throws {
        let parts = try panel("switch=wifi\nvalue=true\n\nfield=volume\ntype=slider\nvalue=40\nmax=100\n\nfield=name\nvalue=Ann\n\nseries=history\nvalue=2,4\n").parts

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
            XCTAssertEqual(BlockKind.faults(in: TextBlock(fields: [.init(key: kind, value: "a"), .init(key: key, value: "1")])), ["the part a has an unknown key: \(key)"])
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
        XCTAssertEqual(try panel("frame=\nclass=gap-part\n\nbutton=swap\nicon=arrow.up.arrow.down\nshortcut=cmd+shift+s\n").hint, "⇧⌘S Swap   Esc Close")
    }

    func testAButtonCanTakeEscapeAndThenTheHintHasNoCloseOfItsOwn() throws {
        let sheet = try panel("frame=\nclass=grid grid-cols-2 gap-part\n\nbutton=cancel\ntitle=Cancel\nshortcut=escape\n\nbutton=remove\ntitle=Move to Trash\nshortcut=cmd+return\n")

        XCTAssertEqual(sheet.parts.first?.key, ActionKey(name: "escape"))
        XCTAssertEqual(sheet.hint, "Esc Cancel   ⌘⏎ Move to Trash")
        XCTAssertEqual(FrameCheck(text: "text=a\nshortcut=cmd+escape\n".placed).partFaults, ["the part a has an unknown key combination: cmd+escape"])
    }

    func testAButtonThatCannotBeAnActionIsAFaultThatSaysWhy() {
        let key = "the button b has shortcut=ctrl+k, which a button cannot take. Use cmd or shift with a letter, a digit, return, backspace or a comma, or escape"
        let actionCheck = FrameCheck(text: "frame=\nclass=gap-part\n\ntext=t\n\nitems=list\n\nbutton=b\nparent=list\ntitle=B\nshortcut=ctrl+k\n\nbutton=c\nparent=list\nicon=trash\n\nitem=r\nparent=list\nshortcut=⌃⌥K\n")
        let action = actionCheck.output

        XCTAssertEqual(action.actions, [])
        XCTAssertEqual(action.errors, [])
        XCTAssertEqual(actionCheck.sheetFaults, [key, "the button c needs a title"])
        XCTAssertEqual(FrameCheck(text: "frame=\nclass=gap-part\n\nbutton=b\ntitle=B\nshortcut=ctrl+k\n").partFaults, [key])
    }

    func testASheetOfRowsDrawsKeysOnlyWhenItsDrawingPlacesAButtonWithAKey() throws {
        let rows = "items=files\n\ntext=a\nparent=files\ntitle=A\n\n"
        let drawn = try XCTUnwrap(SheetParts(output: Frame(text: "frame=\nclass=gap-part\n\n\(rows)button=cancel\nshortcut=escape\n")))
        let actions = SheetParts(output: Frame(text: "frame=\nclass=gap-part\n\n\(rows)text=t\n\nbutton=reveal\nparent=files\nshortcut=cmd+return\n"))

        XCTAssertTrue(drawn.drawsKeys)
        XCTAssertFalse(actions.drawsKeys)
    }

    func testAnEveryLineIsAnUnknownKindThatASheetSkips() throws {
        XCTAssertEqual(FrameCheck(text: "on=clock.5\n\ntext=a\ntitle=A\n".placed).sheetFaults, ["cannot read the block that starts: on=clock.5"])
        XCTAssertEqual(try panel("on=clock.5\n\ntext=a\ntitle=A\n").parts.map(\.id), ["a"])
    }

    func testTheHintSaysThatAPressStopsARunningPart() throws {
        let sheet = try panel("frame=\nclass=grid grid-cols-2 gap-part\n\nbutton=quit\ntitle=Quit\nshortcut=cmd+q\n\nbutton=swap\ntitle=Swap\nshortcut=cmd+s\n")

        XCTAssertEqual(sheet.hint(stopping: { $0.id == "quit" }), "⌘Q Stop   ⌘S Swap   Esc Close")
        XCTAssertEqual(sheet.hint(stopping: { _ in false }), sheet.hint)
    }

    func testTheCatalogReportsWhatAPartCannotHold() {
        XCTAssertEqual(FrameCheck(text: lights.placed).partFaults, [])
        XCTAssertEqual(FrameCheck(text: "text=a\ncolour=red\n".placed).partFaults, ["the part a has an unknown key: colour"])
        XCTAssertEqual(FrameCheck(text: "choice=a\noption=en:English\n".placed).partFaults, ["the part a has an unknown key: option"])
        XCTAssertEqual(FrameCheck(text: "choice=a\ntype=swatches\ncolor=red\n".placed).partFaults, ["the part a needs a color as #rrggbb: red"])
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
        class=gap-part

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

    func testALineWithNoIconKeepsTheIconColumnOnlyWhereALineHasOne() throws {
        let list = try XCTUnwrap(SheetParts(output: Frame(text: "frame=\nclass=gap-part\n\ntext=all\ntitle=All\nicon=cpu\n\ntext=top\ntitle=launchd\n")))
        let plain = try XCTUnwrap(SheetParts(output: Frame(text: "frame=\nclass=gap-part\n\ntext=top\ntitle=launchd\n")))
        let pictured = try XCTUnwrap(SheetParts(output: Frame(text: "frame=\nclass=gap-part\n\npicture=art\nicon=/a.heic\n\ntext=top\ntitle=launchd\n")))

        XCTAssertEqual(list.parts.map(list.keepsIconColumn), [false, true])
        XCTAssertEqual(plain.parts.map(plain.keepsIconColumn), [false])
        XCTAssertEqual(pictured.parts.map(pictured.keepsIconColumn), [false, false])
    }

    func testPointsWithNoDetailStillDrawANumberSeries() throws {
        let part = try XCTUnwrap(try panel("series=history\nvalue=2,4\n").parts.first)

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
        let part = try XCTUnwrap(Frame(text: "frame=\nclass=gap-part\n\nnumber=cpu\nvalue=42%\ntitle=CPU\n").parts.first)

        XCTAssertEqual(part.number?.text, "42%")
        XCTAssertEqual(part.title, "CPU")
        XCTAssertEqual(MetricValue(output: Frame(text: "number=cpu\nvalue=42%\ntitle=CPU\n".placed)), MetricValue(title: "42%", detail: "CPU", number: .of("value=42%")))
    }

    func testTheTypeOfAChoicePicksItsFormAndColorLinesAloneDoNot() throws {
        let options = "option=a\ntitle=A\n\noption=b\ntitle=B\n"
        let list = try XCTUnwrap(Frame(text: "frame=\nclass=gap-part\n\nchoice=c\ntype=list\nvalue=a\n\n" + options).parts.first)
        let colored = try XCTUnwrap(Frame(text: "frame=\nclass=gap-part\n\nchoice=c\ncolor=#ff0000\nvalue=a\n\n" + options).parts.first)
        let swatches = try XCTUnwrap(Frame(text: "frame=\nclass=gap-part\n\nchoice=c\ntype=swatches\ncolor=#ff0000\ncolor=#00ff00\nvalue=#ff0000\n").parts.first)
        var sheet = try XCTUnwrap(SheetParts(output: Frame(text: "frame=\nclass=gap-part\n\nchoice=c\ntype=list\nvalue=a\n\n" + options)))

        XCTAssertEqual(list.control, .list([.init(id: "a", title: "A"), .init(id: "b", title: "B")], value: "a"))
        XCTAssertEqual(colored.control, .menu([.init(id: "a", title: "A"), .init(id: "b", title: "B")], value: "a"))
        XCTAssertEqual(swatches.control, .swatches(["#ff0000", "#00ff00"], value: "#ff0000"))
        XCTAssertEqual(FrameCheck(text: "choice=c\ncolor=#ff0000\n".placed).partFaults, ["the choice c has color lines, which only a choice with type=swatches takes"])
        sheet.take(Frame(text: "frame=\nclass=gap-part\n\nchoice=c\ntype=list\nvalue=a\n\noption=a\ntitle=A\n"), answering: sheet.generation)
        XCTAssertEqual(sheet.parts.first?.control, .list([.init(id: "a", title: "A")], value: "a"))
    }

    func testAnIconDrawsOnEveryKindAndARoundButtonComesFromItsClass() throws {
        let parts = try panel("""
        button=round
        class=rounded-full
        icon=star

        button=boxed
        icon=star

        button=titled
        class=rounded-full
        title=Star
        icon=😀

        text=glyph
        icon=😀

        switch=file
        icon=~/Desktop
        """).parts

        XCTAssertEqual(parts.map(\.press), [.round(.symbol("star")), .line, .line, .none, .none])
        XCTAssertEqual(parts.map(\.icon), [nil, .symbol("star"), .glyph("😀"), .glyph("😀"), .file("~/Desktop")])
    }

    func testTheClassesOfAPartChooseTheLookOfItsBox() throws {
        let looks = ["bg-accent", "rounded-full", "bg-transparent", "bg-tile", "bg-tile hover:bg-accent", "rounded-inner"].map { classes in
            Frame(text: "frame=\nclass=gap-part\n\nbutton=b\ntitle=B\nclass=\(classes)\n").tree.look(of: "b")
        }

        XCTAssertEqual(looks, [.strong, .chip, .bare, .tile, .tile, nil])
        XCTAssertEqual(SpotPart.Look(style: Style(classes: "bg-tile hover:bg-accent").resolved(for: [.sheet, .hover])), .strong)
    }

    func testALookOrAnAlignKeyIsAnUnknownKey() {
        XCTAssertEqual(FrameCheck(text: "frame=\nclass=gap-part\n\nbutton=a\ntitle=A\nlook=strong\nalign=right\n").partFaults, [
            "the part a has an unknown key: look", "the part a has an unknown key: align"
        ])
    }

    func testASwitchWithATickLookKeepsItsValue() throws {
        let part = try XCTUnwrap(Frame(text: "switch=done\ntitle=Call mom\nvalue=true\ntype=tick\n".placed).parts.first)

        XCTAssertTrue(part.isTick)
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

    item=a
    parent=list
    title=Apple

    item=b
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
        XCTAssertEqual(output.items.map(\.place), [nil, nil])
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

    func testAFocusLineFollowsTheRowThatTheSheetResolves() throws {
        let text = "frame=\nclass=gap-part\n\nbox=foot\nclass=sheet:flex-row card:flex-col\n\nswitch=wifi\nparent=foot\nvalue=true\n\nbutton=save\nparent=foot\ntitle=Save\n"
        var sheet = try XCTUnwrap(SheetParts(output: Frame(text: text)))

        XCTAssertEqual(sheet.selectedPart?.id, "wifi")
        sheet.move(by: 1)
        XCTAssertEqual(sheet.selectedPart?.id, "save")
        XCTAssertFalse(sheet.moveLine(by: -1))
    }
}
