import XCTest
@testable import OpenspotCore

@MainActor
final class SessionWindowTests: PanelCase {
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
        try await waitForSessions()
    }

    private func waitForSessions() async throws {
        try await wait("the read of the sessions") { !self.model.isReadingSessions }
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
        XCTAssertEqual(model.window.stops.count, 1)
    }

    func testAVisitComesBackAfterCommandWAndAReopen() async throws {
        model.pushFirst("other", moving: true)
        try await wait("the open other") { self.model.openSheetID == "other" }
        clock.advance(by: 3)
        XCTAssertTrue(model.handleKey(close))
        model.isShown = true
        model.panelWillShow()
        XCTAssertNil(model.openSheetID)
        try await waitForSessions()

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
        XCTAssertEqual(entry.session?.flow.pages.map(\.spot), ["other"])
        XCTAssertEqual(entry.title, "Other")
        XCTAssertTrue(entry.block.contains("session=\(entry.id)\nsession.spot=other\nsession.steps=1"))
    }

    func testARepeatVisitMovesItsEntryToTheTopAndAQuickLookWritesNone() async throws {
        try await visit("other")
        try await visit("parts", for: 0.5)
        try await visit("other")

        XCTAssertTrue(model.handleKey(back))
        try await wait("the visit entries") { self.visits.count == 1 && self.model.window.stops.count == 1 }
        XCTAssertEqual(visits.map { $0.session?.flow.current?.spot }, ["other"])
    }

    func testCommandYOnACardOpensTheTimelinePageAboutThatSpot() async throws {
        let core = folder.appendingPathComponent("core", isDirectory: true)
        try FileManager.default.createDirectory(at: core, withIntermediateDirectories: true)
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        try FileManager.default.createSymbolicLink(at: core.appendingPathComponent("openspot.spot"), withDestinationURL: repo.appendingPathComponent("spots/openspot.spot"))
        await model.reload()
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "other" })

        XCTAssertTrue(model.handleKey(ActionKey(name: "y", isCommand: true)))

        try await wait("the timeline page") { self.model.flow.current == FlowSheet(spot: SpotsModel.timelineSpot, route: "about/other") }
    }

    func testTimeOnTheGridAfterAQuickLookDoesNotKeepIt() async throws {
        try await visit("other", for: 0.5)
        clock.advance(by: 3)

        XCTAssertFalse(model.handleKey(back))
        XCTAssertNil(model.openSheetID)
    }

    func testARunOnTheGridAfterAQuickLookDoesNotKeepTheLook() async throws {
        try await visit("other", for: 0.5)
        model.noteRun()

        XCTAssertFalse(model.handleKey(back))
        XCTAssertNil(model.openSheetID)
    }

    func testTheFirstCommandBracketOnTheGridSkipsThePlaceItShows() async throws {
        model.search("calc")
        model.noteRun()

        XCTAssertFalse(model.handleKey(back))
        XCTAssertEqual(model.searchText, "calc")
    }

    private func keptSession(of spot: String, route: String? = nil) throws -> String {
        var flow = Flow()
        flow.push(FlowSheet(spot: spot))
        if let route { flow.push(FlowSheet(spot: spot, route: route)) }
        var draft = Timeline.Draft(kind: .text, values: [spot], title: spot)
        draft.session = SessionPlace(flow: flow, query: "")
        return try XCTUnwrap(try model.runs.timeline.add(draft, of: SpotsModel.sessionsSpot, at: clock.time)).id
    }

    func testARowOfASessionOpensItsPlaceOnPressWithNoRunAndKeepsThePanelOpen() async throws {
        let id = try keptSession(of: "parts")
        model.pushFirst("other", moving: true)
        try await wait("the open other") { self.model.openSheetID == "other" }

        model.pick(SpotItem(title: "Parts", run: id, move: .session(id)), of: try XCTUnwrap(model.openEntry))

        try await wait("the session") { self.model.openSheetID == "parts" && self.model.transition.phase == .open }
        XCTAssertEqual(host.dismissals, 0)
        XCTAssertEqual(model.flow.pages.map(\.spot), ["parts"])
    }

    func testTheCommandOpensASessionWithItsPagesAndFailsOnAnUnknownOne() async throws {
        let id = try keptSession(of: "other", route: "o")
        try script("other", toml: "title = 'Other'\npages = ['*']", "printf 'item=o\\ntitle=Other\\n'")
        await model.reload()

        let opened = await ModelApp(model: model).openSession(id)
        let missing = await ModelApp(model: model).openSession("nope")

        XCTAssertTrue(opened)
        XCTAssertFalse(missing)
        try await wait("the session's page") { self.model.flow.current == FlowSheet(spot: "other", route: "o") }
        XCTAssertEqual(model.flow.pages.count, 2)
    }

    private func keep(_ spots: [String]) throws {
        for (index, spot) in spots.enumerated() {
            var flow = Flow()
            flow.push(FlowSheet(spot: spot))
            var draft = Timeline.Draft(kind: .text, values: [spot], title: spot, key: "\(index)")
            draft.session = SessionPlace(flow: flow, query: "")
            _ = try model.runs.timeline.add(draft, of: SpotsModel.sessionsSpot, at: clock.time.addingTimeInterval(Double(index)))
        }
    }

    func testCommandBracketWalksPastTheWindowAsItsReadsLandAndKeepsAtMostAWindowWhenTheWalkEnds() async throws {
        try keep(["other", "parts", "other", "parts", "other", "parts", "other", "parts"])
        model.readSessions(older: false)
        try await waitForSessions()
        XCTAssertEqual(model.window.stops.count, SessionWindow.size)

        let order = ["parts", "other", "parts", "other", "parts", "other", "parts", "other"]
        for (step, spot) in order.enumerated() {
            XCTAssertTrue(model.handleKey(back))
            try await wait("session \(step)") { self.model.openSheetID == spot && self.model.transition.phase == .open && self.model.window.index == step }
        }
        try await waitForSessions()
        XCTAssertTrue(model.window.isWhole)
        XCTAssertTrue(model.handleKey(back))
        XCTAssertEqual(model.window.index, 7)

        model.window.stopWalking()
        XCTAssertEqual(model.window.stops.count, SessionWindow.size)
    }

    func testANewModelOnTheSameTimelineReachesTheSessionsOfTheLastRun() async throws {
        try keep(["parts"])
        let files = model.files
        model.quit()
        model = SpotsModel(host: host, files: files, runs: SpotRuns(opening: SheetOpening(motionLength: motionLength), clock: clock.value, stopPause: stopPause, timeline: files.timeline))
        host.model = model
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        try await waitForSessions()

        try await walk(back, to: "parts")
    }

    func testPressesPastTheWindowWaitForOneReadAndLeaveNoBackForALaterRead() async throws {
        try keep(["other", "parts", "other", "parts", "other", "parts", "other", "parts"])
        model.readSessions(older: false)
        try await waitForSessions()

        for _ in 0..<8 { XCTAssertTrue(model.handleKey(back)) }
        try await waitForSessions()
        XCTAssertEqual(model.window.index, 5)

        model.window.stopWalking()
        model.readSessions(older: false)
        try await waitForSessions()
        XCTAssertNil(model.window.index)
    }

    func testATextSessionOnTheGridIsKeptInTheTimelineAndComesBackAfterAShow() async throws {
        model.search("2+2")
        model.noteRun()
        try await visit("other")
        try await wait("the sessions on disk") { self.visits.count == 2 }
        model.panelWillHide()
        model.panelDidHide()
        model.isShown = true
        model.panelWillShow()
        try await waitForSessions()

        XCTAssertTrue(model.handleKey(back))
        try await wait("other") { self.model.openSheetID == "other" }
        XCTAssertTrue(model.handleKey(back))

        try await wait("the text session") { self.model.openSheetID == nil && self.model.searchText == "2+2" }
    }
}
