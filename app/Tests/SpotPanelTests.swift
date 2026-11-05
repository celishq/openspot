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
        lines=6
        placeholder=Translation
        readonly=true
        """).parts

        XCTAssertEqual(parts[0].control, .menu([.init(id: "auto", title: "Auto"), .init(id: "en", title: "English")], value: "en"))
        XCTAssertEqual(parts[1].control, .text("one\ntwo", lines: 6, placeholder: "Translation", isReadOnly: true))
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
        XCTAssertEqual(panel.parts[1].control, .text("old", lines: 4, placeholder: nil, isReadOnly: false))
        XCTAssertTrue(panel.take(PluginOutput(text: "part=input\ntext=three\n\npart=output\ntext=new\n"), answering: second))
        XCTAssertEqual(panel.parts[1].control, .text("new", lines: 4, placeholder: nil, isReadOnly: false))
    }

    func testAnAnswerKeepsTheTextThePersonIsEditing() throws {
        var panel = try panel("part=input\ntext=one\n")
        let call = panel.set("two ", of: "input")

        panel.take(PluginOutput(text: "part=input\ntext=two\n"), answering: call, keeping: "input")

        XCTAssertEqual(panel.parts[0].control, .text("two ", lines: 4, placeholder: nil, isReadOnly: false))
    }

    func testAPressCanReplaceAnyText() throws {
        var panel = try panel("part=input\ntext=one\n")
        let call = panel.advance()

        panel.take(PluginOutput(text: "part=input\ntext=swapped\n"), answering: call)

        XCTAssertEqual(panel.parts[0].control, .text("swapped", lines: 4, placeholder: nil, isReadOnly: false))
    }

    func testTheHintListsTheKeysOfItsParts() throws {
        XCTAssertEqual(try panel(lights).hint, "⌘Q Quit   Esc Close")
        XCTAssertEqual(try panel("section=swap\npress=arrow.up.arrow.down\nkey=cmd+shift+s\n").hint, "⌘⇧S Swap   Esc Close")
    }

    func testAPanelAsksToBeReadAgain() throws {
        XCTAssertEqual(try panel("every=5\n\npart=a\ntitle=A\n").every, 5)
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
        let names = TextBlock.blocks(in: PartCatalog.text).compactMap { $0.value("part") }

        XCTAssertEqual(names, ["section", "line", "switch", "slider", "swatches", "menu", "text", "button"])
    }

    func testTheCallsOfAPanel() {
        XCTAssertEqual(SpotAction.set("left", to: "true").arguments, ["set", "left", "true"])
        XCTAssertEqual(SpotAction.press("quit").arguments, ["press", "quit"])
    }
}
