import XCTest
@testable import OpenspotCore

/// Proves the history of the panel: a row that opens a page, a spot that opens another, and the keys that move back,
/// forward and to the grid.
@MainActor
final class SheetPagesModelTests: XCTestCase {
    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: TestHost!
    private var model: SpotsModel!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-pages-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        suite = "openspot-pages-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let host = TestHost()
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

    private let back = ActionKey(name: "[", isCommand: true)
    private let forward = ActionKey(name: "]", isCommand: true)
    private let escape = ActionKey(name: "escape")
    private let toGrid = ActionKey(name: "escape", isCommand: true)

    private func script(_ name: String, header: String, _ body: String) throws {
        let lines = header.split(separator: "\n", omittingEmptySubsequences: false).map { "# \($0)" }.joined(separator: "\n")
        try "#!/bin/sh\n\(lines)\n\(body)\n".writeScript(to: spots.spotFile(name))
    }

    private func wait(_ what: String, until condition: () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited for \(what)")
    }

    private var titles: [String] {
        model.openItems?.shown.map(\.title) ?? []
    }

    /// Opens a list whose row `a` opens its page, which shows one row named after the page.
    private func openList() async throws {
        try script("list", header: "on=sheet.open", """
        if [ -n "$OPENSPOT_PAGE" ]; then printf 'row=x\\ntitle=Detail %s\\n' "$OPENSPOT_PAGE"; else printf 'row=a\\ntitle=A\\npage=true\\n'; fi
        """)
        try script("other", header: "on=sheet.open", "printf 'row=o\\ntitle=Other\\n'")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("list")
        try await wait("the open list") { model.transition.phase == .open && titles == ["A"] }
    }

    private func openPage() async throws {
        model.runSelectedItem()
        try await wait("the page") { titles == ["Detail a"] }
    }

    func testARowThatOpensAPagePushesItAndKeepsThePanelOpen() async throws {
        try await openList()

        try await openPage()

        XCTAssertEqual(model.history.current, SheetPage(spot: "list", page: "a"))
        XCTAssertEqual(model.openList, "list")
        XCTAssertEqual(host.dismissals, 0)
    }

    func testBackShowsTheSheetBeforeAtOnceAndForwardShowsThePageAgain() async throws {
        try await openList()
        try await openPage()

        XCTAssertTrue(model.handleKey(back))
        XCTAssertEqual(titles, ["A"])
        XCTAssertEqual(model.history.ahead, SheetPage(spot: "list", page: "a"))

        XCTAssertTrue(model.handleKey(forward))
        XCTAssertEqual(titles, ["Detail a"])
    }

    func testEscClearsTheSearchThenStepsBackThenClosesTheSheet() async throws {
        try await openList()
        try await openPage()
        model.searchText = "de"

        XCTAssertTrue(model.handleKey(escape))
        XCTAssertEqual(model.searchText, "")
        XCTAssertTrue(model.handleKey(escape))
        XCTAssertEqual(titles, ["A"])
        XCTAssertEqual(model.openList, "list")
        XCTAssertTrue(model.handleKey(escape))

        try await wait("the grid") { model.openList == nil }
        XCTAssertNil(model.history.current)
    }

    func testCommandEscGoesToTheGridFromAPageAndTheSpotShowsItsFirstSheetNextTime() async throws {
        try await openList()
        try await openPage()

        XCTAssertTrue(model.handleKey(toGrid))

        try await wait("the grid") { model.openList == nil }
        XCTAssertNil(model.history.current)
        XCTAssertNil(model.sheets["list"]?.page)
    }

    func testASpotThatOpensAnotherPushesItAndBackComesHome() async throws {
        try await openList()

        XCTAssertTrue(model.openSheet("other"))
        try await wait("the other sheet") { model.openList == "other" && titles == ["Other"] }

        XCTAssertTrue(model.handleKey(back))
        try await wait("the first sheet") { model.openList == "list" && titles == ["A"] }
        XCTAssertEqual(model.history.ahead, SheetPage(spot: "other"))
    }

    func testAPageOpensFromOutsideTheSpot() async throws {
        try await openList()

        XCTAssertTrue(model.openSheet("list", page: "b"))

        try await wait("the page") { titles == ["Detail b"] }
        XCTAssertEqual(model.history.pages, [SheetPage(spot: "list"), SheetPage(spot: "list", page: "b")])
    }

    func testTheHintOfAPageSaysThatEscGoesBack() async throws {
        try script("info", header: "on=sheet.open", """
        if [ -n "$OPENSPOT_PAGE" ]; then printf 'text=detail\\ntitle=Detail\\n'; else printf 'text=first\\ntitle=First\\n\\nrow=a\\ntitle=A\\npage=true\\n'; fi
        """)
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("info")
        try await wait("the first sheet") { model.openPanel?.parts.first?.title == "First" }
        XCTAssertTrue(model.openSheet("info", page: "a"))

        try await wait("the page of parts") { model.openPanel?.parts.first?.title == "Detail" }

        XCTAssertEqual(model.hint, "Esc Back")
    }

    func testAPageOfTheSameSheetSlidesInFromTheSideItComesFrom() async throws {
        try await openList()
        host.motions = []
        try await openPage()
        try await wait("the slide from the right to rest") { host.motions.contains(.slide) && model.slideOffset == 0 }
        XCTAssertTrue(host.slideStarts.contains { $0 > 0 })
        host.slideStarts = []

        XCTAssertTrue(model.handleKey(back))

        try await wait("the slide from the left to rest") { model.slideOffset == 0 && host.slideStarts.contains { $0 < 0 } }
    }
}
