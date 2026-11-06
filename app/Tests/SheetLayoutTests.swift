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
    grid=s s . .
    grid=i i i i
    grid=i i i x
    grid=- - - x
    grid=t t . x
    grid=o o o o
    grid=o o o c
    card=s i t o

    part=source
    cell=s
    option=en:English
    value=en

    part=input
    cell=i
    text=Hello

    part=target
    cell=t
    option=ru:Russian
    value=ru

    part=output
    cell=o
    text=Привет
    readonly=true

    part=swap
    cell=x
    press=arrow.up.arrow.down

    part=copy
    cell=c
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

    func testARowOfKeysHasTheOneRowHeight() throws {
        let sheet = try placement("""
        grid=v v
        keys=1 2
        keys=0 0

        part=value
        cell=v
        metric=1
        """)

        XCTAssertEqual(try XCTUnwrap(sheet.frames["value"]).rect.height, SheetPlacement.rowHeight)
        XCTAssertEqual(try XCTUnwrap(sheet.frames["1"]).rect.height, SheetPlacement.rowHeight)
        XCTAssertEqual(try XCTUnwrap(sheet.frames["0"]).rect.width, SheetPlacement.width)
    }

    func testTilesHaveTheOneRowHeightAndGap() throws {
        let sheet = try XCTUnwrap(SpotPanel(output: PluginOutput(text: "part=a\ntitle=A\nlook=tile\n\npart=b\ntitle=B\nlook=tile\n"))).placement

        XCTAssertEqual(try XCTUnwrap(sheet.frames["a"]).rect.height, SheetPlacement.rowHeight)
        XCTAssertEqual(try XCTUnwrap(sheet.frames["b"]).rect.minY, SheetPlacement.rowHeight + SheetPlacement.gap)
        XCTAssertEqual(sheet.height, 2 * SheetPlacement.rowHeight + SheetPlacement.gap)
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

    func testRowsWithTextShareTheFreeHeightAndNoMore() throws {
        let sheet = try placement(pair)

        XCTAssertEqual(sheet.height, SheetPlacement.maxHeight)
        XCTAssertFalse(sheet.overflows)
        XCTAssertGreaterThan(try XCTUnwrap(sheet.frames["input"]).rect.height, SheetPlacement.rowHeight)
        XCTAssertEqual(try XCTUnwrap(sheet.frames["source"]).rect.height, SheetPlacement.rowHeight)
    }

    func testRowsWithOnlyLinesKeepTheirHeight() throws {
        let sheet = try placement("grid=a\ngrid=b\n\npart=a\ncell=a\ntitle=A\n\npart=b\ncell=b\ntitle=B\n")

        XCTAssertEqual(sheet.height, 2 * SheetPlacement.rowHeight + SheetPlacement.gap)
    }

    func testTheWordsOfALineSetTheColumns() throws {
        let sheet = try placement("grid=a b b b\n\npart=a\ncell=a\ntitle=A\n\npart=b\ncell=b\ntitle=B\n")
        let a = try XCTUnwrap(sheet.frames["a"]).rect, b = try XCTUnwrap(sheet.frames["b"]).rect

        XCTAssertEqual(b.width, 3 * a.width + 2 * SheetPlacement.gap, accuracy: 0.01)
    }

    func testPartsInACardSitInsideItByOneEdge() throws {
        let sheet = try placement(pair)
        let card = try XCTUnwrap(sheet.cards.first), source = try XCTUnwrap(sheet.frames["source"])

        XCTAssertEqual(source.rect.minX - card.minX, SheetPlacement.edge)
        XCTAssertEqual(source.rect.minY - card.minY, SheetPlacement.edge)
        XCTAssertTrue(source.isInCard)
    }

    func testALetterWithNoPartStaysEmpty() {
        XCTAssertEqual(output("grid=a b\n\npart=a\ncell=a\ntitle=A\n").partFaults, [])
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
        XCTAssertEqual(faults("grid=a\n\npart=a\ncell=a\ntitle=A\n\npart=b\ntitle=B\n"), ["the part b has no cell"])
        XCTAssertEqual(faults("grid=a\n\npart=a\ncell=a\ntitle=A\n\npart=b\ncell=c\ntitle=B\n"), ["the part b names the cell c, which the drawing does not have"])
        XCTAssertEqual(faults("grid=a\n\npart=a\ncell=a\ntitle=A\n\npart=b\ncell=a\ntitle=B\n"), ["the parts a and b share the cell a"])
        XCTAssertEqual(faults("grid=a\ncard=a z\n\npart=a\ncell=a\ntitle=A\n"), ["the card names z, which the drawing does not have"])
        XCTAssertEqual(faults("grid=a b\n\npart=a\ncell=a\nlook=strong\npress=play\n\npart=b\ncell=b\nlook=strong\npress=stop\n"), ["only one part can use look=strong"])
        XCTAssertEqual(faults("grid=a - b\n\npart=a\ncell=a\ntitle=A\n\npart=b\ncell=b\ntitle=B\n"), ["the divider in row 1 is not whole"])
        XCTAssertEqual(faults("grid=a b\ngrid=b a\n\npart=a\ncell=a\ntitle=A\n\npart=b\ncell=b\ntitle=B\n"), ["a and b overlap at one size, so neither lies on top"])
        XCTAssertEqual(faults("layout=pair\n\npart=a\ntitle=A\n"), ["a sheet has no layout key, so draw it with grid= lines"])
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
        XCTAssertEqual(faults("grid=a b\ngrid=t b\n\npart=a\ncell=a\ntitle=Item\n\npart=t\ncell=t\ntitle=Other\n\npart=b\ncell=b\ntext=Hi\n"), ["the part a sits in rows that stretch, so use item= for a list", "the part t sits in rows that stretch, so use item= for a list"])
        XCTAssertEqual(faults(String(repeating: "grid=a\n", count: 20) + "\npart=a\ncell=a\ntext=Hi\n"), ["the drawing is too tall: 914pt of 442pt"])
    }
}
