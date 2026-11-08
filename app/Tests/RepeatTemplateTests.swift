import XCTest
@testable import OpenspotCore

final class RepeatTemplateTests: XCTestCase {
    private let apps = """
    repeat=apps

    template=row
    grid=pic name name quit
    picture=pic
    text=name
    button=quit
    quit.symbol=xmark.circle
    quit.title=Quit

    row=Safari
    run=/Applications/Safari.app
    file=/Applications/Safari.app
    name=Safari
    tone=on

    row=Notes
    run=/Applications/Notes.app
    name=Notes
    hides=quit
    """

    func testARepeatWithNoDrawingIsAList() {
        let output = PluginOutput(text: apps)

        XCTAssertEqual(output.drawing, .list)
        XCTAssertEqual(output.perLine, 1)
        XCTAssertEqual(output.layout?.repeated?.area, "apps")
        XCTAssertEqual(output.items.map(\.title), ["Safari", "Notes"])
    }

    func testOneLineOfSingleCellsIsAGrid() {
        let output = PluginOutput(text: "grid=tone\ngrid=a\n\nrepeat=a\ngrid=a b c d e f g\n\nchoice=tone\noption=none:Yellow\n\nrow=x\nrun=x\n")

        XCTAssertEqual(output.drawing.perLine, 7)
        XCTAssertEqual(output.perLine, 7)
        XCTAssertEqual(output.sheetFaults, [])
    }

    func testABentoTileRepeatsDownAndNamesTheSizeOfEachPlace() {
        let drawing = RepeatDrawing(lines: [["a", "a", "b", "c"], ["a", "a", "d", "e"]])

        XCTAssertNil(drawing.perLine)
        XCTAssertEqual(drawing.places.count, 5)
        XCTAssertEqual(drawing.area(of: 0), SheetArea(x0: 0, x1: 1, y0: 0, y1: 1))
        XCTAssertEqual(drawing.area(of: 6), SheetArea(x0: 2, x1: 2, y0: 2, y1: 2))
        XCTAssertEqual(drawing.size(of: 5), "2x2")
        XCTAssertEqual(drawing.size(of: 1), "1x1")
        XCTAssertEqual(drawing.lineCount(rows: 6), 4)
        XCTAssertEqual(drawing.lineCount(rows: 2), 2)
    }

    func testATemplateFillsItsSlotsFromTheRow() throws {
        let output = PluginOutput(text: apps)
        let safari = try XCTUnwrap(output.items.first)
        let template = try XCTUnwrap(output.template(of: safari))
        let parts = template.parts(of: safari)

        XCTAssertEqual(template.drawing(), [["pic", "name", "name", "quit"]])
        XCTAssertEqual(parts.map(\.id), ["pic", "name", "quit"])
        XCTAssertEqual(parts[0].file, "/Applications/Safari.app")
        XCTAssertEqual(parts[1].title, "Safari")
        XCTAssertEqual(parts[2].press, .symbol("xmark.circle"))
        XCTAssertEqual(parts[2].title, "Quit")
        XCTAssertEqual(safari.tone, .on)
    }

    func testARowHidesASlot() throws {
        let output = PluginOutput(text: apps)
        let notes = try XCTUnwrap(output.items.last)

        XCTAssertEqual(output.template(of: notes)?.parts(of: notes).map(\.id), ["pic", "name"])
    }

    func testAPlaceTakesTheLargestDrawingThatFitsIt() throws {
        let template = try XCTUnwrap(RowTemplate(block: TextBlock(fields: [
            .init(key: "template", value: "photo"),
            .init(key: "picture", value: "pic"),
            .init(key: "text", value: "name"),
            .init(key: "grid", value: "pic"),
            .init(key: "grid.2x2", value: "pic pic"),
            .init(key: "grid.2x2", value: "name name")
        ])))

        XCTAssertEqual(template.drawing(for: "1x1"), [["pic"]])
        XCTAssertEqual(template.drawing(for: "2x2"), [["pic", "pic"], ["name", "name"]])
        XCTAssertEqual(template.drawing(for: "3x2"), [["pic", "pic"], ["name", "name"]])
    }

    func testAControlInARowSendsItsSlotAndTheRun() {
        XCTAssertEqual(SpotAction.slot("on", run: "airpods", value: "true").arguments, ["on", "airpods", "true"])
        XCTAssertEqual(SpotAction.slot("quit", run: "/Applications/Safari.app").arguments, ["quit", "/Applications/Safari.app"])
    }

    func testAValueSetInARowShowsBeforeTheAnswer() throws {
        let output = PluginOutput(text: "repeat=devices\n\ntemplate=row\ngrid=name power\ntext=name\nswitch=power\n\nrow=AirPods\nrun=airpods\npower=false\n")
        var list = ItemList(items: output.items)
        list.take(drawing: output.drawing, templates: output.templates)

        list.set("true", of: "power", in: "airpods")

        let item = try XCTUnwrap(list.shown.first)
        XCTAssertEqual(list.template(of: item)?.parts(of: item).last?.control, .toggle(true))
    }

    func testARowGivesSlotsOfTheirOwnSizeTheirWidthAndTheRestToWords() throws {
        let output = PluginOutput(text: apps)
        let safari = try XCTUnwrap(output.items.first)
        let template = try XCTUnwrap(output.template(of: safari))
        let frames = RowPlacement(drawing: template.drawing(), parts: template.parts(of: safari), size: CGSize(width: 260, height: 40)).frames

        XCTAssertEqual(frames["pic"], CGRect(x: 0, y: 0, width: 40, height: 40))
        XCTAssertEqual(frames["quit"], CGRect(x: 220, y: 0, width: 40, height: 40))
        XCTAssertEqual(frames["name"], CGRect(x: 48, y: 0, width: 164, height: 40))
    }

    func testASheetWithNoDrawingShowsItsComponentsThenItsRows() throws {
        let output = PluginOutput(text: "text=note\ntitle=Note\n\nbutton=copy\ntitle=Copy\n\nrow=A\nrun=a\n")

        XCTAssertEqual(output.layout?.rows, [["note"], ["rows"]])
        XCTAssertEqual(output.layout?.repeated?.area, "rows")
        XCTAssertEqual(output.actions.map(\.id), ["copy"])
        XCTAssertTrue(try XCTUnwrap(SheetParts(output: output)).showsRows)
        XCTAssertEqual(output.sheetFaults, [])
    }

    func testAFrameOfComponentsKeepsTheRowsAndAnEmptyRepeatClearsThem() {
        XCTAssertFalse(PluginOutput(text: "switch=power\non=true\n\ntext=note\ntitle=Note\n").replacesRows)
        XCTAssertTrue(PluginOutput(text: "text=note\ntitle=Note\n\nrow=A\nrun=a\n").replacesRows)
        XCTAssertTrue(PluginOutput(text: "text=note\ntitle=Note\n\nrepeat=list\n").replacesRows)
        XCTAssertTrue(PluginOutput(text: "").replacesRows)
    }

    func testASlotCannotTakeTheNameOfAKeyOfARow() {
        let output = PluginOutput(text: "repeat=a\n\ntemplate=row\ngrid=on name\nswitch=on\ntext=name\n\nrow=A\nrun=a\n")

        XCTAssertEqual(output.partFaults, ["the template row has a slot called on, which is a key of a row"])
    }

    func testAFieldSlotHoldsTheTextOfItsRow() throws {
        let output = PluginOutput(text: "repeat=a\n\ntemplate=row\ngrid=name note\ntext=name\nfield=note\n\nrow=A\nrun=a\nnote=Call back\n")
        let row = try XCTUnwrap(output.items.first)

        XCTAssertEqual(output.template(of: row)?.parts(of: row).last?.control, .text("Call back", placeholder: nil, isReadOnly: false))
    }
}
