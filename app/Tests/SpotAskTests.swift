import XCTest
@testable import OpenspotCore

@MainActor
final class SpotAskTests: PanelCase {
    private var client: URL!

    override func setUp() async throws {
        try await super.setUp()
        client = folder.appendingPathComponent("A.app/Contents/Helpers/openspot")
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: client)
        takeCalls()
        try script("picker", toml: "title = 'Picker'", """
        case "$1" in
          show) printf 'text=morning\\ntitle=Morning\\n\\ntext=evening\\ntitle=Evening\\n' ;;
          open) '\(client.path)' spot reply "$2" ;;
        esac
        """)
        try script("asker", toml: "title = 'Asker'\noffers = ['search']", "[ \"$1\" = show ] && printf 'text=x\\ntitle=Snooze This\\n'; exit 0")
        await model.reload()
    }

    private func ask(_ id: String, as spot: String = "asker", title: String? = nil) throws -> Task<CommandAnswer, Never> {
        let api = try XCTUnwrap(model.runs.api)
        let caller = SpotCaller(spot: try XCTUnwrap(model.sheets[spot]?.spot))
        let words = ["spot", "ask", id] + (title.map { ["--title", $0] } ?? [])
        let work = try XCTUnwrap(api.work(for: CommandRequest(arguments: words, folder: folder.path, caller: caller), input: { "" }))
        return Task { await work() }
    }

    private func waitForPicker() async throws {
        try await wait("the open picker") { self.model.transition.phase == .open && self.titles == ["Morning", "Evening"] }
    }

    func testAnAskPrintsWhatTheAskedSpotReplies() async throws {
        let asking = try ask("picker")
        try await waitForPicker()

        model.sheets["picker"]?.list.select(run: "evening")
        model.runSelectedItem()

        let answer = await asking.value
        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(answer.output, "evening\n")
        XCTAssertEqual(host.dismissals, 1)
    }

    func testAnAskEndsWithNoValueWhenTheSheetClosesWithNoReply() async throws {
        let asking = try ask("picker")
        try await waitForPicker()

        XCTAssertTrue(model.handleKey(toGrid))

        let answer = await asking.value
        XCTAssertEqual(answer.code, 1)
        XCTAssertEqual(answer.output, "")
    }

    func testANewerAskEndsTheOlderOne() async throws {
        let older = try ask("picker")
        try await waitForPicker()
        let newer = try ask("picker")

        let first = await older.value
        XCTAssertEqual(first.code, 1)
        model.runSelectedItem()
        let second = await newer.value
        XCTAssertEqual(second.output, "morning\n")
    }

    func testAnAskFromAnOpenSheetIsAStepOfItsFlowAndBackEndsIt() async throws {
        model.isShown = true
        model.panelWillShow()
        model.press("asker")
        try await wait("the asker") { self.model.transition.phase == .open && self.titles == ["Snooze This"] }

        let asking = try ask("picker")
        try await waitForPicker()

        XCTAssertEqual(model.flow.pages.map(\.spot), ["asker", "picker"])
        XCTAssertTrue(model.handleKey(escape))
        let answer = await asking.value
        XCTAssertEqual(answer.code, 1)
        try await wait("the asker again") { self.model.flow.current?.spot == "asker" }
    }

    func testAnAskFromARowOfTheMainSearchGrowsFromThatRowAndShrinksBackIntoIt() async throws {
        model.isShown = true
        model.panelWillShow()
        model.searchText = "snooze"
        try await wait("the row of the asker") { self.model.visible.contains { $0.spot.id == "asker" && $0.item?.run == "x" } }
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.spot.id == "asker" && $0.item?.run == "x" })
        let row = try XCTUnwrap(model.selectedEntry).id

        let asking = try ask("picker")
        try await waitForPicker()

        XCTAssertEqual(SpotSheetCard.of(model.openSheetID, in: model)?.id, row)
        host.heldEnds = []
        XCTAssertTrue(model.handleKey(toGrid))
        XCTAssertEqual(model.transition.phase, .closing)
        XCTAssertEqual(SpotSheetCard.of(model.transition.id, in: model)?.id, row)
        host.heldEnds?.forEach { $0() }
        host.heldEnds = nil
        _ = await asking.value
    }

    func testAnAskNamesThePageItOpensWithItsTitle() async throws {
        let asking = try ask("picker", title: "Example page")
        try await waitForPicker()

        XCTAssertEqual(model.flow.current?.title, "Example page")
        let entry = try XCTUnwrap(model.sheetEntry(model.openSheetID))
        XCTAssertEqual(model.sheetContent(of: entry).state.title, "Example page")
        XCTAssertTrue(model.handleKey(toGrid))
        _ = await asking.value
    }

    func testAnAskedPageKeepsItsTitleWhileItStepsBack() async throws {
        model.isShown = true
        model.panelWillShow()
        model.press("asker")
        try await wait("the asker") { self.model.transition.phase == .open && self.titles == ["Snooze This"] }
        let asking = try ask("picker", title: "Example page")
        try await waitForPicker()

        XCTAssertEqual(model.sheets["picker"]?.shownState.title, "Example page")
        host.heldEnds = []
        XCTAssertTrue(model.handleKey(escape))

        XCTAssertEqual(model.flowEdges.leavingPage?.spot, "picker")
        XCTAssertEqual(model.flowEdges.leavingPage?.state.title, "Example page")
        host.heldEnds?.forEach { $0() }
        host.heldEnds = nil
        _ = await asking.value
    }

    func testASpotCannotAskItself() async throws {
        let answer = await (try ask("picker", as: "picker")).value

        XCTAssertEqual(answer.code, 1)
        XCTAssertTrue(answer.errors.contains("cannot ask itself"), answer.errors)
    }

    func testAReplyWithNoAskFails() async throws {
        let api = try XCTUnwrap(model.runs.api)
        let caller = SpotCaller(spot: try XCTUnwrap(model.sheets["picker"]?.spot))
        let work = try XCTUnwrap(api.work(for: CommandRequest(arguments: ["spot", "reply", "x"], folder: folder.path, caller: caller), input: { "" }))

        let answer = await work()

        XCTAssertEqual(answer.code, 1)
    }
}
