import XCTest
@testable import OpenspotCore

final class SheetLayoutTests: XCTestCase {
    private func output(_ text: String) -> PluginOutput {
        PluginOutput(text: text)
    }

    private func placement(_ text: String) throws -> SheetPlacement {
        let panel = try XCTUnwrap(SpotPanel(output: output(text)))
        return panel.placement
    }

    private let pair = """
    layout=pair

    part=source
    cell=from
    option=en:English
    value=en

    part=input
    cell=top
    text=Hello

    part=target
    cell=to
    option=ru:Russian
    value=ru

    part=output
    cell=bottom
    text=Привет
    readonly=true

    part=swap
    cell=swap
    press=arrow.up.arrow.down

    part=copy
    cell=action
    look=chip
    align=right
    title=Copy
    press=true
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

        part=a
        cell=a
        title=A

        part=b
        cell=b
        title=B

        part=c
        cell=c
        title=C

        part=d
        cell=d
        title=D
        """).frames

        let a = try XCTUnwrap(frames["a"]).rect, b = try XCTUnwrap(frames["b"]).rect, c = try XCTUnwrap(frames["c"]).rect
        XCTAssertEqual(b.minX - a.maxX, SheetPlacement.gap)
        XCTAssertEqual(c.minY - a.maxY, SheetPlacement.gap)
        XCTAssertEqual(a.height, SheetPlacement.rowHeight)
    }

    func testARowOfKeysSetsTheHeightOfEveryRow() throws {
        let sheet = try placement("""
        grid=v v
        keys=1 2
        keys=0 0

        part=value
        cell=v
        metric=1
        """)

        XCTAssertEqual(try XCTUnwrap(sheet.frames["value"]).rect.height, SheetPlacement.keyRowHeight)
        XCTAssertEqual(try XCTUnwrap(sheet.frames["1"]).rect.height, SheetPlacement.keyRowHeight)
        XCTAssertEqual(try XCTUnwrap(sheet.frames["0"]).rect.width, SheetPlacement.width)
    }

    func testARoundButtonOnALineShrinksToTheRow() throws {
        let frame = try XCTUnwrap(try placement("part=reload\ntitle=Reload\npress=arrow.clockwise\n").frames["reload"])

        XCTAssertEqual(frame.rect.height, SheetPlacement.rowHeight)
        XCTAssertEqual(frame.roundSize, SheetPlacement.rowHeight)
    }

    func testADividerHasOneGapAboveAndBelow() throws {
        let sheet = try placement("""
        grid=a
        grid=-
        grid=b

        part=a
        cell=a
        title=A

        part=b
        cell=b
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
        grid=t t
        grid=t c

        part=note
        cell=t
        text=Hello

        part=save
        cell=c
        press=checkmark
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
        grid=d d
        grid=b b

        part=target
        cell=d
        option=a:A
        value=a

        part=output
        cell=b
        text=Hello
        """)
        XCTAssertEqual(try XCTUnwrap(sheet.frames["output"]).clearTop, 0)

        let over = try placement("""
        grid=d b
        grid=b b

        part=target
        cell=d
        option=a:A
        value=a

        part=output
        cell=b
        text=Hello
        """)
        XCTAssertGreaterThan(try XCTUnwrap(over.frames["output"]).clearTop, 0)
    }

    func testFillTakesTheFreeHeightAndNoMore() throws {
        let sheet = try placement(pair)

        XCTAssertEqual(sheet.height, SheetPlacement.maxHeight)
        XCTAssertFalse(sheet.overflows)
        XCTAssertGreaterThan(try XCTUnwrap(sheet.frames["input"]).rect.height, SheetPlacement.rowHeight)
    }

    func testPartsInACardSitInsideItByOneEdge() throws {
        let sheet = try placement(pair)
        let card = try XCTUnwrap(sheet.cards.first), source = try XCTUnwrap(sheet.frames["source"])

        XCTAssertEqual(source.rect.minX - card.minX, SheetPlacement.edge)
        XCTAssertEqual(source.rect.minY - card.minY, SheetPlacement.edge)
        XCTAssertTrue(source.isInCard)
    }

    func testANamedLayoutIsADrawingWithNamedCells() throws {
        XCTAssertEqual(output(pair).partFaults, [])
        let layout = try XCTUnwrap(output(pair).layout)

        XCTAssertEqual(layout.letter(of: try XCTUnwrap(output(pair).parts.first)), "s")
        XCTAssertEqual(layout.rows[3], ["-", "-", "-", "x"])
    }

    func testANamedLayoutCanLeaveACellEmpty() {
        XCTAssertEqual(output("layout=pair\n\npart=input\ncell=top\ntext=Hi\n").partFaults, [])
    }

    func testASheetWithNoDrawingIsOneColumnOfLines() throws {
        let sheet = try placement("""
        section=lights
        title=Lights
        on=true

        part=left
        title=Left
        on=false

        section=power
        title=Power

        part=battery
        title=Battery
        detail=68%
        """)

        XCTAssertEqual(sheet.lines.count, 1)
        XCTAssertEqual(try XCTUnwrap(sheet.frames["left"]).rect.width, SheetPlacement.width)
    }

    func testKeysAreCalledByTheirWords() throws {
        let parts = output("grid=v v\nkeys=. -\n\npart=value\ncell=v\nmetric=0\n").parts

        XCTAssertEqual(parts.map(\.id), ["value", ".", "-"])
        XCTAssertEqual(parts[1].press, .line)
        XCTAssertEqual(parts[1].title, ".")
        XCTAssertEqual(parts[2].look, .key)
    }

    func testAPartCanStartWithAnyKey() throws {
        let parts = output("grid=p\ngrid=p\n\nblock=progress\npart=job\ncell=p\ntitle=Copying\nlevel=30\n").parts

        XCTAssertEqual(parts.first?.control, .progress(level: 30))
    }

    func testTheFaultsOfADrawing() {
        func faults(_ text: String) -> [String] { output(text).partFaults }

        XCTAssertEqual(faults("grid=a b\ngrid=a\n\npart=a\ncell=a\ntitle=A\n\npart=b\ncell=b\ntitle=B\n"), ["each grid line needs the same number of columns"])
        XCTAssertEqual(faults("grid=a b\n\npart=a\ncell=a\ntitle=A\n"), ["the letter b has no part"])
        XCTAssertEqual(faults("grid=a\n\npart=a\ncell=a\ntitle=A\n\npart=b\ntitle=B\n"), ["the part b has no cell"])
        XCTAssertEqual(faults("grid=a\n\npart=a\ncell=a\ntitle=A\n\npart=b\ncell=c\ntitle=B\n"), ["the part b names the cell c, which the drawing does not have"])
        XCTAssertEqual(faults("grid=a\n\npart=a\ncell=a\ntitle=A\n\npart=b\ncell=a\ntitle=B\n"), ["the parts a and b share the cell a"])
        XCTAssertEqual(faults("grid=a\ncard=a z\n\npart=a\ncell=a\ntitle=A\n"), ["the card names z, which the drawing does not have"])
        XCTAssertEqual(faults("grid=a b\n\npart=a\ncell=a\nlook=strong\npress=play\n\npart=b\ncell=b\nlook=strong\npress=stop\n"), ["only one part can use look=strong"])
        XCTAssertEqual(faults("grid=a - b\n\npart=a\ncell=a\ntitle=A\n\npart=b\ncell=b\ntitle=B\n"), ["the divider in row 1 is not whole"])
        XCTAssertEqual(faults("grid=a b\ngrid=b a\n\npart=a\ncell=a\ntitle=A\n\npart=b\ncell=b\ntitle=B\n"), ["a and b overlap at one size, so neither lies on top"])
        XCTAssertEqual(faults("layout=nope\n\npart=a\ntitle=A\n"), ["there is no layout called nope"])
        XCTAssertEqual(faults("layout=pair\n\npart=a\ncell=nope\ntitle=A\n"), ["the part a names the cell nope, which the layout pair does not have"])
    }

    func testACheckOfOneSheetReportsWhatCannotBeRead() {
        XCTAssertEqual(output("grid=a\n\npart=a\ncell=a\ntitle=A\n").sheetFaults, [])
        XCTAssertEqual(output("grid=a\n\ntitle=A\n\npart=a\ncell=a\ntitle=A\n").sheetFaults, ["cannot read the block that starts: title=A"])
        XCTAssertEqual(output("grid=a\n").sheetFaults, ["the sheet has no parts"])
    }

    func testTheFaultsThatComeFromSize() {
        func faults(_ text: String) -> [String] { output(text).partFaults }

        XCTAssertEqual(faults("part=a\nlevel=255\n"), ["the part a has a level of 255, outside 0 to 100"])
        XCTAssertEqual(faults("part=a\nlevel=255\nmax=255\n"), [])
        XCTAssertEqual(faults("grid=a b c d\ngrid=a b c d\n\npart=a\ncell=a\nmetric=1\n\npart=b\ncell=b\ntitle=B\n\npart=c\ncell=c\ntitle=C\n\npart=d\ncell=d\ntitle=D\n"), ["the part a needs at least 2 columns of 4 for its number"])
        XCTAssertEqual(faults("grid=a a\n\npart=a\ncell=a\nmetric=1\ntitle=CPU\n"), ["the part a needs at least 2 rows for its number and title"])
        XCTAssertEqual(faults("grid=p p\n\npart=p\ncell=p\nblock=progress\nlevel=1\n"), ["the part p needs at least 2 rows for its title and bar"])
        XCTAssertEqual(faults("grid=a b c d\n\npart=a\ncell=a\ntitle=A very long title indeed\n\npart=b\ncell=b\ntitle=B\n\npart=c\ncell=c\ntitle=C\n\npart=d\ncell=d\ntitle=D\n"), ["the title of the part a may not fit its cell"])
        XCTAssertEqual(faults("grid=a b\ngrid=t b\n\npart=a\ncell=a\ntitle=Item\n\npart=t\ncell=t\ntitle=Other\n\npart=b\ncell=b\ntext=Hi\nfill=true\n"), ["the part a sits in rows that stretch, so use item= for a list", "the part t sits in rows that stretch, so use item= for a list"])
        XCTAssertEqual(faults(String(repeating: "grid=a\n", count: 20) + "\npart=a\ncell=a\ntext=Hi\n"), ["the drawing is too tall: 712pt of 442pt"])
    }
}
