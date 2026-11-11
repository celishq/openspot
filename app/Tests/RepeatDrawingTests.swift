import XCTest
@testable import OpenspotCore

final class RepeatDrawingTests: XCTestCase {
    private let apps = """
    repeat=apps

    row=/Applications/Safari.app
    title=Safari
    icon=/Applications/Safari.app
    value=true

    row=/Applications/Notes.app
    title=Notes
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
        let output = PluginOutput(text: "grid=tone\ngrid=a\n\nrepeat=a\ngrid=a b c d e f g\n\nchoice=tone\n\noption=none\ntitle=Yellow\n\nrow=x\ntitle=x\n")

        XCTAssertEqual(output.drawing.perLine, 7)
        XCTAssertEqual(output.perLine, 7)
        XCTAssertEqual(output.sheetFaults, [])
    }

    func testABentoTileRepeatsDown() {
        let drawing = RepeatDrawing(lines: [["a", "a", "b", "c"], ["a", "a", "d", "e"]])

        XCTAssertNil(drawing.perLine)
        XCTAssertEqual(drawing.places.count, 5)
        XCTAssertEqual(drawing.area(of: 0), SheetArea(x0: 0, x1: 1, y0: 0, y1: 1))
        XCTAssertEqual(drawing.area(of: 6), SheetArea(x0: 2, x1: 2, y0: 2, y1: 2))
        XCTAssertEqual(drawing.lineCount(rows: 6), 4)
        XCTAssertEqual(drawing.lineCount(rows: 2), 2)
    }

    func testASheetWithNoDrawingShowsItsComponentsThenItsRows() throws {
        let output = PluginOutput(text: "text=note\ntitle=Note\n\nbutton=copy\ntitle=Copy\n\nrow=a\ntitle=A\n")

        XCTAssertEqual(output.layout?.rows, [["note"], ["rows"]])
        XCTAssertEqual(output.layout?.repeated?.area, "rows")
        XCTAssertEqual(output.actions.map(\.id), ["copy"])
        XCTAssertTrue(try XCTUnwrap(SheetParts(output: output)).showsRows)
        XCTAssertEqual(output.sheetFaults, [])
    }
}
