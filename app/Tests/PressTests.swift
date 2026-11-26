import XCTest
@testable import OpenspotCore

@MainActor
final class PressTests: PanelCase {
    private func takes(stale: Bool = false, of press: () -> Void) async -> [Int] {
        model.followHint()
        await Task { @MainActor in }.value
        if stale { model.hintIsStale = true }
        let start = model.hintTakes
        press()
        let atEnd = model.hintTakes - start
        await Task { @MainActor in }.value
        return [atEnd, model.hintTakes - start]
    }

    private func showGrid(_ names: String...) async throws {
        for name in names { try script(name, toml: "title = '\(name)'", ":") }
        await model.reload()
        model.isShown = true
        model.panelWillShow()
    }

    private func openChoice() async throws {
        try script("snooze", toml: "title = 'Snooze'\n[settings]\nmorning = { type = 'choice', options = ['7:00', '8:00', '9:00'] }", ":")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        XCTAssertTrue(model.changeSetting("morning", of: "snooze"))
        XCTAssertNotNil(model.form)
    }

    func testAPickWorksTheHintOutOnceByTheEndOfThePress() async throws {
        try await openList()
        let entry = try XCTUnwrap(model.openEntry)
        let item = try XCTUnwrap(model.openItems?.shown.first)

        let takes = await takes { model.pick(item, of: entry) }

        XCTAssertEqual(takes, [1, 1])
        XCTAssertEqual(model.sheetHint, HintWords(model.hint))
    }

    func testARunOfARowWorksTheHintOutOnceByTheEndOfThePress() async throws {
        try await openList()
        let item = try XCTUnwrap(model.openItems?.shown.first)

        let takes = await takes { model.runItem(item) }

        XCTAssertEqual(takes, [1, 1])
        XCTAssertEqual(model.sheetHint, HintWords(model.hint))
    }

    func testAChoiceOfAFormWorksTheHintOutOnceByTheEndOfThePress() async throws {
        try await openChoice()

        let takes = await takes { model.chooseFormOption(SpotItem(title: "9:00", run: "9:00")) }

        XCTAssertNil(model.form)
        XCTAssertEqual(takes, [1, 1])
    }

    func testAKeystrokeInAFormWorksAStaleHintOutOnceByTheEndOfThePress() async throws {
        try await openChoice()

        let takes = await takes(stale: true) { model.setFormValue("8:00", for: "morning") }

        XCTAssertEqual(takes, [1, 1])
    }

    func testAReturnThatMakesARowFromTheSearchWorksTheHintOutOnceByTheEndOfThePress() async throws {
        try script("list", toml: "[actions.start]\ninputs.minutes = { type = 'text', required = true }\n[on]\n\"sheet.open\" = true", """
        case "$1" in
          start) : ;;
          *) printf 'button=start\\ntitle=Keep awake for…\\nscope=spot\\nclose=false\\n\\nitem=a\\ntitle=Apple\\n' ;;
        esac
        """)
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("list")
        try await wait("the open list") { self.model.openSheetID == "list" && self.model.openItems?.shown.count == 1 }
        model.search("45")
        try await wait("the row that makes the action") { self.model.createAction != nil }

        let takes = await takes { model.createFromSearch() }

        XCTAssertNotNil(model.form)
        XCTAssertEqual(takes, [1, 1])
    }

    func testAKeystrokeInTheActionsMenuWorksAStaleHintOutOnceByTheEndOfThePress() async throws {
        try script("weather", toml: "title = 'Weather'\n[actions.hot]\ntitle = 'Hot'\n[actions.cold]\ntitle = 'Cold'\n[on]\n\"sheet.open\" = true", ":")
        _ = try model.files.config.change { $0.arrangement.set(isOnGrid: true, of: "weather") }
        await model.reload()
        model.isShown = true
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "weather" })
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))

        let takes = await takes(stale: true) { model.searchMenu("h") }

        XCTAssertEqual(takes, [1, 1])
    }

    func testAPressOfAFloatingCardWorksAStaleHintOutOnceByTheEndOfThePress() async throws {
        try await showGrid("notes")

        let takes = await takes(stale: true) { model.pressFloatCard("notes") }

        XCTAssertEqual(takes, [1, 1])
    }

    func testALandingWorksAStaleHintOutOnceByTheEndOfThePress() async throws {
        try await showGrid("notes")

        let takes = await takes(stale: true) { model.land("notes") }

        XCTAssertEqual(host.landings, ["notes"])
        XCTAssertEqual(takes, [1, 1])
    }

    func testADragOutWorksAStaleHintOutOnceByTheEndOfThePress() async throws {
        try await openList()
        let item = try XCTUnwrap(model.openItems?.shown.first)

        let takes = await takes(stale: true) { model.dragOut([item], of: "list") }

        XCTAssertEqual(takes, [1, 1])
    }

    func testChangingTheColumnsWorksAStaleHintOutOnceByTheEndOfThePress() async throws {
        try await showGrid("notes")
        model.beginEditing()

        let takes = await takes(stale: true) { model.set(columns: 6) }

        XCTAssertEqual(model.grid, GridLayout(columns: 6))
        XCTAssertEqual(takes, [1, 1])
    }

    func testTakingASpotOffTheGridWorksAStaleHintOutOnceByTheEndOfThePress() async throws {
        try await showGrid("notes", "mail")
        model.beginEditing()

        let takes = await takes(stale: true) { model.takeOffGrid("notes") }

        XCTAssertFalse(model.visible.contains { $0.id == "notes" && $0.isOnGrid })
        XCTAssertEqual(takes, [1, 1])
    }

    func testASheetThatClosesWhileALoadTakesItsSpotAwayKeepsItsLookAndShrinksIntoTheFieldToTheEndOfItsMotion() async throws {
        try await openList()
        host.heldEnds = []
        XCTAssertTrue(model.handleKey(ActionKey(name: "escape")))
        try FileManager.default.removeItem(at: spots.spotFile("list"))

        await model.reload()

        XCTAssertNil(model.card(id: "list"))
        XCTAssertEqual(model.transition.phase, .closing)
        XCTAssertEqual(model.sheetEntry("list")?.state.title, "List")
        XCTAssertNil(SpotSheetCard.of("list", in: model))
        XCTAssertEqual(host.disagreements, 0)
        let ends = host.heldEnds ?? []
        host.heldEnds = nil
        ends.forEach { $0() }
        XCTAssertEqual(model.transition.phase, .closed)
        XCTAssertNil(model.sheetEntry("list"))
    }

    func testASearchDuringTheCloseOfASheetAimsTheCloseAtWhereItsCardIsNow() async throws {
        try await openList()
        host.heldEnds = []
        XCTAssertTrue(model.handleKey(ActionKey(name: "escape")))
        let before = SpotSheetCard.of("list", in: model)?.placement

        model.search("List")

        let index = try XCTUnwrap(model.visible.firstIndex { $0.id == "list" })
        let now = model.placements.first { $0.index == index }
        XCTAssertNotEqual(now, before)
        XCTAssertEqual(SpotSheetCard.of("list", in: model)?.placement, now)
        let ends = host.heldEnds ?? []
        host.heldEnds = nil
        ends.forEach { $0() }
    }

    func testAnOpenDuringTheCloseOfASheetWhoseSpotALoadRemovedKeepsItsLookUntilTheCloseEnds() async throws {
        try await openList()
        host.heldEnds = []
        XCTAssertTrue(model.handleKey(ActionKey(name: "escape")))
        try FileManager.default.removeItem(at: spots.spotFile("list"))
        await model.reload()

        model.press("other")

        XCTAssertEqual(model.transition.id, "list")
        XCTAssertEqual(model.transition.phase, .closing)
        XCTAssertEqual(model.sheetEntry("list")?.state.title, "List")
        let ends = host.heldEnds ?? []
        host.heldEnds = nil
        ends.forEach { $0() }
    }

    func testAnOpenOfASheetTellsNoReaderOfTheClosingSheet() async throws {
        try script("list", toml: "title = 'List'", "printf 'item=a\\ntitle=A\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        nonisolated(unsafe) var told = false
        withObservationTracking { _ = model.closingSheet } onChange: { told = true }

        model.press("list")
        try await wait("the open") { self.model.openSheetID == "list" }

        XCTAssertFalse(told)
    }
}
