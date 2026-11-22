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
    look=chip

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
        XCTAssertEqual(tree.node("head")?.kind, "box")
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
        XCTAssertEqual(level.kind, "liquid")
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

    func testANewIdJoinsTheEndOfItsParent() {
        let tree = patched("text=speed\nparent=head\ntitle=Fast\n", after: wifi)

        XCTAssertEqual(tree.node("head")?.children, ["wifi", "name", "forget", "speed"])
    }

    func testANewParentMovesTheNode() {
        let out = patched("button=forget\ntitle=Forget\n", after: wifi)
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

    func testTheParentOfAnItemInAFrameWithNoTreeIsNoFault() {
        let text = "text=shrink\ntitle=Shrink\nparent=Files\n"
        let check = FrameCheck(text: text)

        XCTAssertFalse(check.output.tree.isWritten)
        XCTAssertEqual(check.output.tree.children, ["shrink"])
        XCTAssertTrue(check.partFaults.isEmpty)
        XCTAssertEqual(check.output.items.map(\.parent), ["Files"])
    }

    func testABoxIsNeitherAnItemNorAnError() {
        let frame = Frame(text: "frame=\n\nbox=head\nclass=flex-row\n\ntext=name\nparent=head\ntitle=Home\n")

        XCTAssertTrue(frame.errors.isEmpty)
        XCTAssertEqual(frame.parts.map(\.id), ["name"])
        XCTAssertTrue(FrameCheck(text: "frame=\n\nbox=head\n\ntext=name\nparent=head\ntitle=Home\n").partFaults.isEmpty)
    }

    func testAWrittenTreeDrawsEachNodeInTheSheetAndNoneAsAnItem() throws {
        let panel = try XCTUnwrap(SheetParts(output: Frame(text: wifi)))

        XCTAssertTrue(panel.tree.isWritten)
        XCTAssertEqual(panel.tree.children, ["head", "note"])
        XCTAssertEqual(Set(panel.parts.map(\.id)), ["wifi", "name", "forget", "note"])
        XCTAssertTrue(Frame(text: wifi).items.isEmpty)
        XCTAssertEqual(panel.placement.height, panel.top.partsRoom)
    }

    func testAFrameWithNoTreeKeepsItsGridPlacement() throws {
        let panel = try XCTUnwrap(SheetParts(output: Frame(text: "frame=\ngrid=a\n\ntext=a\ntitle=Alpha\n")))

        XCTAssertFalse(panel.tree.isWritten)
        XCTAssertEqual(panel.placement.height, SpotTokens.listRow)
    }

    func testANodeKeepsItsWordsAndItsIcon() {
        let text = "frame=\nclass=gap-2\n\nicon=wifi\nvalue=wifi\n\nicon=cup\nvalue=cups.png\n\ntext=name\ntitle=Home\ndetail=82 Mb/s\nvalue=On\ntone=good\n"
        let tree = Frame(text: text).tree

        XCTAssertEqual(tree.node("wifi")?.kind, "icon")
        XCTAssertEqual(tree.node("wifi")?.icon, .symbol("wifi"))
        XCTAssertEqual(tree.node("cup")?.icon, .image("cups.png"))
        XCTAssertEqual(tree.node("name")?.title, "Home")
        XCTAssertEqual(tree.node("name")?.detail, "82 Mb/s")
        XCTAssertEqual(tree.node("name")?.value, "On")
        XCTAssertEqual(tree.node("name")?.tone, .good)
        XCTAssertTrue(FrameCheck(text: text).partFaults.isEmpty)
    }

    func testAStyleInASheetLeavesItsVariantsUnapplied() {
        let style = Style(classes: "p-3 card:p-0 dark:hidden")

        XCTAssertEqual(style.resolved(for: [.sheet, .dark]).padding[.top], .steps(3))
        XCTAssertNil(style.resolved(for: [.sheet, .dark]).isHidden)
    }
}
