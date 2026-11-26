import XCTest
@testable import OpenspotCore

@MainActor
final class RowHandOffTests: AttachmentCase {
    private let tab = ActionKey(name: "tab")

    private func openHistory(_ rows: String) async throws {
        try script("history", toml: "title = 'History'\n\n[on]\n\"sheet.open\" = true", "printf '\(rows)'")
        await open()
        model.press("history")
        try await wait("the open list") { self.model.transition.phase == .open && !self.titles.isEmpty }
    }

    func testTabOnARowWithALinkHandsItToTheActionsThatTakeIt() async throws {
        try taker(takes: "'url'")
        try await openHistory("item=a\\ntitle=A page\\nurl=https://a.com\\n")

        XCTAssertTrue(model.handleKey(tab))

        try await wait("the grid with the row's value") { self.model.openSheetID == nil && self.model.attachments.isOn }
        XCTAssertEqual(model.attachments.selectedChip?.value, AttachmentValue(url: "https://a.com", title: "A page"))
        XCTAssertEqual(model.visible.map(\.state.title), ["keep"])

        model.runSelected()

        try await wait("the hand-off") { self.log("keep-drops").count == 2 }
        XCTAssertEqual(log("keep-drops"), ["input.url=https://a.com", "input.title=A page"])
    }

    func testTabOnARowWithATextHandsTheText() async throws {
        try taker(takes: "'text'")
        try await openHistory("item=a\\ntitle=Note\\ntext=two\\\\nlines\\n")

        XCTAssertTrue(model.handleKey(tab))

        try await wait("the grid with the row's value") { self.model.attachments.isOn }
        XCTAssertEqual(model.attachments.selectedChip?.value, AttachmentValue(text: "two\nlines", title: "Note"))
    }

    func testTabOnARowWithNoValueDoesNothingToTheSheet() async throws {
        try taker(takes: "'url'")
        try await openHistory("item=a\\ntitle=Plain\\n")

        _ = model.handleKey(tab)

        XCTAssertEqual(model.openSheetID, "history")
        XCTAssertFalse(model.attachments.isOn)
    }

    func testTabOnARowNoSpotTakesDoesNothingToTheSheet() async throws {
        try taker(takes: "'url'")
        try await openHistory("item=a\\ntitle=Note\\ntext=words\\n")

        _ = model.handleKey(tab)

        XCTAssertEqual(model.openSheetID, "history")
        XCTAssertFalse(model.attachments.isOn)
    }
}
