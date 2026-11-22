import XCTest
@testable import OpenspotCore

final class RepeatDrawingTests: XCTestCase {
    private let apps = """
    items=apps

    text=/Applications/Safari.app
    parent=apps
    title=Safari
    icon=/Applications/Safari.app
    value=true

    text=/Applications/Notes.app
    parent=apps
    title=Notes
    hides=quit
    """

    func testItemsWithNoClassesAreAList() {
        let output = Frame(text: apps)

        XCTAssertEqual(output.drawing, .list)
        XCTAssertEqual(output.perLine, 1)
        XCTAssertEqual(output.layout?.repeated?.area, "apps")
        XCTAssertEqual(output.items.map(\.title), ["Safari", "Notes"])
    }

    func testItemsInAGridOfColumnsAreTiles() {
        let outputCheck = FrameCheck(text: "frame=\nclass=gap-part\n\nchoice=tone\n\noption=none\ntitle=Yellow\n\nitems=a\nclass=grid grid-cols-7\n\ntext=x\nparent=a\ntitle=x\n")
        let output = outputCheck.output

        XCTAssertEqual(output.drawing.perLine, 7)
        XCTAssertEqual(output.perLine, 7)
        XCTAssertEqual(outputCheck.sheetFaults, [])
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

    func testTheItemsShowUnderTheBlocksBeforeThem() throws {
        let outputCheck = FrameCheck(text: "frame=\nclass=gap-part\n\ntext=note\ntitle=Note\n\nitems=list\n\nbutton=copy\nparent=list\ntitle=Copy\n\ntext=a\nparent=list\ntitle=A\n")
        let output = outputCheck.output

        XCTAssertEqual(output.layout?.rows, [["note"], ["list"]])
        XCTAssertEqual(output.layout?.repeated?.area, "list")
        XCTAssertEqual(output.actions.map(\.id), ["copy"])
        XCTAssertTrue(try XCTUnwrap(SheetParts(output: output)).showsRows)
        XCTAssertEqual(outputCheck.sheetFaults, [])
    }
}
