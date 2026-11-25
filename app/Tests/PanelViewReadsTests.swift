import XCTest
@testable import OpenspotCore

@MainActor
final class PanelViewReadsTests: XCTestCase {
    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: FakeHost!
    private var model: SpotsModel!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-reads-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        suite = "openspot-reads-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let host = FakeHost()
        self.host = host
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path],
            home: folder,
            defaults: defaults
        )
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2, prepare: { await host.prepare($0, glyphs: $1) }))
        host.model = model
    }

    override func tearDown() async throws {
        model.quit()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: folder)
    }

    private var spots: URL {
        folder.appendingPathComponent("spots", isDirectory: true)
    }

    private func openList() async throws {
        try TestSpot(toml: "", body: "printf 'item=a\\ntitle=Apple\\n\\nitem=b\\ntitle=Banana\\n'").write(to: spots.spotFile("list"))
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("list")
        try await wait("the open list") { model.transition.phase == .open && model.openSheetID == "list" && model.openItems?.shown.count == 2 }
    }

    func testAScrollOfTheGridTellsNoReaderOfTheSheetsCardWhileNoSheetShows() async throws {
        model.gridScrolled(to: 10)
        nonisolated(unsafe) var changed = false
        withObservationTracking { _ = model.cardScroll } onChange: { changed = true }

        model.gridScrolled(to: 40)

        XCTAssertFalse(changed)
        XCTAssertEqual(model.gridScroll, 40)
    }

    func testASheetGrowsFromWhereItsCardWasScrolledToAndAScrollWhileItShowsTellsNoReader() async throws {
        model.gridScrolled(to: 40)

        try await openList()

        XCTAssertEqual(model.cardScroll, 40)
        nonisolated(unsafe) var changed = false
        withObservationTracking { _ = model.cardScroll } onChange: { changed = true }
        model.gridScrolled(to: 60)
        XCTAssertFalse(changed)
    }

    func testASheetClosesToWhereItsCardIsScrolledToNow() async throws {
        try await openList()
        model.gridScrolled(to: 60)

        model.transition.hide(moves: true)

        XCTAssertEqual(model.transition.phase, .closing)
        XCTAssertEqual(model.cardScroll, 60)
    }

    private func showTwoCards() async throws -> (list: Int, other: Int) {
        try TestSpot(toml: "", body: "printf 'item=a\\ntitle=Apple\\n\\nitem=b\\ntitle=Banana\\n'").write(to: spots.spotFile("list"))
        try TestSpot(toml: "", body: "true").write(to: spots.spotFile("other"))
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        let list = try XCTUnwrap(model.visible.firstIndex { $0.id == "list" })
        let other = try XCTUnwrap(model.visible.firstIndex { $0.id == "other" })
        model.selected = list
        return (list, other)
    }

    func testASheetThatOpensAndClosesTellsNoReaderOfWhatTheRingAndFocusOfAnotherCardRead() async throws {
        let cards = try await showTwoCards()
        XCTAssertTrue(model.marksMenu(ofCard: cards.list))
        nonisolated(unsafe) var changed = false
        withObservationTracking { _ = (model.marksMenu(ofCard: cards.other), model.focus(ofCard: cards.other)) } onChange: { changed = true }

        model.press("list")
        try await wait("the open list") { model.transition.phase == .open && model.openSheetID == "list" }
        XCTAssertFalse(model.marksMenu(ofCard: cards.list))
        model.closeSheet(moving: false)

        XCTAssertFalse(changed)
    }

    func testASheetThatOpensTellsTheReaderOfTheSelectedCardsMenuMark() async throws {
        let cards = try await showTwoCards()
        nonisolated(unsafe) var changed = false
        withObservationTracking { _ = model.marksMenu(ofCard: cards.list) } onChange: { changed = true }

        model.press("list")
        try await wait("the open list") { model.transition.phase == .open && model.openSheetID == "list" }

        XCTAssertTrue(changed)
    }
}
