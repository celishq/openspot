import XCTest
@testable import OpenspotCore

@MainActor
final class PeekActTests: PanelCase {
    private let board = FakeClipboard()

    private func openColors(uses: String = "[\"clipboard\"]") async throws {
        model.runs.api = CommandAPI(mac: Mac(clipboard: board), places: model.files, app: ModelApp(model: model), runs: model.runs)
        try script("colors", toml: "title = 'Colors'\nuses = \(uses)\n\n[on]\n\"sheet.open\" = true", """
        [ -n "$1" ] && [ "$1" != show ] && printf '%s|%s\\n' "$1" "$(sed -n 's/^input.item=//p')" >> '\(folder.appendingPathComponent("runs").path)' && exit 0
        printf 'item=red\\ntitle=Red\\ntext=#ff0000\\n\\npeek=pr\\nparent=red\\n\\ntext=hex\\nparent=pr\\ntitle=#FF0000\\n\\nbutton=rgb\\nparent=pr\\ntitle=Copy RGB\\ncopy=rgb(255 0 0)\\n\\nbutton=put\\nparent=pr\\ntitle=Paste Hex\\npaste=#FF0000\\n\\nbutton=web\\nparent=pr\\ntitle=Open Page\\nopen=https://example.com/red\\n\\nbutton=name\\nparent=pr\\ntitle=Rename\\nrun=rename\\n'
        """)
        await model.reload()
        model.press("colors")
        try await wait("the open list") { self.model.openSheet?.list.shown.isEmpty == false }
    }

    private func action(_ title: String) throws -> (CommandAction, SpotsModel.Target) {
        let target = try XCTUnwrap(model.target)
        let row = try XCTUnwrap(model.actionMenu(on: target)?.rows.first { $0.title == title }, "no \(title) in ⌘K")
        return (try XCTUnwrap(row.action), target)
    }

    func testTheButtonsOfAPeekAreActionsOfItsRowAndNoPartOfItsDrawing() async throws {
        try await openColors()
        let target = try XCTUnwrap(model.target)

        let titles = model.actionMenu(on: target)?.rows.map(\.title) ?? []

        XCTAssertTrue(["Peek", "Copy RGB", "Paste Hex", "Open Page", "Rename"].allSatisfy(titles.contains), "\(titles)")
        guard case .blocks(let tree) = Peek(item: try XCTUnwrap(target.item))?.look else { return XCTFail("no blocks") }
        XCTAssertNil(tree.node("rgb"))
    }

    func testCopyPutsItsTextOnTheClipboardWithNoRunOfTheSpot() async throws {
        try await openColors()
        let (copy, target) = try action("Copy RGB")

        model.run(copy, on: target)

        try await wait("the copied text") { self.board.text() == "rgb(255 0 0)" }
        XCTAssertNil(try? String(contentsOf: folder.appendingPathComponent("runs"), encoding: .utf8))
    }

    func testPasteCopiesItsTextAndPastesItIntoTheFrontApp() async throws {
        try await openColors()
        let (paste, target) = try action("Paste Hex")

        model.run(paste, on: target)

        try await wait("the paste") { self.board.pasteCount == 1 }
        XCTAssertEqual(board.text(), "#FF0000")
    }

    func testOpenOpensItsPlace() async throws {
        try await openColors()
        let (open, target) = try action("Open Page")

        model.run(open, on: target)

        XCTAssertEqual(host.opened, [URL(string: "https://example.com/red")!])
    }

    func testRunCallsTheSpotWithTheRow() async throws {
        try await openColors()
        let (rename, target) = try action("Rename")

        model.run(rename, on: target)

        try await wait("the spot's run") { (try? String(contentsOf: self.folder.appendingPathComponent("runs"), encoding: .utf8)) == "rename|red\n" }
    }

    func testACopyBySpotThatDoesNotUseTheClipboardIsRefused() async throws {
        try await openColors(uses: "[]")
        let (copy, target) = try action("Copy RGB")

        model.run(copy, on: target)

        try await wait("the refusal") { self.host.toasts.contains { $0.note.words.contains("clipboard") } }
        XCTAssertEqual(board.count(), 0)
    }
}
