import XCTest
@testable import OpenspotCore

@MainActor
final class ItemPreviewTests: PanelCase {
    private let space = ActionKey(name: " ")

    private func openHistory(_ rows: String, on: String = "") async throws {
        try script("history", toml: "title = 'History'\n\n[on]\n\"sheet.open\" = true\(on)", rows)
        await model.reload()
        model.press("history")
        try await wait("the open list") { self.model.openSheet?.list.shown.isEmpty == false }
    }

    func testSpaceOnARowShowsItsPreviewBesideTheSheetAndFollowsTheSelection() async throws {
        try await openHistory("printf 'item=a\\ntitle=Note\\ntext=two\\\\nlines\\n\\nitem=b\\ntitle=Page\\nurl=https://a.com/x\\n'")

        XCTAssertTrue(model.handleKey(space))

        XCTAssertEqual(model.preview?.run, "a")
        XCTAssertEqual(host.previews.compactMap { $0 }.count, 1)
        XCTAssertTrue(model.hint.contains("Space Close Preview"), model.hint)

        _ = model.handleSearchKey(ActionKey(name: "down"))

        XCTAssertEqual(model.preview?.run, "b")
        XCTAssertEqual(host.previews.count, 1)
    }

    func testEscapeClosesThePreviewFirstAndThenTheSheet() async throws {
        try await openHistory("printf 'item=a\\ntitle=Note\\ntext=words\\n'")
        _ = model.handleKey(space)

        XCTAssertTrue(model.handleKey(ActionKey(name: "escape")))

        XCTAssertNil(model.preview)
        XCTAssertEqual(host.previews.last, .some(nil))
        XCTAssertEqual(model.openSheetID, "history")
    }

    func testARowWithNothingToShowHasNoPreviewAndSpaceGoesOn() async throws {
        try await openHistory("printf 'item=a\\ntitle=Plain\\n'")

        XCTAssertFalse(model.handleKey(space))
        XCTAssertNil(model.preview)
        XCTAssertFalse(model.hint.contains("Preview"), model.hint)
    }

    func testASpotThatAnswersItemPreviewDrawsItsOwn() async throws {
        try await openHistory("""
        case "$1" in
          item.preview) printf 'text=own\\ntitle=%s\\n' "$(sed -n 's/^input.item.text=//p')" ;;
          *) printf 'item=a\\ntitle=Red\\ntext=#ff0000\\n' ;;
        esac
        """, on: "\n\"item.preview\" = true")

        _ = model.handleKey(space)

        try await wait("the spot's own preview") { self.model.preview?.isOwn == true }
        XCTAssertEqual(model.preview?.blocks.first?.value("title"), "#ff0000")
    }

    func testHidingThePanelClosesThePreview() async throws {
        try await openHistory("printf 'item=a\\ntitle=Note\\ntext=words\\n'")
        _ = model.handleKey(space)

        model.panelWillHide()

        XCTAssertNil(model.preview)
        XCTAssertEqual(host.previews.last, .some(nil))
    }
}
