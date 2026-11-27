import XCTest
@testable import OpenspotCore

@MainActor
final class PeekTests: PanelCase {
    private let peekKey = ActionKey(name: "p", isCommand: true)

    private func openHistory(_ rows: String) async throws {
        try script("history", toml: "title = 'History'\n\n[on]\n\"sheet.open\" = true", rows)
        await model.reload()
        model.press("history")
        try await wait("the open list") { self.model.openSheet?.list.shown.isEmpty == false }
    }

    func testCommandPOnARowShowsItsPeekBesideTheSheetAndFollowsTheSelection() async throws {
        try await openHistory("printf 'item=a\\ntitle=Note\\ntext=two\\\\nlines\\n\\nitem=b\\ntitle=Page\\nurl=https://a.com/x\\n'")

        XCTAssertTrue(model.handleKey(peekKey))

        let sheet = try XCTUnwrap(model.openSheet?.sheetRect)
        let rect = CGRect(x: sheet.maxX + SpotTokens.peekGap, y: sheet.minY, width: SpotTokens.peekWidth, height: min(SpotTokens.peekHeight, sheet.height))
        XCTAssertEqual(model.peek?.look, .text("two\nlines"))
        XCTAssertEqual(model.peekRect, rect)
        XCTAssertEqual(host.reaches, [rect])
        XCTAssertTrue(model.hint.contains("⌘P Close Peek"), model.hint)
        try await wait("the peek grown out of the sheet") { self.model.isPeekOpen }

        _ = model.handleSearchKey(ActionKey(name: "down"))

        XCTAssertEqual(model.peek?.look, .link("https://a.com/x", host: "a.com"))
        XCTAssertEqual(host.reaches, [rect])
    }

    func testCommandPAgainClosesThePeek() async throws {
        try await openHistory("printf 'item=a\\ntitle=Note\\ntext=words\\n'")
        _ = model.handleKey(peekKey)

        try await wait("the grown peek") { self.model.isPeekGrown }
        host.heldEnds = []

        XCTAssertTrue(model.handleKey(peekKey))

        XCTAssertFalse(model.isPeekOpen)
        XCTAssertEqual(model.peek?.look, .text("words"))
        XCTAssertEqual(model.openSheetID, "history")
        host.heldEnds?.forEach { $0() }
        XCTAssertNil(model.peek)
        XCTAssertNil(model.peekRect)
    }

    func testAFileRowPeeksAsAPictureOrAFile() async throws {
        try await openHistory("printf 'item=a\\ntitle=Shot\\nfile=/tmp/shot.png\\n\\nitem=b\\ntitle=Doc\\nfile=/tmp/doc.pdf\\n'")

        _ = model.handleKey(peekKey)
        XCTAssertEqual(model.peek?.look, .picture("/tmp/shot.png"))

        _ = model.handleSearchKey(ActionKey(name: "down"))
        XCTAssertEqual(model.peek?.look, .file("/tmp/doc.pdf"))
    }

    func testTheShownHintSaysClosePeekOnceThePeekOpens() async throws {
        try await openHistory("printf 'item=a\\ntitle=Note\\ntext=words\\n'")
        model.followHint()

        _ = model.handleKey(peekKey)

        try await wait("the hint of the open peek") { self.model.sheetHint.groups.contains { $0.words == "Close Peek" } }
    }

    func testWithNoRoomOnTheRightThePeekGrowsOnTheLeft() async throws {
        try await openHistory("printf 'item=a\\ntitle=Note\\ntext=words\\n'")
        host.roomRight = false

        _ = model.handleKey(peekKey)

        let sheet = try XCTUnwrap(model.openSheet?.sheetRect)
        XCTAssertEqual(model.peekRect?.maxX, sheet.minX - SpotTokens.peekGap)
        XCTAssertEqual(model.peekSource?.minX, sheet.minX)
    }

    func testEscapeClosesThePeekFirstAndThenTheSheet() async throws {
        try await openHistory("printf 'item=a\\ntitle=Note\\ntext=words\\n'")
        _ = model.handleKey(peekKey)

        XCTAssertTrue(model.handleKey(ActionKey(name: "escape")))

        XCTAssertFalse(model.isPeekOpen)
        XCTAssertEqual(model.openSheetID, "history")
        try await wait("the panel back to its own size") { self.model.peekRect == nil && self.host.reaches.last == .some(nil) }
    }

    func testARowWithNothingToShowHasNoPeekAndCommandPGoesOn() async throws {
        try await openHistory("printf 'item=a\\ntitle=Plain\\n'")

        XCTAssertFalse(model.handleKey(peekKey))
        XCTAssertNil(model.peek)
        XCTAssertFalse(model.hint.contains("Peek"), model.hint)
    }

    func testHidingThePanelClosesThePeek() async throws {
        try await openHistory("printf 'item=a\\ntitle=Note\\ntext=words\\n'")
        _ = model.handleKey(peekKey)

        model.panelWillHide()

        XCTAssertNil(model.peek)
        try await wait("the panel back to its own size") { self.model.peekRect == nil && self.host.reaches.last == .some(nil) }
    }

    func testClosingTheSheetClosesThePeek() async throws {
        try await openHistory("printf 'item=a\\ntitle=Note\\ntext=words\\n'")
        _ = model.handleKey(peekKey)

        _ = model.handleKey(ActionKey(name: "escape"))
        _ = model.handleKey(ActionKey(name: "escape"))

        XCTAssertNil(model.openSheetID)
        try await wait("the peek gone with the sheet") { self.model.peek == nil }
    }

    func testTypingInTheFieldKeepsThePeekOnTheNewSelection() async throws {
        try await openHistory("printf 'item=a\\ntitle=Alpha\\ntext=one\\n\\nitem=b\\ntitle=Beta\\ntext=two\\n'")
        _ = model.handleKey(peekKey)

        model.search("Beta")

        try await wait("the peek of the only row left") { self.model.peek?.look == .text("two") }
    }

    func testTheActionsMenuOfAPeekableRowOffersPeek() async throws {
        try await openHistory("printf 'item=a\\ntitle=Note\\ntext=words\\n\\nitem=b\\ntitle=Plain\\n'")
        let note = try XCTUnwrap(model.target)

        XCTAssertEqual(model.actionMenu(on: note)?.rows.contains { $0.title == "Peek" }, true)

        _ = model.handleSearchKey(ActionKey(name: "down"))
        let plain = try XCTUnwrap(model.target)
        XCTAssertNotEqual(model.actionMenu(on: plain)?.rows.contains { $0.title == "Peek" }, true)
    }

    func testThePeekRowOfTheActionsMenuOpensThePeekAsTheKeyDoes() async throws {
        try await openHistory("printf 'item=a\\ntitle=Note\\ntext=words\\n'")
        let note = try XCTUnwrap(model.target)

        model.run(.peek, on: note)

        XCTAssertEqual(model.peek?.look, .text("words"))
    }

    func testThePeekReadsAheadThePicturesOfTheSelectedRowAndTheRowsBesideIt() async throws {
        try await openHistory("printf 'item=a\\ntitle=A\\nfile=/tmp/a.png\\n\\nitem=b\\ntitle=B\\nfile=/tmp/b.pdf\\n\\nitem=c\\ntitle=C\\nfile=/tmp/c.png\\n\\nitem=d\\ntitle=D\\ntext=words\\n'")
        XCTAssertEqual(host.peekReads, [])

        _ = model.handleKey(peekKey)
        XCTAssertEqual(host.peekReads, [[.picture("/tmp/a.png"), .file("/tmp/b.pdf")]])

        _ = model.handleSearchKey(ActionKey(name: "down"))
        XCTAssertEqual(host.peekReads.last, [.file("/tmp/b.pdf"), .picture("/tmp/c.png"), .picture("/tmp/a.png")])
    }

    func testALongTextPeeksOnlyAsMuchAsThePaneCanShow() async throws {
        let long = String(repeating: "word ", count: Peek.textLimit)
        try await openHistory("printf 'item=a\\ntitle=Long\\ntext=\(long)\\n'")

        _ = model.handleKey(peekKey)

        guard case .text(let shown) = model.peek?.look else { return XCTFail("no text") }
        XCTAssertEqual(shown.count, Peek.textLimit)
    }

    func testAPeekThatIsClosingStartsNoSecondCloseThatWouldEndIt() async throws {
        try await openHistory("printf 'item=a\\ntitle=Note\\ntext=words\\n'")
        model.followHint()
        _ = model.handleKey(peekKey)
        try await wait("the grown peek") { self.model.isPeekGrown }
        host.heldEnds = []

        _ = model.handleKey(peekKey)
        model.takePeek()

        XCTAssertEqual(host.heldEnds?.count, 1)
        XCTAssertNotNil(model.peekRect)
        XCTAssertEqual(model.peek?.look, .text("words"))
    }
}
