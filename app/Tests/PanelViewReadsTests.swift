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
        try TestSpot(toml: "on = ['sheet.open']", body: "printf 'row=a\\ntitle=Apple\\n\\nrow=b\\ntitle=Banana\\n'").write(to: spots.spotFile("list"))
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
}
