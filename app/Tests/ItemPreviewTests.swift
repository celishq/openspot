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

    func testTheShownHintSaysClosePreviewOnceThePreviewOpens() async throws {
        try await openHistory("printf 'item=a\\ntitle=Note\\ntext=words\\n'")
        model.followHint()

        _ = model.handleKey(space)

        try await wait("the hint of the open preview") { self.model.sheetHint.groups.contains { $0.words == "Close Preview" } }
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

    private func colors() throws {
        try script("colors", toml: """
        title = 'Colors'

        [on]
        "item.preview" = true

        [types.color]
        title = "Color"
        match = '^#[0-9a-fA-F]{6}$'

        [actions.copy-rgba]
        title = "Copy as RGBA"
        type = "color"
        """, """
        input=$(cat)
        printf '%s|%s|%s\\n' "$1" "$(printf '%s\\n' "$input" | sed -n 's/^input.type=//p')" "$(printf '%s\\n' "$input" | sed -n 's/^input.item.text=//p')" >> '\(folder.appendingPathComponent("colors").path)'
        [ "$1" = item.preview ] && printf 'text=swatch\\ntitle=rgba\\n'
        exit 0
        """)
    }

    private var colorRuns: [String] {
        ((try? String(contentsOf: folder.appendingPathComponent("colors"), encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    func testARowWhoseTextIsOfATypeShowsThePreviewAndTheActionsOfTheSpotThatDeclaresIt() async throws {
        try colors()
        try await openHistory("printf 'item=a\\ntitle=Red\\ntext=#ff0000\\n\\nitem=b\\ntitle=Note\\ntext=words\\n'")

        _ = model.handleKey(space)

        try await wait("the preview of the type") { self.model.preview?.isOwn == true }
        model.closeMenu()
        model.closeMenu()
        XCTAssertEqual(colorRuns, ["item.preview|color|#ff0000"])
        let red = try XCTUnwrap(model.target)
        XCTAssertEqual(model.actionMenu(on: red)?.rows.map(\.title).contains("Copy as RGBA"), true)

        _ = model.handleSearchKey(ActionKey(name: "down"))

        XCTAssertEqual(model.preview?.isOwn, false)
        let note = try XCTUnwrap(model.target)
        XCTAssertEqual(model.actionMenu(on: note)?.rows.map(\.title).contains("Copy as RGBA"), false)
    }

    func testATypedActionRunsWithTheRowAndIsNoCommandOfItsOwn() async throws {
        try colors()
        try await openHistory("printf 'item=a\\ntitle=Red\\ntext=#ff0000\\n'")
        let red = try XCTUnwrap(model.target)
        let offer = try XCTUnwrap(model.typedActions(on: try XCTUnwrap(red.item)).first)

        model.run(offer.action, offeredBy: offer.owner, on: red)

        try await wait("the action's run") { self.colorRuns.contains("copy-rgba||#ff0000") }
        XCTAssertEqual(model.sheets["colors"]?.spot.commands.map(\.id), [])
    }
}
