import XCTest
@testable import OpenspotCore

final class SheetListKeysTests: PanelCase {
    private func open(_ actions: String) async throws {
        let frame = "grid=files\\ngrid=import\\n\\nrepeat=files\\n\\nbutton=import\\ntitle=Import\\nlook=strong\\nshortcut=cmd+return\\n\(actions)\\nrow=a\\ntitle=A\\n\\nrow=b\\ntitle=B\\n"
        try script("list", header: "title=List\non=sheet.open", "printf '\(frame)'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("list")
        try await wait("the sheet") { self.model.openParts?.parts.contains { $0.id == "import" } == true && self.titles == ["A", "B"] }
    }

    func testTheActionsKeyOpensTheMenuThatTheFooterOffers() async throws {
        try await open("\\nbutton=open\\ntitle=Select\\nclose=false\\n\\nbutton=change\\ntitle=Change Folder\\nshortcut=cmd+o\\nscope=spot\\n")

        XCTAssertTrue(model.hint.contains("⌘K Actions"), model.hint)
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        XCTAssertNotNil(model.menu)
    }

    func testCommandDownMovesFromTheListToTheMainButton() async throws {
        try await open("")

        XCTAssertTrue(model.handleKey(ActionKey(name: "down", isCommand: true)))

        XCTAssertEqual(model.openParts?.selected, "import")
    }

    func testCommandDownTellsTheListThatItsSelectionLeft() async throws {
        try await open("")
        let content = try model.sheetContent(of: XCTUnwrap(model.entry("list")))
        nonisolated(unsafe) var changed = false
        withObservationTracking { _ = content.selection() } onChange: { changed = true }

        _ = model.handleKey(ActionKey(name: "down", isCommand: true))

        XCTAssertTrue(changed)
        XCTAssertEqual(content.selection(), Int.max)
    }

    func testALineMoveUnderAViewMovesTheSelectionThatTheViewReads() async throws {
        let frame = "grid=preview\\ngrid=files\\ngrid=import\\n\\nview=preview\\ngrow=false\\n\\nrepeat=files\\n\\nbutton=import\\ntitle=Import\\nlook=strong\\nshortcut=cmd+return\\n\\nrow=a\\ntitle=A\\n\\nrow=b\\ntitle=B\\n"
        try script("list", header: "title=List\non=sheet.open\nview=preview.swift", "printf '\(frame)'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("list")
        try await wait("the sheet") { self.titles == ["A", "B"] }
        let content = try model.sheetContent(of: XCTUnwrap(model.entry("list")))

        model.moveItemLine(by: 1)

        XCTAssertEqual(content.selection(), 1)
        XCTAssertEqual(content.list.run(at: content.selection()), "b")
    }
}
