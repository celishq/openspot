import XCTest
@testable import OpenspotCore

final class ViewTreePartsTests: XCTestCase {
    private let kinds = BlockKind.all + [BlockKind(view: "liquid", source: "/spots/liquid.swift")]

    func testAViewNodeWithNoSizeClassTakesTheFreeHeight() {
        let tree = Frame(text: "frame=\nclass=gap-2\n\nliquid=fill\nvalue=84\n\nliquid=low\nclass=h-24\n", kinds: kinds).tree

        XCTAssertEqual(tree.node("fill")?.style.grows, true)
        XCTAssertNil(tree.node("low")?.style.grows)
    }

    func testARepeatedKeyOnAViewNodeIsNoFault() {
        let text = "liquid=fill\nlevel=1\nlevel=2\n\ntext=b\ntitle=B\ntitle=C\n"

        XCTAssertEqual(SpotCheck.brokenBlocks(in: text, kinds: kinds).count, 1)
        XCTAssertTrue(SpotCheck.brokenBlocks(in: text, kinds: kinds)[0].hasPrefix("the block text=b has title twice"))
    }

    func testTheRowsThatAViewNodeGetsCarryTheirBlocks() throws {
        let text = "frame=\nclass=gap-2\n\nliquid=fill\n\nitems=list\n\nitem=a\nparent=list\ntitle=A\n"
        let output = Frame(text: text, kinds: kinds)

        XCTAssertNotNil(output.tree.node("fill")?.source)
        XCTAssertEqual(output.rows, [["item", "a", "parent", "list", "title", "A"]])
    }

    func testTheCheckOfATreeChecksEachNodeAsAPart() {
        let text = "frame=\nclass=gap-2\n\ntext=a\ntitle=A\ntone=blue\n\nbutton=go\ntitle=Go\nlook=round\n\nswitch=show\nvalue=true\n"
        let faults = FrameCheck(text: text).partFaults

        XCTAssertTrue(faults.contains("the part a has an unknown tone: blue"), "\(faults)")
        XCTAssertTrue(faults.contains("the part go has an unknown key: look"), "\(faults)")
        XCTAssertTrue(faults.contains("a part cannot be called show"), "\(faults)")
        XCTAssertFalse(faults.contains("an item cannot be called show"), "\(faults)")
    }

    func testAButtonWithAScopeIsAnActionWhereverItSits() {
        let frame = Frame(text: "frame=\nclass=gap-2\n\nbutton=copy\ntitle=Copy\nscope=item\n\nbutton=go\ntitle=Go\n")

        XCTAssertEqual(frame.actions.map(\.id), ["copy"])
        XCTAssertEqual(frame.parts.map(\.id), ["go"])
        XCTAssertNil(frame.tree.node("copy"))
    }

    func testATreeSearchesItsItemsOnlyWithASearchField() {
        let bare = Frame(text: "frame=\nclass=gap-2\n\nitems=list\n\ntext=a\nparent=list\ntitle=A\n")
        let searched = Frame(text: "frame=\nclass=gap-2\n\nfield=find\ntype=search\n\nitems=list\n\ntext=a\nparent=list\ntitle=A\n")

        XCTAssertEqual(bare.search, .off)
        XCTAssertEqual(searched.search, .local)
        XCTAssertEqual(Frame(text: "text=a\ntitle=A\n").search, .local)
    }

    func testASearchFieldWithNoItemsShowsTheSearchInItsPlace() throws {
        let output = Frame(text: "frame=\nclass=gap-part\n\nfield=find\ntype=search\n\ntext=a\ntitle=A\n")
        let sheet = try XCTUnwrap(SheetParts(output: output))

        XCTAssertTrue(sheet.placesSearch)
        XCTAssertFalse(sheet.top.hasField)
        XCTAssertTrue(sheet.showsRows)
        XCTAssertEqual(sheet.top.partsRoom, SpotTokens.partsMaxHeight)
    }

    func testATreeSheetIsAsTallAsItsTree() throws {
        let short = try XCTUnwrap(SheetParts(output: Frame(text: "frame=\nclass=gap-part\n\nswitch=a\ntitle=A\n\nswitch=b\ntitle=B\n")))
        let listed = try XCTUnwrap(SheetParts(output: Frame(text: "frame=\nclass=gap-part\n\nswitch=a\ntitle=A\n\nitems=list\n\ntext=b\nparent=list\ntitle=B\n")))

        XCTAssertEqual(short.height, 2 * SpotTokens.listRow + SpotTokens.partGap)
        XCTAssertEqual(listed.height, listed.top.partsRoom)
    }

    func testAViewPinnedOverItsBoxFillsTheSheet() throws {
        let panel = try XCTUnwrap(SheetParts(output: Frame(text: "frame=\nclass=relative\n\nliquid=level\nclass=absolute inset-0\nvalue=0.7\n", kinds: kinds)))

        XCTAssertEqual(panel.height, panel.top.partsRoom)
    }

    func testAMultilineFieldTakesTheFreeHeightAndGrowWorksOnANode() {
        let tree = Frame(text: "frame=\nclass=gap-2\n\nfield=note\ntype=multiline\n\nfield=short\ntype=multiline\ngrow=false\n\nfield=name\n\ntext=a\ntitle=A\ngrow=true\n").tree

        XCTAssertEqual(tree.node("note")?.style.grows, true)
        XCTAssertEqual(tree.node("short")?.style.grows, false)
        XCTAssertNil(tree.node("name")?.style.grows)
        XCTAssertEqual(tree.node("a")?.style.grows, true)
    }

    func testAFieldWithNoTypeIsOneLineAndAMultilineFieldHoldsSeveral() throws {
        let parts = Frame(text: "frame=\nclass=gap-2\n\nfield=name\nvalue=Ann\n\nfield=note\ntype=multiline\nvalue=a\\nb\n").parts

        XCTAssertEqual(parts.map(\.isMultiline), [false, true])
        XCTAssertEqual(parts.map(\.fillsHeight), [false, true])
    }

    func testANodeHiddenInTheSheetIsNoPartOfTheSheet() {
        let frame = Frame(text: "frame=\nclass=gap-2\n\nswitch=a\ntitle=A\nclass=hidden card:flex\n\nswitch=b\ntitle=B\n")

        XCTAssertEqual(frame.parts.map(\.id), ["b"])
        XCTAssertEqual(frame.face.parts.map(\.id), ["a", "b"])
    }

    func testANodeHiddenInTheSheetTakesNoGap() throws {
        let hidden = try XCTUnwrap(SheetParts(output: Frame(text: "frame=\nclass=gap-8\n\nswitch=a\ntitle=A\n\ntext=b\ntitle=B\nclass=hidden wide:flex\n\nswitch=c\ntitle=C\nclass=sheet:hidden\n\nswitch=d\ntitle=D\n")))
        let shown = try XCTUnwrap(SheetParts(output: Frame(text: "frame=\nclass=gap-8\n\nswitch=a\ntitle=A\n\nswitch=d\ntitle=D\n")))

        XCTAssertEqual(hidden.height, shown.height)
    }

    func testAChoiceIsAListOnlyByItsTypeAndAMenuWithoutOne() {
        let options = "option=x\ntitle=X\n\noption=y\ntitle=Y\n"
        let frame = Frame(text: "frame=\nclass=gap-2\n\nchoice=tall\nclass=h-24\n\n\(options)\nchoice=grown\nclass=grow\n\n\(options)\nchoice=list\ntype=list\n\n\(options)")
        let control = { (id: String) in frame.parts.first { $0.id == id }?.control }

        XCTAssertEqual(control("tall"), .menu([.init(id: "x", title: "X"), .init(id: "y", title: "Y")], value: nil))
        XCTAssertEqual(control("grown"), .menu([.init(id: "x", title: "X"), .init(id: "y", title: "Y")], value: nil))
        XCTAssertEqual(control("list"), .list([.init(id: "x", title: "X"), .init(id: "y", title: "Y")], value: nil))
    }
}
