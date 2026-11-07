import XCTest
@testable import OpenspotCore

final class SpotPanelTests: XCTestCase {
    private let lights = """
    section=lights
    title=Lights
    on=true

    part=left
    title=Left
    detail=Connecting…
    on=false

    part=brightness
    level=80
    max=100
    symbol=sun.max

    part=color
    color=#ff0000
    color=#00ff00
    value=#00ff00

    part=battery
    title=Battery
    detail=68%

    part=reload
    title=Reload
    press=arrow.clockwise

    part=quit
    title=Quit
    press=true
    key=cmd+q
    close=true
    """

    private func panel(_ text: String) throws -> SpotPanel {
        try XCTUnwrap(SpotPanel(output: PluginOutput(text: text)))
    }

    func testAScriptThatPrintsPartsIsAList() {
        XCTAssertEqual(PluginOutput(text: lights).kind, .list)
        XCTAssertNil(SpotPanel(output: PluginOutput(text: "row=A\nrun=a\n")))
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
        part=source
        option=auto:Auto
        option=en:English
        value=en

        part=output
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

        XCTAssertEqual(block.value("lights"), "true")
        XCTAssertEqual(block.value("left"), "true")
        XCTAssertEqual(block.value("brightness"), "20")
        XCTAssertEqual(block.value("color"), "#00ff00")
        XCTAssertNil(block.value("battery"))
    }

    func testAnOlderAnswerIsDropped() throws {
        var panel = try panel("part=input\ntext=one\n\npart=output\ntext=old\n")
        let first = panel.set("two", of: "input")
        let second = panel.set("three", of: "input")

        XCTAssertFalse(panel.take(PluginOutput(text: "part=input\ntext=two\n\npart=output\ntext=stale\n"), answering: first))
        XCTAssertEqual(panel.parts[1].control, .text("old", placeholder: nil, isReadOnly: false))
        XCTAssertTrue(panel.take(PluginOutput(text: "part=input\ntext=three\n\npart=output\ntext=new\n"), answering: second))
        XCTAssertEqual(panel.parts[1].control, .text("new", placeholder: nil, isReadOnly: false))
    }

    func testAnAnswerKeepsTheTextThePersonIsEditing() throws {
        var panel = try panel("part=input\ntext=one\n")
        let call = panel.set("two ", of: "input")

        panel.take(PluginOutput(text: "part=input\ntext=two\n"), answering: call, keeping: "input")

        XCTAssertEqual(panel.parts[0].control, .text("two ", placeholder: nil, isReadOnly: false))
    }

    func testAPressCanReplaceAnyText() throws {
        var panel = try panel("part=input\ntext=one\n")
        let call = panel.advance()

        panel.take(PluginOutput(text: "part=input\ntext=swapped\n"), answering: call)

        XCTAssertEqual(panel.parts[0].control, .text("swapped", placeholder: nil, isReadOnly: false))
    }

    func testTheHintListsTheKeysOfItsParts() throws {
        XCTAssertEqual(try panel(lights).hint, "⌘Q Quit   Esc Close")
        XCTAssertEqual(try panel("section=swap\npress=arrow.up.arrow.down\nkey=cmd+shift+s\n").hint, "⌘⇧S Swap   Esc Close")
    }

    func testAnEveryLineIsAnUnknownKeyThatASheetSkips() throws {
        XCTAssertEqual(PluginOutput(text: "every=5\n\npart=a\ntitle=A\n").sheetFaults, [])
        XCTAssertEqual(try panel("every=5\n\npart=a\ntitle=A\n").parts.map(\.id), ["a"])
    }

    func testTheHintSaysThatAPressStopsARunningPart() throws {
        let sheet = try panel("part=quit\ntitle=Quit\npress=true\nkey=cmd+q\n\npart=swap\ntitle=Swap\npress=true\nkey=cmd+s\n")

        XCTAssertEqual(sheet.hint(stopping: { $0.id == "quit" }), "⌘Q Stop   ⌘S Swap   Esc Close")
        XCTAssertEqual(sheet.hint(stopping: { _ in false }), sheet.hint)
    }

    func testTheCatalogReportsWhatAPartCannotHold() {
        XCTAssertEqual(PluginOutput(text: lights).partFaults, [])
        XCTAssertEqual(PluginOutput(text: "part=a\ncolour=red\n").partFaults, ["the part a has an unknown key: colour"])
        XCTAssertEqual(PluginOutput(text: "part=a\non=true\nlevel=3\n").partFaults, ["the part a has more than one control"])
        XCTAssertEqual(PluginOutput(text: "part=a\noption=English\n").partFaults, ["the part a needs an option as id:title: English"])
        XCTAssertEqual(PluginOutput(text: "part=a\ncolor=red\n").partFaults, ["the part a needs a color as #rrggbb: red"])
        XCTAssertEqual(PluginOutput(text: "part=a\nkey=nope+a\n").partFaults, ["the part a has an unknown key combination: nope+a"])
    }

    func testTheCatalogNamesEachControl() {
        for word in ["`on=true`", "`level=70`", "`color=", "`option=", "`item=", "`text=", "`press=true`", "`metric=", "`point=", "`image=", "`block=progress`", "`keys=", "`card=", "`repeat=", "`glyph="] {
            XCTAssertTrue(PartCatalog.text.contains(word), word)
        }
    }

    func testTheCallsOfAPanel() {
        XCTAssertEqual(SpotAction.set("left", to: "true").arguments, ["left", "true"])
        XCTAssertEqual(SpotAction.press("quit").arguments, ["quit"])
    }

    func testAPartOrAnActionCalledReadIsAFault() {
        XCTAssertEqual(PluginOutput(text: "part=read\ntitle=A\n").partFaults, ["a part cannot be called read"])
        XCTAssertEqual(PluginOutput(text: "keys=read go\n").partFaults, ["a part cannot be called read"])
        XCTAssertEqual(PluginOutput(text: "action=read\ntitle=A\n").partFaults, ["an action cannot be called read"])
    }

    func testArrowsSelectThePartsThatReturnCanUse() throws {
        var sheet = try panel("""
        part=key
        title=Key
        shortcut=ctrl+space

        part=note
        title=Note

        part=wifi
        title=Wi-Fi
        on=true

        part=reload
        title=Reload
        press=true
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
        let sheet = try panel("part=note\ntitle=Note\n\npart=key\nshortcut=ctrl+space\n\npart=wifi\non=true\n")

        XCTAssertEqual(sheet.selectedPart?.id, "key")
    }

    func testASheetWithATextAreaKeepsItsArrows() throws {
        var sheet = try panel("part=note\ntext=Hello\n\npart=reload\ntitle=Reload\npress=true\n")

        sheet.move(by: 1)

        XCTAssertFalse(sheet.takesArrows)
        XCTAssertNil(sheet.selectedPart)
    }

    func testALineWithAValueCarriesALevelMarkInItsTone() throws {
        let part = try XCTUnwrap(try panel("part=left\ntitle=AirPods left\ndetail=12%\nvalue=0.12\ntone=bad\n").parts.first)

        XCTAssertEqual(part.control, SpotPart.Control.none)
        XCTAssertEqual(part.mark?.kind, .gauge)
        XCTAssertEqual(part.mark?.fill, 0.12)
        XCTAssertEqual(part.mark?.tone, .bad)
    }

    func testALineWithPointsAndADetailCarriesATrendMark() throws {
        let part = try XCTUnwrap(try panel("part=cpu\ntitle=All cores\ndetail=30%\nmax=100\npoint=20\npoint=40\n").parts.first)

        XCTAssertEqual(part.control, SpotPart.Control.none)
        XCTAssertEqual(part.mark?.kind, .trend)
        XCTAssertEqual(part.mark?.scaledPoints, [0.2, 0.4])
    }

    func testPointsWithNoDetailStillDrawAChartTile() throws {
        let part = try XCTUnwrap(try panel("part=history\npoint=2\npoint=4\n").parts.first)

        XCTAssertEqual(part.control, .chart([2, 4]))
        XCTAssertNil(part.mark)
    }

    func testTheArrowsScrollASheetWithNothingToSelect() throws {
        let sheet = try panel("part=mac\ntitle=This Mac\ndetail=100%\n\npart=swap\ntitle=Swap\ndetail=0 MB\n")

        XCTAssertTrue(sheet.scrollsByArrows)
    }

    func testTheArrowsDoNotScrollASheetWithAPartToSelect() throws {
        let sheet = try panel("part=mac\ntitle=This Mac\n\npart=key\nshortcut=ctrl+space\n")

        XCTAssertFalse(sheet.scrollsByArrows)
    }

    func testTheSelectionSurvivesANewAnswerAndMovesOnWhenThePartEnds() throws {
        var sheet = try panel("part=key\nshortcut=ctrl+space\n")
        sheet.move(by: 1)

        sheet.take(PluginOutput(text: "part=key\nshortcut=option+space\n"), answering: sheet.generation)
        XCTAssertEqual(sheet.selectedPart?.id, "key")

        sheet.take(PluginOutput(text: "part=wifi\non=true\n"), answering: sheet.generation)
        XCTAssertEqual(sheet.selectedPart?.id, "wifi")
    }

    func testAClearedSelectionGoesBackToTheFirstPart() throws {
        var sheet = try panel("part=key\nshortcut=ctrl+space\n\npart=wifi\non=true\n")
        sheet.move(by: 1)

        sheet.clearSelection()

        XCTAssertEqual(sheet.selectedPart?.id, "key")
    }
}
