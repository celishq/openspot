import XCTest
@testable import OpenspotCore

@MainActor
final class SpotRunStateTests: XCTestCase {
    private var clock: FakeClock!
    private var runs: SpotRuns!
    private var links: [String: FakeLink] = [:]
    private var records: [CallLog.Record] = []

    override func setUp() async throws {
        clock = FakeClock()
        runs = SpotRuns(clock: clock.value)
        runs.standIn = { [unowned self] spot in
            let link = FakeLink()
            links[spot.id] = link
            return link
        }
        runs.onCall = { [unowned self] record, _ in records.append(record) }
    }

    override func tearDown() async throws {
        runs.quit()
    }

    private func sheet(kind: SpotKind = .list, read: SpotRead? = .sheet) -> (SpotRun, FakeLink) {
        let sheet = runs.sheet(for: Spot(id: "script", name: "Script", url: URL(fileURLWithPath: "/script.spot/script.sh"), kind: kind, read: read))
        return (sheet, links["script"]!)
    }

    private func sleeps(_ count: Int = 1) async throws {
        try await wait("\(count) sleeps on the clock") { self.clock.sleepCount == count }
    }

    private func opened(searches: Bool = false, frame: String = "row=a\ntitle=A\n") async -> (SpotRun, FakeLink) {
        let (sheet, link) = sheet(read: SpotRead(moments: [.sheet], searchesSheet: searches))
        sheet.open {}
        await link.frame(frame, of: link.sent[0])
        await link.end(link.sent[0])
        return (sheet, link)
    }

    func testClosingStopsAReadThatNothingElseWants() async throws {
        let (sheet, link) = sheet()

        sheet.open {}
        sheet.close()
        await link.frame("row=a\ntitle=A\n", of: link.sent[0])
        await link.end(link.sent[0])

        XCTAssertTrue(link.sent[0].made.isStopped)
        XCTAssertEqual(sheet.list.shown.count, 0)
        XCTAssertFalse(sheet.list.isLoading)
    }

    func testATypedTextReachesTheScriptAfterItsPause() async throws {
        let (sheet, link) = await opened(searches: true)

        sheet.search("rep")
        try await sleeps()
        clock.advance(by: 0.2)
        XCTAssertEqual(link.sent.count, 1)
        clock.advance(by: 0.1)

        try await wait("the search") { link.sent.count == 2 }
        XCTAssertEqual(link.sent[1].request.input, "search=rep\n")
    }

    func testAStoppedSearchChangesNothing() async throws {
        let (sheet, link) = await opened(searches: true)
        sheet.search("slow")
        try await sleeps()
        clock.advance(by: 0.3)
        try await wait("the search") { link.sent.count == 2 }

        sheet.close()
        await link.frame("row=b\ntitle=B\n\nrow=c\ntitle=C\n", of: link.sent[1])
        await link.end(link.sent[1])

        XCTAssertTrue(link.sent[1].made.isStopped)
        XCTAssertEqual(sheet.list.shown.map(\.run), ["a"])
    }

    func testAnOlderAnswerDoesNotReplaceANewerChange() async throws {
        let (sheet, link) = await opened(frame: "field=a\ntitle=start\nvalue=x\n")
        let part = try XCTUnwrap(sheet.panel?.parts.first)
        sheet.set(part, to: "old")
        try await sleeps()
        clock.advance(by: 0.3)
        try await wait("the older call") { link.sent.count == 2 }

        sheet.set(part, to: "new")
        try await sleeps(2)
        clock.advance(by: 0.3)
        try await wait("the newer call") { link.sent.count == 3 }
        await link.frame("field=a\ntitle=new\nvalue=x\n", of: link.sent[2])
        await link.end(link.sent[2])
        await link.frame("field=a\ntitle=old\nvalue=x\n", of: link.sent[1])
        await link.end(link.sent[1])

        XCTAssertEqual(link.arguments().dropFirst().map(\.last), ["old", "new"])
        XCTAssertEqual(sheet.panel?.parts.first?.title, "new")
        XCTAssertEqual(sheet.panel?.parts.first?.value, "new")
    }

    func testAReadAskedDuringAReadRunsAfterIt() async throws {
        let (sheet, link) = sheet()
        sheet.read(need: .change)
        sheet.read(need: .change)
        XCTAssertEqual(link.sent.count, 1)

        await link.frame("row=a\ntitle=A\n", of: link.sent[0])
        await link.end(link.sent[0])

        XCTAssertEqual(link.sent.count, 2)
        XCTAssertTrue(sheet.isReading)
    }

    func testAReadThatPrintsNothingAnswersWithNoRows() async throws {
        let (sheet, link) = await opened()

        sheet.read(need: .change)
        await link.end(link.sent[1])

        XCTAssertEqual(sheet.list.shown.count, 0)
        XCTAssertFalse(sheet.isReading)
        XCTAssertTrue(sheet.calls.isEmpty)
    }

    func testAToggleThatFailsIsUndone() async throws {
        let (sheet, link) = sheet(kind: .toggle, read: nil)
        var failures: [String] = []
        sheet.onReport = { if case .failure(let text) = $0 { failures.append(text) } }

        sheet.pressCard()
        XCTAssertEqual(sheet.state.on, true)
        await link.end(link.sent[0], .failed(SpotError.failed(1, "No power")))

        XCTAssertNotEqual(sheet.state.on, true)
        XCTAssertEqual(failures, ["No power"])
        XCTAssertFalse(sheet.isCardRunning)
    }

    func testAToggleStoppedByASecondPressIsUndone() async throws {
        let (sheet, link) = sheet(kind: .toggle, read: nil)
        sheet.pressCard()
        clock.advance(by: 0.5)
        sheet.pressCard()
        XCTAssertFalse(link.sent[0].made.isStopped)

        clock.advance(by: 0.5)
        sheet.pressCard()
        await link.end(link.sent[0])

        XCTAssertTrue(link.sent[0].made.isStopped)
        XCTAssertNotEqual(sheet.state.on, true)
        XCTAssertEqual(link.sent.count, 1)
    }

    func testAReadFollowsWorkThatDrewNoPicture() async throws {
        let (sheet, link) = await opened()

        sheet.pick(SpotItem(title: "A", run: "a"))
        await link.frame("toast=Done\n", of: link.sent[1])
        await link.end(link.sent[1])

        XCTAssertEqual(link.arguments(), [["read"], ["open", "a"], ["read"]])
    }

    func testNoReadFollowsWorkThatDrewAPicture() async throws {
        let (sheet, link) = await opened()

        sheet.pick(SpotItem(title: "A", run: "a"))
        await link.frame("row=b\ntitle=B\n", of: link.sent[1])
        await link.end(link.sent[1])

        XCTAssertEqual(link.arguments(), [["read"], ["open", "a"]])
        XCTAssertEqual(sheet.list.shown.map(\.run), ["b"])
    }

    func testWorkThatNamesARowReadsAndSelectsIt() async throws {
        let (sheet, link) = await opened()

        sheet.pick(SpotItem(title: "A", run: "a"))
        await link.frame("select=b\n", of: link.sent[1])
        await link.end(link.sent[1])
        await link.frame("row=a\ntitle=A\n\nrow=b\ntitle=B\n", of: link.sent[2])
        await link.end(link.sent[2])

        XCTAssertEqual(sheet.selectedItem?.run, "b")
    }

    func testWorkShowsOnceTheClockHasRunOneSecond() async throws {
        let (sheet, link) = sheet(kind: .launch, read: nil)

        sheet.pressCard()
        try await sleeps()
        clock.advance(by: 0.9)
        XCTAssertTrue(sheet.work.isEmpty)
        clock.advance(by: 0.1)

        XCTAssertEqual(sheet.work.map(\.id), [link.sent[0].made.id])
        try await wait("the reader of the work") { sheet.workPauses == 1 }
    }

    func testAFormCallAnswersWithItsFrameOfFieldsAndTheRowItNames() async throws {
        let (sheet, link) = await opened()
        let action = CommandAction(id: "new", title: "New")
        async let answer = sheet.form(action, item: nil)
        try await wait("the form call") { link.sent.count == 2 }

        await link.frame("title=New\n\nfield=a\ntitle=A\n", of: link.sent[1])
        await link.frame("toast=Ready\n", of: link.sent[1])
        await link.end(link.sent[1])

        let form = try await answer
        XCTAssertEqual(form?.fields.map(\.name), ["a"])
        XCTAssertTrue(sheet.calls.isEmpty)
    }

    func testAStoppedFormCallAnswersNothing() async throws {
        let (sheet, link) = await opened()
        let action = CommandAction(id: "new", title: "New")
        async let answer = sheet.form(action, item: nil)
        try await wait("the form call") { link.sent.count == 2 }

        sheet.stop(link.sent[1].made)
        await link.end(link.sent[1])

        let form = try await answer
        XCTAssertNil(form)
    }

    func testEachCallIsCountedAndReachesTheLogWithItsFramesAndItsEnd() async throws {
        let (sheet, link) = await opened()

        sheet.pick(SpotItem(title: "A", run: "a"))
        await link.frame("toast=Done\n", of: link.sent[1])
        await link.end(link.sent[1], .failed(SpotError.failed(2, "No")))

        XCTAssertEqual(records.map(\.arguments), [["read"], ["open", "a"]])
        XCTAssertEqual(records.last?.frames, ["toast=Done\n"])
        XCTAssertEqual(records.last?.end, .exited(2))
        XCTAssertEqual(runs.usage.counts["script"]?.runs, 2)
        XCTAssertEqual(runs.usage.counts["script"]?.failures, 1)
    }
}
