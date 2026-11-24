import XCTest
@testable import OpenspotCore

final class ViewTreeTests: XCTestCase {
    private let wifi = """
    frame=
    class=gap-3 p-3

    box=head
    class=flex-row items-center gap-2

    picture=wifi
    parent=head
    icon=wifi
    class=text-accent

    text=name
    parent=head
    title=Home
    detail=82 Mb/s
    class=grow

    button=forget
    parent=head
    title=Forget
    class=rounded-full

    text=note
    title=Saved
    """

    private func patched(_ patch: String, after base: String) -> ViewTree {
        let drawn = FrameStream(base, after: nil).drawn
        return Frame(text: FrameStream(patch, after: drawn).text).tree
    }

    func testEachBlockSitsInTheNodeItsParentNamesInTheOrderOfItsLines() {
        let tree = Frame(text: wifi).tree

        XCTAssertTrue(tree.isWritten)
        XCTAssertEqual(tree.style, Style(classes: "gap-3 p-3"))
        XCTAssertEqual(tree.children, ["head", "note"])
        XCTAssertEqual(tree.node("head")?.kind, .box)
        XCTAssertEqual(tree.node("head")?.style.arrangement, .row)
        XCTAssertEqual(tree.node("head")?.children, ["wifi", "name", "forget"])
        XCTAssertEqual(tree.node("name")?.parent, "head")
        XCTAssertEqual(tree.node("name")?.style.grows, true)
        XCTAssertEqual(tree.node("name")?.block.value("title"), "Home")
        XCTAssertNil(tree.node("note")?.parent)
        XCTAssertTrue(tree.faults.isEmpty)
    }

    private let battery = """
    frame=
    class=relative

    liquid=level
    class=absolute inset-0
    value=0.72
    tone=good

    text=words
    title=72%
    """

    func testAViewOfTheSpotIsAKindOfNodeThatHoldsItsKeysAndItsSource() throws {
        let kinds = BlockKind.all + [BlockKind(view: "liquid", source: "/spots/liquid.swift")]
        let tree = Frame(text: battery, kinds: kinds).tree
        let level = try XCTUnwrap(tree.node("level"))

        XCTAssertEqual(tree.children, ["level", "words"])
        XCTAssertEqual(level.kind.name, "liquid")
        XCTAssertEqual(level.source, "/spots/liquid.swift")
        XCTAssertEqual(level.values["value"], ["0.72"])
        XCTAssertEqual(level.values["tone"], ["good"])
        XCTAssertTrue(level.style.isAbsolute)
        XCTAssertNil(tree.node("words")?.source)
    }

    func testAKindThatNoManifestNamesIsSkippedAndReported() {
        let check = FrameCheck(text: battery)

        XCTAssertNil(check.output.tree.node("level"))
        XCTAssertEqual(check.output.tree.children, ["words"])
        XCTAssertTrue(check.sheetFaults.contains("cannot read the block that starts: liquid=level"))
    }

    func testAPatchByIdReplacesTheNodeAndKeepsItsChildren() {
        let tree = patched("box=head\nclass=flex-col\n", after: wifi)

        XCTAssertEqual(tree.node("head")?.style.arrangement, .column)
        XCTAssertEqual(tree.node("head")?.children, ["wifi", "name", "forget"])
        XCTAssertEqual(tree.children, ["head", "note"])
    }

    func testALaterBlockWithTheIdAndKindOfANodePatchesItsKeysAndKeepsItsPlace() throws {
        for tree in [patched("text=name\ntitle=Office\n", after: wifi), Frame(text: wifi + "\n\ntext=name\ntitle=Office\n").tree] {
            let name = try XCTUnwrap(tree.node("name"))
            XCTAssertEqual(name.title, "Office")
            XCTAssertEqual(name.detail, "82 Mb/s")
            XCTAssertEqual(name.style.grows, true)
            XCTAssertEqual(name.parent, "head")
            XCTAssertEqual(tree.node("head")?.children, ["wifi", "name", "forget"])
            XCTAssertTrue(tree.faults.isEmpty)
        }
    }

    func testALaterBlockWithTheIdOfANodeAndAnotherKindReplacesItInItsPlace() throws {
        for tree in [patched("switch=name\ntitle=Wi-Fi\n", after: wifi), Frame(text: wifi + "\n\nswitch=name\ntitle=Wi-Fi\n").tree] {
            let name = try XCTUnwrap(tree.node("name"))
            XCTAssertEqual(name.kind, .toggle)
            XCTAssertEqual(name.title, "Wi-Fi")
            XCTAssertNil(name.detail)
            XCTAssertNil(name.style.grows)
            XCTAssertEqual(tree.node("head")?.children, ["wifi", "name", "forget"])
            XCTAssertTrue(tree.faults.isEmpty)
        }
    }

    func testANewIdJoinsTheEndOfItsParent() {
        let tree = patched("text=speed\nparent=head\ntitle=Fast\n", after: wifi)

        XCTAssertEqual(tree.node("head")?.children, ["wifi", "name", "forget", "speed"])
    }

    func testANewParentMovesTheNode() {
        let out = patched("button=forget\nparent=\n", after: wifi)
        XCTAssertEqual(out.node("head")?.children, ["wifi", "name"])
        XCTAssertEqual(out.children, ["head", "forget", "note"])

        let into = patched("text=note\nparent=head\ntitle=Saved\n", after: wifi)
        XCTAssertEqual(into.node("head")?.children, ["wifi", "name", "forget", "note"])
        XCTAssertEqual(into.children, ["head"])
    }

    func testAFrameWithARootReplacesTheWholeTree() {
        let tree = patched("frame=\n\ntext=only\ntitle=Only\n", after: wifi)

        XCTAssertEqual(tree.children, ["only"])
        XCTAssertNil(tree.node("head"))
    }

    func testAParentThatNamesNoNodeJoinsTheRootAndIsReported() {
        let text = wifi + "\n\ntext=lost\nparent=gone\ntitle=Lost\n"

        XCTAssertEqual(Frame(text: text).tree.children, ["head", "note", "lost"])
        XCTAssertTrue(FrameCheck(text: text).partFaults.contains("the part lost names the parent gone, which no part has"))
    }

    func testANodeInsideItselfJoinsTheRootAndIsReported() {
        let text = "frame=\nclass=gap-2\n\nbox=a\nparent=b\n\nbox=b\nparent=a\n"
        let tree = Frame(text: text).tree

        XCTAssertEqual(tree.children, ["a"])
        XCTAssertEqual(tree.node("a")?.children, ["b"])
        XCTAssertEqual(tree.faults, ["the part a sits inside itself"])
    }

    func testAnUnknownClassIsReported() {
        let text = "frame=\nclass=p-3 glow\n\ntext=name\ntitle=Home\nclass=grow card:blink\n"

        XCTAssertEqual(FrameCheck(text: text).partFaults, [
            "the root has an unknown class: glow",
            "the part name has an unknown class: card:blink"
        ])
    }

    func testThePlaceOfAnItemIsNoParentAndNoFault() {
        let text = "item=shrink\ntitle=Shrink\nplace=Files\n"
        let check = FrameCheck(text: text)

        XCTAssertFalse(check.output.tree.isWritten)
        XCTAssertEqual(check.output.tree.children, ["shrink"])
        XCTAssertTrue(check.partFaults.isEmpty)
        XCTAssertEqual(check.output.items.map(\.place), ["Files"])
    }

    func testABoxIsNeitherAnItemNorAnError() {
        let frame = Frame(text: "frame=\nclass=gap-part\n\nbox=head\nclass=flex-row\n\ntext=name\nparent=head\ntitle=Home\n")

        XCTAssertTrue(frame.errors.isEmpty)
        XCTAssertEqual(frame.parts.map(\.id), ["name"])
        XCTAssertTrue(FrameCheck(text: "frame=\nclass=gap-part\n\nbox=head\n\ntext=name\nparent=head\ntitle=Home\n").partFaults.isEmpty)
    }

    func testOnlyAnItemsBlockOrAClassOnTheRootMakesALayout() {
        let loose = FrameCheck(text: "frame=\n\nbox=head\nclass=flex-row\n\nitem=name\nparent=head\ntitle=Home\nclass=grow\n\nnumber=n\nclass=card:flex\nvalue=1\n")

        XCTAssertFalse(loose.output.tree.isWritten)
        XCTAssertEqual(loose.output.items.map(\.run), ["name", "n"])
        XCTAssertEqual(loose.partFaults, [
            "the part head needs a layout, so give the root a class", "the part name needs a layout, so give the root a class",
            "the card shows more than one value: name, n. Name the one it stands for with value= in the root"
        ])
        XCTAssertTrue(Frame(text: "frame=\nclass=gap-part\n\ntext=a\n").tree.isWritten)
        XCTAssertTrue(Frame(text: "items=list\n\nitem=a\nparent=list\n").tree.isWritten)
    }

    func testAWrittenTreeDrawsEachNodeInTheSheetAndNoneAsAnItem() throws {
        let panel = try XCTUnwrap(SheetParts(output: Frame(text: wifi)))

        XCTAssertTrue(panel.tree.isWritten)
        XCTAssertEqual(panel.tree.children, ["head", "note"])
        XCTAssertEqual(Set(panel.parts.map(\.id)), ["wifi", "name", "forget", "note"])
        XCTAssertTrue(Frame(text: wifi).items.isEmpty)
        XCTAssertLessThan(panel.height, panel.top.partsRoom)
    }

    func testAFrameWithNoTreeWritesItsChoiceOverItsItemsAsATree() throws {
        let output = Frame(text: "choice=a\nvalue=x\n\noption=x\ntitle=X\n\nitem=b\ntitle=B\n")
        let panel = try XCTUnwrap(SheetParts(output: output))

        XCTAssertFalse(output.tree.isWritten)
        XCTAssertEqual(output.search, .local)
        XCTAssertFalse(panel.tree.isWritten)
        XCTAssertEqual(panel.tree.children, ["a", "items"])
        XCTAssertEqual(panel.tree.node("items")?.kind, .items)
        XCTAssertEqual(panel.tree.style.rowGap, Frame(text: "frame=\nclass=gap-part\n").tree.style.rowGap)
        XCTAssertEqual(output.items.map(\.title), ["B"])
        XCTAssertTrue(panel.showsRows)
        XCTAssertEqual(panel.height, panel.top.partsRoom)
    }

    func testAFrameWithNoTreeAndNoItemsWritesItsChoicesAsATreeOfTheirOwnHeight() throws {
        let panel = try XCTUnwrap(SheetParts(output: Frame(text: "frame=\ntitle=Look\n\nchoice=look\nvalue=x\n\noption=x\ntitle=X\n\nchoice=size\nvalue=s\n\noption=s\ntitle=S\n")))

        XCTAssertFalse(panel.tree.isWritten)
        XCTAssertEqual(panel.tree.children, ["look", "size"])
        XCTAssertFalse(panel.showsRows)
        XCTAssertEqual(panel.height, 2 * SpotTokens.listRow + SpotTokens.partGap)
        XCTAssertEqual(panel.focusOrder.map(\.id), ["look", "size"])
    }

    func testANodeKeepsItsWordsAndItsIcon() {
        let text = "frame=\nclass=gap-2\n\nicon=wifi\nvalue=wifi\n\nicon=cup\nvalue=cups.png\n\ntext=name\ntitle=Home\ndetail=82 Mb/s\nvalue=On\ntone=good\n"
        let tree = Frame(text: text).tree

        XCTAssertEqual(tree.node("wifi")?.kind, .icon)
        XCTAssertEqual(tree.node("wifi")?.icon, .symbol("wifi"))
        XCTAssertEqual(tree.node("cup")?.icon, .image("cups.png"))
        XCTAssertEqual(tree.node("name")?.title, "Home")
        XCTAssertEqual(tree.node("name")?.detail, "82 Mb/s")
        XCTAssertEqual(tree.node("name")?.value, "On")
        XCTAssertEqual(tree.node("name")?.tone, .good)
        XCTAssertTrue(FrameCheck(text: text).partFaults.isEmpty)
    }

    func testEachLeafHasOneNaturalSize() {
        let tree = Frame(text: "frame=\nclass=gap-part\n\nicon=wifi\nvalue=wifi\n\npicture=cup\nicon=cups.png\n\nnumber=cpu\nvalue=1\n\nfield=keys\ntype=hotkey\nvalue=cmd+k\n\nitems=list\n").tree
        let icon = SpotTokens.listIconSize
        let cell = SpotTokens.cell

        XCTAssertEqual(tree.node("wifi")?.naturalSize, CGSize(width: icon, height: icon))
        XCTAssertEqual(tree.node("cup")?.naturalSize, CGSize(width: cell, height: cell))
        XCTAssertEqual(tree.node("cpu")?.naturalSize, CGSize(width: cell, height: SpotTokens.listRow))
        XCTAssertEqual(tree.node("keys")?.naturalSize, CGSize(width: cell, height: 2 * SpotTokens.listRow + SpotTokens.partGap))
        XCTAssertEqual(tree.node("list")?.naturalSize, CGSize(width: cell, height: SpotTokens.listRow))
    }

    func testTheClassesOfTheItemsLayOutEachItem() {
        let text = "frame=\nclass=gap-part\n\nitems=list\nclass=grid grid-cols-4 gap-part\n\ntext=a\nparent=list\ntitle=A\nclass=bg-tile\n"

        XCTAssertEqual(Frame(text: text).columns, 4)
        XCTAssertEqual(Frame(text: "frame=\n\nitems=list\nclass=gap-part\n").columns, 1)
    }

    func testABoxInTheItemsTitlesTheItemsInsideItAndTheSectionFontIsOnlyALook() {
        let text = "frame=\n\nitems=list\n\nbox=recent\nparent=list\ntitle=Recent\n\nitem=a\nparent=recent\ntitle=A\n\nitem=b\nparent=list\ntitle=B\nclass=font-section\n"
        let frame = Frame(text: text)

        XCTAssertEqual(frame.items.map(\.run), ["a", "b"])
        XCTAssertEqual(frame.items.map(\.section), ["Recent", nil])
        XCTAssertEqual(frame.parts, [])
        XCTAssertEqual(FrameCheck(text: text).partFaults, [])
    }

    func testATextsPaddingIsPartOfItsHeight() throws {
        let plain = try XCTUnwrap(Frame(text: "frame=\n\ntext=a\ntitle=A\n").tree.height(in: SpotTokens.partsWidth))
        let padded = try XCTUnwrap(Frame(text: "frame=\n\ntext=a\ntitle=A\nclass=p-3\n").tree.height(in: SpotTokens.partsWidth))

        XCTAssertEqual(padded, plain + 2 * 3 * SpotTokens.spaceUnit)
    }

    func testATextCountsEachLineItsWordsWrapTo() throws {
        let short = "frame=\n\ntext=a\ntitle=A\ndetail=One line\n"
        let long = "frame=\n\ntext=a\ntitle=A\ndetail=\(Array(repeating: "words", count: 60).joined(separator: " "))\n"
        let one = try XCTUnwrap(Frame(text: short).tree.height(in: SpotTokens.partsWidth))
        let many = try XCTUnwrap(Frame(text: long).tree.height(in: SpotTokens.partsWidth))
        let cut = try XCTUnwrap(Frame(text: long + "class=truncate\n").tree.height(in: SpotTokens.partsWidth))
        let line = CGFloat(SpotTokens.layout.type.detail) + SpotTokens.textLeading

        XCTAssertGreaterThanOrEqual(many, one + 4 * line)
        XCTAssertEqual((many - one).truncatingRemainder(dividingBy: line), 0)
        XCTAssertEqual(cut, one)
    }

    func testAButtonPlacedInAWrittenTreeIsNoActionSoItNeedsNoTitle() {
        let check = FrameCheck(text: "frame=\nclass=gap-part\n\nbox=row\nclass=flex-row\n\nbutton=swap\nparent=row\nicon=arrow.up.arrow.down\n")

        XCTAssertEqual(check.partFaults, [])
        XCTAssertEqual(check.output.actions, [])
    }


    func testALaterFrameChangesABlockOfItsOwnKindAndAnOptionStaysWithItsChoice() {
        let base = "frame=\nclass=gap-part\n\nicon=wifi\nvalue=wifi\n\nchoice=net\nvalue=wifi\n\noption=wifi\ntitle=Wi-Fi\n\ntext=note\ntitle=Note\n"
        let patch = "choice=net\nvalue=lan\n\noption=lan\ntitle=Ethernet\n\noption=wifi\ntitle=Wireless\n"

        let output = Frame(text: FrameStream(patch, after: FrameStream(base, after: nil).drawn).text)

        XCTAssertEqual(output.tree.children, ["wifi", "net", "note"])
        XCTAssertEqual(output.tree.node("wifi")?.kind, .icon)
        XCTAssertEqual(output.parts.first { $0.id == "net" }?.control, .menu([.init(id: "lan", title: "Ethernet"), .init(id: "wifi", title: "Wireless")], value: "lan"))
        XCTAssertEqual(output.errors, [])
        let renamed = Frame(text: FrameStream("option=wifi\ntitle=Air\n", after: FrameStream(base, after: nil).drawn).text)
        XCTAssertEqual(renamed.parts.first { $0.id == "net" }?.control, .menu([.init(id: "wifi", title: "Air")], value: "wifi"))
        XCTAssertEqual(renamed.errors, [])
    }

    func testAButtonGivesItsHoverToTheBlocksInsideIt() throws {
        let tree = Frame(text: "frame=\n\nbutton=go\n\ntext=label\nparent=go\ntitle=Go\nclass=hover:text-accent\n").tree
        let button = try XCTUnwrap(tree.node("go"))

        XCTAssertTrue(tree.tracksHover(button))
        XCTAssertEqual(tree.states(in: [.sheet], pressed: false, hovered: true, selected: false), [.sheet, .hover])
    }
}
