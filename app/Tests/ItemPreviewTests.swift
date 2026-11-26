import XCTest
@testable import OpenspotCore

@MainActor
final class ItemPreviewTests: PanelCase {
    private let preview = ActionKey(name: "y", isCommand: true)

    private func openHistory(_ rows: String, on: String = "") async throws {
        try script("history", toml: "title = 'History'\n\n[on]\n\"sheet.open\" = true\(on)", rows)
        await model.reload()
        model.press("history")
        try await wait("the open list") { self.model.openSheet?.list.shown.isEmpty == false }
    }

    func testCommandYOnARowShowsItsPreviewBesideTheSheetAndFollowsTheSelection() async throws {
        try await openHistory("printf 'item=a\\ntitle=Note\\ntext=two\\\\nlines\\n\\nitem=b\\ntitle=Page\\nurl=https://a.com/x\\n'")

        XCTAssertTrue(model.handleKey(preview))

        XCTAssertEqual(model.preview?.run, "a")
        XCTAssertEqual(host.previews.compactMap { $0 }.count, 1)
        XCTAssertTrue(model.hint.contains("⌘Y Close Preview"), model.hint)

        _ = model.handleSearchKey(ActionKey(name: "down"))

        XCTAssertEqual(model.preview?.run, "b")
        XCTAssertEqual(host.previews.count, 1)
    }

    func testTheShownHintSaysClosePreviewOnceThePreviewOpens() async throws {
        try await openHistory("printf 'item=a\\ntitle=Note\\ntext=words\\n'")
        model.followHint()

        _ = model.handleKey(preview)

        try await wait("the hint of the open preview") { self.model.sheetHint.groups.contains { $0.words == "Close Preview" } }
    }

    func testEscapeClosesThePreviewFirstAndThenTheSheet() async throws {
        try await openHistory("printf 'item=a\\ntitle=Note\\ntext=words\\n'")
        _ = model.handleKey(preview)

        XCTAssertTrue(model.handleKey(ActionKey(name: "escape")))

        XCTAssertNil(model.preview)
        XCTAssertEqual(host.previews.last, .some(nil))
        XCTAssertEqual(model.openSheetID, "history")
    }

    func testARowWithNothingToShowHasNoPreviewAndCommandYGoesOn() async throws {
        try await openHistory("printf 'item=a\\ntitle=Plain\\n'")

        XCTAssertFalse(model.handleKey(preview))
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

        _ = model.handleKey(preview)

        try await wait("the spot's own preview") { self.model.preview?.isOwn == true }
        XCTAssertEqual(model.preview?.blocks.first?.value("title"), "#ff0000")
    }

    func testHidingThePanelClosesThePreview() async throws {
        try await openHistory("printf 'item=a\\ntitle=Note\\ntext=words\\n'")
        _ = model.handleKey(preview)

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
        icon = "swatch"
        match = '^(#[0-9a-fA-F]{6}|rgb\\(.*\\))$'

        [actions.copy-rgba]
        title = "Copy as RGBA"
        inputs.color = { type = "color", required = true }
        """, """
        input=$(cat)
        printf '%s|%s|%s\\n' "$1" "$(printf '%s\\n' "$input" | sed -n 's/^input.type=//p')" "$(printf '%s\\n' "$input" | sed -n 's/^input.item.text=//p')$(printf '%s\\n' "$input" | sed -n 's/^input.color=//p')" >> '\(folder.appendingPathComponent("colors").path)'
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

        _ = model.handleKey(preview)

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

    func testAnInputOfATypeThatNoTypesTableDeclaresIsAFault() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("typed-\(UUID().uuidString).sh")
        try "#!/bin/sh\n".writeScript(to: url, toml: "title = 'Paint'\n\n[actions.copy]\ntitle = 'Copy'\ninputs.color = { type = 'colr', required = true }")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try SpotFile(file: url, id: "paint")) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "spot.toml: [actions.copy] inputs.color has an unknown type: colr. Use \(ValueType.names), or declare it in [types.colr].")
        }
    }

    func testARowOfATypeWithAnIconTakesItsIconAndASwatchShowsItsColour() async throws {
        try colors()
        try await openHistory("printf 'item=a\\ntitle=Red\\ntext=#FF0000\\nicon=text.alignleft\\n\\nitem=b\\ntitle=Blue\\ntext=rgb(0 0 255)\\n\\nitem=c\\ntitle=Note\\ntext=words\\nicon=text.alignleft\\n'")

        XCTAssertEqual(model.openSheet?.list.shown.map(\.swatch), ["#ff0000", "#0000ff", nil])
        XCTAssertEqual(model.openSheet?.list.shown.last?.symbol, "text.alignleft")
    }

    func testAColourTextOfEachFormTurnsIntoItsHex() {
        let texts = ["#f00", "#FF3B30", "#ff3b3080", "rgb(255, 59, 48)", "rgba(0 122 255 / 50%)", "hsl(120, 100%, 25%)", "red", "#ff3b3"]

        XCTAssertEqual(texts.map(ColorText.hex), ["#ff0000", "#ff3b30", "#ff3b30", "#ff3b30", "#007aff", "#008000", nil, nil])
    }

    func testBlocksWhoseParentIsARowAreItsPreviewAndNoPartOfTheSheet() {
        let frame = Frame(text: "item=a\ntitle=A\n\ntext=big\nparent=a\ntitle=Big\nclass=font-title\n\nitem=b\ntitle=B\n")

        XCTAssertEqual(frame.errors, [])
        XCTAssertEqual(frame.items.map(\.title), ["A", "B"])
        XCTAssertEqual(frame.items.first?.preview.map { $0.value("title") }, ["Big"])
        XCTAssertEqual(frame.items.last?.preview, [])
    }

    func testARowThatCarriesItsPreviewShowsItWithNoRunOfTheSpot() async throws {
        try await openHistory("printf 'item=a\\ntitle=Note\\n\\ntext=big\\nparent=a\\ntitle=Big\\n'")

        XCTAssertTrue(model.handleKey(preview))

        XCTAssertEqual(model.preview?.isOwn, true)
        XCTAssertEqual(model.preview?.blocks.first?.value("title"), "Big")
    }

    func testThePreviewIsAskedForTheRowsBesideTheSelectedOneAhead() async throws {
        try colors()
        try await openHistory("printf 'item=a\\ntitle=Red\\ntext=#ff0000\\n\\nitem=b\\ntitle=Blue\\ntext=#0000ff\\n\\nitem=c\\ntitle=Green\\ntext=#00ff00\\n'")

        _ = model.handleKey(preview)

        try await wait("the asks of the row and the next one") { self.colorRuns.count == 2 }
        XCTAssertEqual(colorRuns, ["item.preview|color|#ff0000", "item.preview|color|#0000ff"])
        _ = model.handleSearchKey(ActionKey(name: "down"))
        try await wait("the next row's preview at once") { self.model.preview?.isOwn == true && self.model.preview?.run == "b" }
    }
}
