import XCTest
@testable import OpenspotCore

@MainActor
final class PeekFileTests: PanelCase {
    private let peekKey = ActionKey(name: "p", isCommand: true)

    private func frame(_ name: String, row: String, title: String) throws -> String {
        let file = folder.appendingPathComponent("\(name).frame")
        try "peek=peek-\(row)\nparent=\(row)\n\ntext=t\nparent=peek-\(row)\ntitle=\(title)\n\nbutton=c\nparent=peek-\(row)\ntitle=Copy \(title)\naction=clipboard copy --text \(title)\n".write(to: file, atomically: true, encoding: .utf8)
        return file.path
    }

    private func openRows(_ a: String, _ b: String) async throws {
        try script("kept", toml: "title = 'Kept'\n\n[on]\n\"sheet.open\" = true", "printf 'item=a\\ntitle=A\\ntext=one\\npeek.file=\(a)\\n\\nitem=b\\ntitle=B\\ntext=two\\npeek.file=\(b)\\n'")
        await model.reload()
        model.press("kept")
        try await wait("the open list") { self.model.openSheet?.list.shown.isEmpty == false }
    }

    private func title(of tree: Peek.Look?) -> String? {
        guard case .blocks(let tree) = tree else { return nil }
        return tree.node("t")?.block.value("title")
    }

    func testThePeekOfARowIsTheFrameItsPeekFileNamesReadInTheBackground() async throws {
        try await openRows(try frame("a", row: "a", title: "Kept A"), try frame("b", row: "b", title: "Kept B"))

        XCTAssertTrue(model.handleKey(peekKey))

        try await wait("the kept peek") { self.title(of: self.model.peek?.look) == "Kept A" }
        let target = try XCTUnwrap(model.target)
        XCTAssertTrue(model.actionMenu(on: target)?.rows.contains { $0.title == "Copy Kept A" } == true)
    }

    func testTheNextRowsPeekIsReadAheadSoTheArrowShowsItAtOnce() async throws {
        try await openRows(try frame("a", row: "a", title: "Kept A"), try frame("b", row: "b", title: "Kept B"))
        _ = model.handleKey(peekKey)
        try await wait("the kept peek of the next row") { self.model.peekFrames.blocks(of: self.folder.appendingPathComponent("b.frame").path) != nil }

        _ = model.handleSearchKey(ActionKey(name: "down"))

        XCTAssertEqual(title(of: model.peek?.look), "Kept B")
    }

    func testAMissingPeekFileLeavesTheRowsOwnPeek() async throws {
        try await openRows(folder.appendingPathComponent("gone.frame").path, try frame("b", row: "b", title: "Kept B"))

        _ = model.handleKey(peekKey)
        try await wait("the next row's kept peek") { self.model.peekFrames.blocks(of: self.folder.appendingPathComponent("b.frame").path) != nil }

        XCTAssertEqual(model.peek?.look, .text("one"))
    }

    func testTheKeptFramesHoldNoMoreThanTheirByteLimit() {
        var frames = PeekFrames()
        let block = TextBlock(fields: [.init(key: "text", value: "t")])

        for index in 0..<40 { frames.take([block], of: "/f\(index)", bytes: PeekFrames.byteLimit / 8) }

        XCTAssertLessThanOrEqual(frames.bytes, PeekFrames.byteLimit)
        XCTAssertNil(frames.blocks(of: "/f0"))
        XCTAssertNotNil(frames.blocks(of: "/f39"))
    }
}
