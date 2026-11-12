import XCTest
@testable import OpenspotCore

final class SheetLayoutTests: XCTestCase {
    private func output(_ text: String) -> SpotOutput {
        SpotOutput(text: text)
    }

    private func placement(_ text: String) throws -> SheetPlacement {
        let panel = try XCTUnwrap(SheetParts(output: output(text)))
        return panel.placement
    }

    private let pair = """
    grid=source source . .
    grid=input input input input
    grid=input input input swap
    grid=- - - swap
    grid=target target . swap
    grid=output output output output
    grid=output output output copy

    choice=source
    value=en

    option=en
    title=English

    field=input
    value=Hello

    choice=target
    value=ru

    option=ru
    title=Russian

    field=output
    value=Привет
    readonly=true

    button=swap
    icon=arrow.up.arrow.down

    button=copy
    look=chip
    align=right
    title=Copy
    """

    func testALetterFillsTheRectangleAroundItsCells() throws {
        let layout = try XCTUnwrap(SheetLayout(block: TextBlock(fields: [
            .init(key: "grid", value: "a a b"),
            .init(key: "grid", value: "a a b")
        ])))

        XCTAssertEqual(layout.areas["a"], SheetArea(x0: 0, x1: 1, y0: 0, y1: 1))
        XCTAssertEqual(layout.areas["b"], SheetArea(x0: 2, x1: 2, y0: 0, y1: 1))
    }

    func testEveryGapIsOneSizeAcrossAndDown() throws {
        let frames = try placement("""
        grid=a b
        grid=c d

        text=a
        title=A

        text=b
        title=B

        text=c
        title=C

        text=d
        title=D
        """).frames

        let a = try XCTUnwrap(frames["a"]).rect, b = try XCTUnwrap(frames["b"]).rect, c = try XCTUnwrap(frames["c"]).rect
        XCTAssertEqual(b.minX - a.maxX, SheetPlacement.gap)
        XCTAssertEqual(c.minY - a.maxY, SheetPlacement.gap)
        XCTAssertEqual(a.height, SheetPlacement.rowHeight)
    }

    func testTilesHaveTheOneRowHeightAndGap() throws {
        let sheet = try XCTUnwrap(SheetParts(output: SpotOutput(text: "text=a\ntitle=A\nlook=tile\n\ntext=b\ntitle=B\nlook=tile\n"))).placement

        XCTAssertEqual(try XCTUnwrap(sheet.frames["a"]).rect.height, SheetPlacement.rowHeight)
        XCTAssertEqual(try XCTUnwrap(sheet.frames["b"]).rect.minY, SheetPlacement.rowHeight + SheetPlacement.gap)
        XCTAssertEqual(sheet.height, 2 * SheetPlacement.rowHeight + SheetPlacement.gap)
    }

    func testARoundButtonOnALineShrinksToTheRow() throws {
        let frame = try XCTUnwrap(try placement("grid=reload\n\nbutton=reload\ntitle=Reload\nicon=arrow.clockwise\n").frames["reload"])

        XCTAssertEqual(frame.rect.height, SheetPlacement.rowHeight)
        XCTAssertEqual(frame.roundSize, SheetPlacement.rowHeight)
    }

    func testADividerHasOneGapAboveAndBelow() throws {
        let sheet = try placement("""
        grid=a
        grid=-
        grid=b

        text=a
        title=A

        text=b
        title=B
        """)

        let line = try XCTUnwrap(sheet.lines.first)
        XCTAssertEqual(line.minY - (try XCTUnwrap(sheet.frames["a"]).rect.maxY), SheetPlacement.gap)
        XCTAssertEqual((try XCTUnwrap(sheet.frames["b"]).rect.minY) - line.maxY, SheetPlacement.gap)
    }

    func testAPartThatCrossesADividerCentresOnIt() throws {
        let sheet = try placement(pair)
        let swap = try XCTUnwrap(sheet.frames["swap"])

        XCTAssertTrue(swap.isOnTop)
        XCTAssertEqual(swap.vertical, .center)
        XCTAssertEqual(swap.rect.midY, try XCTUnwrap(sheet.lines.first).midY)
        XCTAssertEqual(swap.horizontal, .end)
    }

    func testAPartInACornerHasOneInsetFromBothEdges() throws {
        let sheet = try placement("""
        grid=note note
        grid=note save

        field=note
        value=Hello

        button=save
        icon=checkmark
        """)
        let note = try XCTUnwrap(sheet.frames["note"]), save = try XCTUnwrap(sheet.frames["save"])

        XCTAssertTrue(save.isOnTop)
        XCTAssertEqual((save.horizontal, save.vertical).0, .end)
        XCTAssertEqual(save.vertical, .end)
        XCTAssertEqual(note.rect.maxX - save.rect.maxX, SheetPlacement.gap)
        XCTAssertEqual(note.rect.maxY - save.rect.maxY, SheetPlacement.gap)
    }

    func testTextStepsAwayFromAPartOverItsEdge() throws {
        let sheet = try placement("""
        grid=target target
        grid=output output

        choice=target
        value=a

        option=a
        title=A

        field=output
        value=Hello
        """)
        XCTAssertEqual(try XCTUnwrap(sheet.frames["output"]).clearTop, 0)

        let over = try placement("""
        grid=target output
        grid=output output

        choice=target
        value=a

        option=a
        title=A

        field=output
        value=Hello
        """)
        XCTAssertGreaterThan(try XCTUnwrap(over.frames["output"]).clearTop, 0)
    }

    func testRowsWithTextShareTheFreeHeightAndNoMore() throws {
        let sheet = try placement(pair)

        XCTAssertEqual(sheet.height, SheetPlacement.maxHeight)
        XCTAssertFalse(sheet.overflows)
        XCTAssertGreaterThan(try XCTUnwrap(sheet.frames["input"]).rect.height, SheetPlacement.rowHeight)
        XCTAssertEqual(try XCTUnwrap(sheet.frames["source"]).rect.height, SheetPlacement.rowHeight)
    }

    func testRowsWithOnlyLinesKeepTheirHeight() throws {
        let sheet = try placement("grid=a\ngrid=b\n\ntext=a\ntitle=A\n\ntext=b\ntitle=B\n")

        XCTAssertEqual(sheet.height, 2 * SheetPlacement.rowHeight + SheetPlacement.gap)
    }

    func testTheWordsOfALineSetTheColumns() throws {
        let sheet = try placement("grid=a b b b\n\ntext=a\ntitle=A\n\ntext=b\ntitle=B\n")
        let a = try XCTUnwrap(sheet.frames["a"]).rect, b = try XCTUnwrap(sheet.frames["b"]).rect

        XCTAssertEqual(b.width, 3 * a.width + 2 * SheetPlacement.gap, accuracy: 0.01)
    }

    func testALetterWithNoPartStaysEmpty() {
        XCTAssertEqual(output("grid=a b\n\ntext=a\ntitle=A\n").partFaults, [])
    }

    private let picker = """
    grid=tone tone
    grid=a a

    repeat=a
    grid=a b c d e f g

    choice=tone
    title=Tone
    value=x

    option=x
    title=X

    row=1
    title=one
    icon=😀
    """

    func testARepeatedAreaSharesTheFreeHeightUnderTheField() throws {
        let sheet = try placement(picker)
        let area = try XCTUnwrap(sheet.repeatFrame)

        XCTAssertEqual(area.minY, SheetPlacement.rowHeight + SheetPlacement.gap)
        XCTAssertEqual(sheet.height, SheetPlacement.maxHeight - SheetPlacement.fieldRoom)
        XCTAssertEqual(area.maxY, sheet.height)
        XCTAssertFalse(sheet.overflows)
    }

    func testRowsAndPartsShareOneSheet() throws {
        let lines = output(picker)

        XCTAssertEqual(lines.items.map(\.glyph), ["😀"])
        XCTAssertEqual(lines.perLine, 7)
        XCTAssertEqual(lines.sheetFaults, [])
        XCTAssertFalse(try XCTUnwrap(SheetParts(output: lines)).takesArrows)
    }

    func testRowsAloneNeedNoDrawing() {
        let lines = output("repeat=a\ngrid=a b c d e f g\n\nrow=1\ntitle=one\nicon=😀\n")

        XCTAssertEqual(lines.perLine, 7)
        XCTAssertEqual(lines.sheetFaults, [])
        XCTAssertEqual(output("row=1\ntitle=one\n").perLine, nil)
    }

    func testTheFaultsOfARepeat() {
        func faults(_ text: String) -> [String] { output(text).partFaults }
        let part = "\n\ntext=a\ntitle=A\n"

        XCTAssertEqual(faults("grid=a\n\nrepeat=z\ngrid=x y" + part), ["the repeat names z, which the drawing does not have"])
        XCTAssertEqual(faults("grid=a\ngrid=b\n\nrepeat=a\ngrid=x y" + part), ["the part a stands on the repeated area a", "the part a sits in rows that stretch, so draw a choice over two lines for a list"])
        XCTAssertEqual(faults("grid=a\ngrid=b\ngrid=c\n\nrepeat=b\n\nrepeat=c" + part), ["a sheet can repeat only one area"])
    }

    func testASheetWithNoDrawingIsOneColumnOfLines() throws {
        let sheet = try placement("""
        section=lights
        title=Lights

        switch=left
        title=Left
        value=false

        section=power
        title=Power

        text=battery
        title=Battery
        detail=68%
        """)

        XCTAssertEqual(sheet.lines.count, 1)
        XCTAssertEqual(try XCTUnwrap(sheet.frames["left"]).rect.width, SheetPlacement.width)
    }

    func testAPartStartsWithItsPartKey() throws {
        let first = output("grid=job\ngrid=job\n\ngauge=job\ntitle=Copying\nvalue=0.3\n")
        let later = output("grid=p\ngrid=p\n\nblock=progress\npart=job\ncell=p\ntitle=Copying\nlevel=30\n")

        XCTAssertEqual(first.parts.first?.control, .progress(level: 30))
        XCTAssertEqual(later.parts, [])
        XCTAssertEqual(later.errors, ["block=progress"])
    }

    func testTheFaultsOfADrawing() {
        func faults(_ text: String) -> [String] { output(text).partFaults }

        XCTAssertEqual(faults("grid=a b\ngrid=a\n\ntext=a\ntitle=A\n\ntext=b\ntitle=B\n"), ["each grid line needs the same number of columns"])
        XCTAssertEqual(faults("grid=a\n\ntext=a\ntitle=A\n\ntext=b\ntitle=B\n"), ["the part b is not in the drawing"])
        XCTAssertEqual(faults("grid=a\ngrid.small=b\n\ntext=a\ntitle=A\n\ntext=b\ntitle=B\n"), [])
        XCTAssertEqual(faults("grid=a\n\ntext=a\ntitle=A\n\ntext=a\ntitle=B\n"), ["two parts are called a"])
        XCTAssertEqual(faults("grid=a b\n\nbutton=a\nlook=strong\nicon=play\n\nbutton=b\nlook=strong\nicon=stop\n"), ["only one part can use look=strong"])
        XCTAssertEqual(faults("grid=a - b\n\ntext=a\ntitle=A\n\ntext=b\ntitle=B\n"), ["the divider in row 1 is not whole"])
        XCTAssertEqual(faults("grid=a b\ngrid=b a\n\ntext=a\ntitle=A\n\ntext=b\ntitle=B\n"), ["a and b overlap at one size, so neither lies on top"])
        XCTAssertEqual(faults("layout=pair\n\ntext=a\ntitle=A\n"), ["a sheet has no layout key, so draw it with grid= lines"])
    }

    func testACheckOfOneSheetReportsWhatCannotBeRead() {
        XCTAssertEqual(output("grid=a\n\ntext=a\ntitle=A\n").sheetFaults, [])
        XCTAssertEqual(output("grid=a\n\ntitle=A\n\ntext=a\ntitle=A\n").sheetFaults, ["cannot read the block that starts: title=A"])
        XCTAssertEqual(output("grid=a\n").sheetFaults, ["the sheet has no parts"])
    }

    func testTheFaultsThatComeFromSize() {
        func faults(_ text: String) -> [String] { output(text).partFaults }

        XCTAssertEqual(faults("slider=a\nvalue=255\n"), ["the part a has a level of 255, outside 0 to 100"])
        XCTAssertEqual(faults("slider=a\nvalue=255\nmax=255\n"), [])
        XCTAssertEqual(faults("grid=a b c d\ngrid=a b c d\n\nnumber=a\nvalue=1\n\ntext=b\ntitle=B\n\ntext=c\ntitle=C\n\ntext=d\ntitle=D\n"), ["the part a needs at least 2 columns of 4 for its number"])
        XCTAssertEqual(faults("grid=a a\n\nnumber=a\nvalue=1\ntitle=CPU\n"), ["the part a needs at least 2 rows for its number and title"])
        XCTAssertEqual(faults("grid=p p\n\ngauge=p\nvalue=0.01\n"), ["the part p needs at least 2 rows for its title and bar"])
        XCTAssertEqual(faults("grid=a b c d\n\ntext=a\ntitle=A very long title indeed\n\ntext=b\ntitle=B\n\ntext=c\ntitle=C\n\ntext=d\ntitle=D\n"), ["the title of the part a may not fit its cell"])
        XCTAssertEqual(faults("grid=a b\ngrid=t b\n\ntext=a\ntitle=Item\n\ntext=t\ntitle=Other\n\nfield=b\nvalue=Hi\n"), ["the part a sits in rows that stretch, so draw a choice over two lines for a list", "the part t sits in rows that stretch, so draw a choice over two lines for a list"])
        XCTAssertEqual(faults(String(repeating: "grid=a\n", count: 20) + "\nfield=a\nvalue=Hi\n"), ["the drawing is too tall: 914pt of 442pt"])
    }

    func testAViewFillsItsAreaOfASheetAndSharesTheFreeHeight() throws {
        let sheet = try placement("grid=chart chart\ngrid=chart chart\ngrid=go go\n\nview=chart\npoint=1\n\nbutton=go\ntitle=Go\n")
        let frame = try XCTUnwrap(sheet.frames["chart"])

        XCTAssertEqual(frame.vertical, .fill)
        XCTAssertGreaterThan(frame.rect.height, SheetPlacement.rowHeight * 2)
        XCTAssertEqual(output("grid=chart\n\nview=chart\n").sheetFaults, [])
    }

}
