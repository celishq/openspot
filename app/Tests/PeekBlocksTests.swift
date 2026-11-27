import XCTest
@testable import OpenspotCore

@MainActor
final class PeekBlocksTests: PanelCase {
    private let peekKey = ActionKey(name: "p", isCommand: true)

    func testAPeekBlockAndItsChildrenBelongToTheirRowAndAreNoPartOfTheSheet() {
        let frame = Frame(text: "item=a\ntitle=A\n\npeek=pa\nparent=a\n\ntext=big\nparent=pa\ntitle=Big\n\nitem=b\ntitle=B\n")

        XCTAssertEqual(frame.errors, [])
        XCTAssertEqual(frame.items.map(\.title), ["A", "B"])
        XCTAssertEqual(frame.items.first?.peek.map(\.firstLine), ["peek=pa", "text=big"])
        XCTAssertEqual(frame.items.last?.peek, [])
    }

    func testARowThatCarriesAPeekShowsItsBlocksWithNoRunOfTheSpot() async throws {
        try script("history", toml: "title = 'History'\n\n[on]\n\"sheet.open\" = true", "printf 'item=a\\ntitle=Red\\ntext=#ff0000\\n\\npeek=pa\\nparent=a\\n\\ntext=hex\\nparent=pa\\ntitle=#FF0000\\n\\nnumber=red\\nparent=pa\\ntitle=Red\\nvalue=255\\n'")
        await model.reload()
        model.press("history")
        try await wait("the open list") { self.model.openSheet?.list.shown.isEmpty == false }

        XCTAssertTrue(model.handleKey(peekKey))

        guard case .blocks(let tree) = model.peek?.look else { return XCTFail("no blocks: \(String(describing: model.peek?.look))") }
        XCTAssertEqual(tree.node("hex")?.block.value("title"), "#FF0000")
        XCTAssertEqual(tree.node("red")?.kind, .number)
    }

    func testAPeekOfOnlyUnknownBlocksFallsBackToTheRowsValue() {
        let frame = Frame(text: "item=a\ntitle=A\ntext=words\n\npeek=pa\nparent=a\n\nslider=s\nparent=pa\n")

        XCTAssertEqual(frame.items.first.flatMap { Peek(item: $0) }?.look, .text("words"))
    }

    func testAPeekWhoseParentNamesNoRowIsAFaultOfTheFrame() {
        let frame = Frame(text: "item=a\ntitle=A\n\npeek=pa\nparent=z\n")

        XCTAssertEqual(frame.errors, ["peek=pa"])
    }
}
