import XCTest
@testable import OpenspotCore

final class SheetLayoutTests: XCTestCase {
    private func output(_ text: String) -> Frame {
        Frame(text: text)
    }

    private func placement(_ text: String) throws -> SheetPlacement {
        let panel = try XCTUnwrap(SheetParts(output: output(text)))
        return panel.placement
    }

    func testOnlyAMultilineFieldTakesTheFreeHeight() {
        let line = output("frame=\nclass=gap-part\n\nfield=a\ntitle=Name\n\nbutton=b\ntitle=Go\n")
        let multiline = output("frame=\nclass=gap-part\n\nfield=a\ntype=multiline\n\nbutton=b\ntitle=Go\n")

        XCTAssertNil(line.tree.node("a")?.style.grows)
        XCTAssertEqual(multiline.tree.node("a")?.style.grows, true)
    }

    func testTheCheckTakesGrowOnABlock() {
        XCTAssertEqual(FrameCheck(text: "frame=\nclass=gap-part\n\nfield=f\ntype=multiline\ngrow=false\n").partFaults, [])
    }

    func testRowsFitTheRoomTheyAreGivenNotTheWholeSheet() {
        let three = SpotTokens.rowsHeight(rows: 3)

        XCTAssertEqual(three, SpotTokens.listRow * 3 + SpotTokens.listRowGap * 2)
        XCTAssertTrue(SpotTokens.rowsFit(rows: 3))
        XCTAssertFalse(SpotTokens.rowsFit(rows: 3, in: three - 1))
        XCTAssertEqual(SpotTokens.sheetRect(rows: 3).height, SpotTokens.sheetRowsTop + three + SpotTokens.padding)
    }

    func testASheetWithRowsKeepsRoomForTheFieldOnlyWhenItSearches() throws {
        let numbers = "number=cpu\nclass=h-20\nvalue=1\nvalue=2\n\nitems=list\n\ntext=a\nparent=list\ntitle=A\n"
        let still = try XCTUnwrap(SheetParts(output: output("frame=\nclass=gap-part\n\n" + numbers)))
        let searched = try XCTUnwrap(SheetParts(output: output("frame=\nclass=gap-part\n\nfield=find\ntype=search\n\n" + numbers)))

        XCTAssertFalse(still.top.hasField)
        XCTAssertTrue(searched.top.hasField)
        XCTAssertEqual(still.placement.height, SpotTokens.partsMaxHeight)
        XCTAssertEqual(searched.placement.height, SpotTokens.partsMaxHeight - SpotTokens.partFieldRoom)
    }

    func testABlockThatDoesNotGrowKeepsTheHeightOfItsLines() throws {
        let grown = try placement("frame=\nclass=gap-part\n\nfield=note\ntype=multiline\n\nbutton=go\ntitle=Go\n")
        let kept = try placement("frame=\nclass=gap-part\n\nfield=note\ntype=multiline\ngrow=false\n\nbutton=go\ntitle=Go\n")

        XCTAssertEqual(grown.height, SpotTokens.partsMaxHeight)
        XCTAssertLessThan(kept.height, SpotTokens.partsMaxHeight)
    }

    private let picker = """
    frame=
    class=gap-part

    choice=tone
    title=Tone
    value=x

    option=x
    title=X

    items=a
    class=grid grid-cols-7

    text=1
    parent=a
    title=one
    icon=😀
    """

    func testTheItemsTakeTheFreeHeightOfASheetWithNoSearchField() throws {
        let sheet = try placement(picker)

        XCTAssertEqual(sheet.height, SpotTokens.partsMaxHeight)
        XCTAssertFalse(sheet.overflows)
    }

    func testRowsAndPartsShareOneSheet() throws {
        let linesCheck = FrameCheck(text: picker)
        let lines = linesCheck.output

        XCTAssertEqual(lines.items.map(\.glyph), ["😀"])
        XCTAssertEqual(lines.perLine, 7)
        XCTAssertEqual(linesCheck.sheetFaults, [])
        XCTAssertFalse(try XCTUnwrap(SheetParts(output: lines)).takesArrows)
    }

    func testRowsAloneNeedNoLayout() {
        let linesCheck = FrameCheck(text: "items=a\nclass=grid grid-cols-7\n\ntext=1\nparent=a\ntitle=one\nicon=😀\n")
        let lines = linesCheck.output

        XCTAssertEqual(lines.perLine, 7)
        XCTAssertEqual(linesCheck.sheetFaults, [])
        XCTAssertEqual(output("text=1\ntitle=one\n").perLine, nil)
    }

    func testAHotkeyFieldTakesTwoLinesOfTheFullWidth() throws {
        let sheet = try placement("frame=\nclass=gap-part\n\nfield=key\ntype=hotkey\n")

        XCTAssertEqual(sheet.height, 2 * SpotTokens.listRow + SpotTokens.partGap)
    }

    func testAPartStartsWithItsPartKey() throws {
        let first = output("frame=\nclass=gap-part\n\nnumber=job\ntitle=Copying\nvalue=30\nmax=100\n")
        let later = output("frame=\nclass=gap-part\n\nblock=progress\npart=job\ncell=p\ntitle=Copying\nlevel=30\n")

        XCTAssertEqual(first.parts.first?.number?.fill, 0.3)
        XCTAssertEqual(later.parts, [])
        XCTAssertEqual(later.errors, ["block=progress"])
    }

    func testACheckOfOneSheetReportsWhatCannotBeRead() {
        XCTAssertEqual(FrameCheck(text: "frame=\nclass=gap-part\n\ntext=a\ntitle=A\n").sheetFaults, [])
        XCTAssertEqual(FrameCheck(text: "frame=\nclass=gap-part\n\ntitle=A\n\ntext=a\ntitle=A\n").sheetFaults, ["cannot read the block that starts: title=A"])
        XCTAssertEqual(FrameCheck(text: "frame=\nclass=gap-part\n").sheetFaults, ["the sheet has no parts"])
    }

    func testTheLevelOfASliderIsAFaultOutsideItsRange() {
        func faults(_ text: String) -> [String] { FrameCheck(text: text).partFaults }

        XCTAssertEqual(faults("frame=\nclass=gap-part\n\nfield=a\ntype=slider\nvalue=255\n"), ["the part a has a level of 255, outside 0 to 100"])
        XCTAssertEqual(faults("frame=\nclass=gap-part\n\nfield=a\ntype=slider\nvalue=255\nmax=255\n"), [])
    }

    func testAViewNodeGrowsToShareTheFreeHeight() {
        let kinds = BlockKind.kinds(views: ["chart": "/spots/usage.spot/chart.swift"])
        let text = "frame=\nclass=gap-part\n\nchart=chart\npoint=1\n\nbutton=go\ntitle=Go\n"

        XCTAssertEqual(Frame(text: text, kinds: kinds).tree.node("chart")?.style.grows, true)
        XCTAssertEqual(FrameCheck(text: text, kinds: kinds).sheetFaults, [])
    }
}
