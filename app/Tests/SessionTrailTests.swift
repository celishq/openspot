import XCTest
@testable import OpenspotCore

@MainActor
final class SessionTrailTests: PanelCase {
    private var clock = FakeClock()
    private let close = ActionKey(name: "w", isCommand: true)

    override func setUp() async throws {
        try await super.setUp()
        let files = model.files
        model.quit()
        model = SpotsModel(host: host, files: files, runs: SpotRuns(opening: SheetOpening(motionLength: motionLength), clock: clock.value, stopPause: stopPause, timeline: files.timeline))
        host.model = model
        try script("parts", toml: "title = 'Parts'", "printf 'frame=\\nclass=gap-part\\n\\ntext=a\\ntitle=A\\n'")
        try script("other", toml: "title = 'Other'", "printf 'item=o\\ntitle=Other\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
    }

    private func visit(_ id: String, for seconds: TimeInterval = 3) async throws {
        model.pushFirst(id, moving: true)
        try await wait("the open \(id)") { self.model.openSheetID == id && self.model.transition.phase == .open }
        clock.advance(by: seconds)
        XCTAssertTrue(model.handleKey(escape))
        try await wait("the grid after \(id)") { self.model.openSheetID == nil }
    }

    private func walk(_ key: ActionKey, to id: String?) async throws {
        XCTAssertTrue(model.handleKey(key))
        try await wait("the sheet \(id ?? "none")") { self.model.openSheetID == id && self.model.transition.phase != .opening }
    }

    func testCommandBracketOnTheGridBringsBackTheSheetThatEscLeft() async throws {
        try await visit("other")

        try await walk(back, to: "other")
    }

    func testAQuickLookIsNotKept() async throws {
        try await visit("other", for: 0.5)

        XCTAssertFalse(model.handleKey(back))
        XCTAssertNil(model.openSheetID)
    }

    func testCommandBracketWalksBackThroughTheVisitsAndForwardToTheGrid() async throws {
        try await visit("other")
        try await visit("parts")

        try await walk(back, to: "parts")
        try await walk(back, to: "other")
        try await walk(forward, to: "parts")
        try await walk(forward, to: nil)
    }

    func testARepeatVisitOfTheSamePlaceIsKeptOnce() async throws {
        try await visit("other")
        try await visit("other")

        try await walk(back, to: "other")
        XCTAssertTrue(model.handleKey(back))
        XCTAssertEqual(model.openSheetID, "other")
        XCTAssertEqual(model.trail.places.count, 1)
    }

    func testAVisitComesBackAfterCommandWAndAReopen() async throws {
        model.pushFirst("other", moving: true)
        try await wait("the open other") { self.model.openSheetID == "other" }
        clock.advance(by: 3)
        XCTAssertTrue(model.handleKey(close))
        model.isShown = true
        model.panelWillShow()
        XCTAssertNil(model.openSheetID)

        try await walk(back, to: "other")
    }

    func testARunMakesAQuickVisitWorthKeeping() async throws {
        model.pushFirst("other", moving: true)
        try await wait("the open other") { self.model.openSheetID == "other" }
        model.noteRun()
        XCTAssertTrue(model.handleKey(escape))
        try await wait("the grid") { self.model.openSheetID == nil }

        try await walk(back, to: "other")
    }

    private var visits: [TimelineEntry] {
        model.runs.timeline.list(Timeline.Query(spots: [SpotsModel.sessionsSpot]), at: clock.time) ?? []
    }

    func testAKeptVisitIsAnEntryOfTheTimelineThatNamesThePlaceItOpens() async throws {
        try await visit("other")

        XCTAssertTrue(model.handleKey(back))
        try await wait("the visit entry") { self.visits.count == 1 }
        let entry = try XCTUnwrap(visits.first)
        XCTAssertEqual(entry.opens, "other")
        XCTAssertNil(entry.opensRoute)
        XCTAssertEqual(entry.title, "Other")
        XCTAssertTrue(entry.block.contains("opens=other"))
    }

    func testARepeatVisitMovesItsEntryToTheTopAndAQuickLookWritesNone() async throws {
        try await visit("other")
        try await visit("parts", for: 0.5)
        try await visit("other")

        XCTAssertTrue(model.handleKey(back))
        try await wait("the visit entries") { self.visits.count == 1 && self.model.trail.places.count == 1 }
        XCTAssertEqual(visits.map(\.opens), ["other"])
    }
}
