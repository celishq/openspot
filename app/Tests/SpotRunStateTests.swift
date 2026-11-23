import XCTest
@testable import OpenspotCore

@MainActor
final class SpotRunStateTests: XCTestCase {
    private var clock: FakeClock!
    private var runs: SpotRuns!
    private var links: [String: FakeMode] = [:]
    private var records: [CallLog.Record] = []

    override func setUp() async throws {
        clock = FakeClock()
        runs = SpotRuns(clock: clock.value)
        runs.standIn = { [unowned self] spot in
            let link = FakeMode()
            links[spot.id] = link
            return link
        }
        runs.onCall = { [unowned self] record in records.append(record) }
    }

    override func tearDown() async throws {
        runs.quit()
    }

    private func sheet(kind: SpotKind = .list, triggers: Manifest.Triggers = .sheet, mode: SpotMode = .once, offers: [Manifest.Action] = []) -> (SpotRun, FakeMode) {
        let sheet = runs.sheet(for: Spot(id: "script", name: "Script", url: URL(fileURLWithPath: "/script.spot/script.sh"), kind: kind, triggers: triggers, mode: mode, offers: offers))
        return (sheet, links["script"]!)
    }

    private func sleeps(_ count: Int = 1) async throws {
        try await wait("\(count) sleeps on the clock") { self.clock.sleepCount == count }
    }

    private func opened(searches: Bool = false, frame: String = "item=a\ntitle=A\n") async -> (SpotRun, FakeMode) {
        let (sheet, link) = sheet(triggers: Manifest.Triggers(events: [searches ? SpotEvent.sheetText : SpotEvent.sheetOpen]))
        sheet.open {}
        await link.frame(frame, of: link.sent[0])
        await link.end(link.sent[0])
        return (sheet, link)
    }

    func testClosingStopsAReadThatNothingElseWants() async throws {
        let (sheet, link) = sheet()

        sheet.open {}
        sheet.close()
        await link.frame("text=a\ntitle=A\n", of: link.sent[0])
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
        XCTAssertEqual(link.sent[1].request.message.text, "input.value=rep\n")
    }

    func testAStoppedSearchChangesNothing() async throws {
        let (sheet, link) = await opened(searches: true)
        sheet.search("slow")
        try await sleeps()
        clock.advance(by: 0.3)
        try await wait("the search") { link.sent.count == 2 }

        sheet.close()
        await link.frame("item=b\ntitle=B\n\nitem=c\ntitle=C\n", of: link.sent[1])
        await link.end(link.sent[1])

        XCTAssertTrue(link.sent[1].made.isStopped)
        XCTAssertEqual(sheet.list.shown.map(\.run), ["a"])
    }

    func testAnOlderAnswerDoesNotReplaceANewerChange() async throws {
        let (sheet, link) = await opened(frame: "frame=\nclass=gap-part\n\nfield=a\ntitle=start\nvalue=x\n")
        let part = try XCTUnwrap(sheet.panel?.parts.first)
        sheet.set(part, to: "old")
        try await sleeps()
        clock.advance(by: 0.3)
        try await wait("the older call") { link.sent.count == 2 }

        sheet.set(part, to: "new")
        try await sleeps(2)
        clock.advance(by: 0.3)
        try await wait("the newer call") { link.sent.count == 3 }
        await link.frame("frame=\nclass=gap-part\n\nfield=a\ntitle=new\nvalue=x\n", of: link.sent[2])
        await link.end(link.sent[2])
        await link.frame("frame=\nclass=gap-part\n\nfield=a\ntitle=old\nvalue=x\n", of: link.sent[1])
        await link.end(link.sent[1])

        XCTAssertEqual(link.sent.dropFirst().map { call in call.request.message.inputs.last { $0.key == "value" }?.value }, ["old", "new"])
        XCTAssertEqual(sheet.panel?.parts.first?.title, "new")
        XCTAssertEqual(sheet.panel?.parts.first?.value, "new")
    }

    func testAReadAskedDuringAReadRunsAfterIt() async throws {
        let (sheet, link) = sheet()
        sheet.show(need: .change)
        sheet.show(need: .change)
        XCTAssertEqual(link.sent.count, 1)

        await link.frame("text=a\ntitle=A\n", of: link.sent[0])
        await link.end(link.sent[0])

        XCTAssertEqual(link.sent.count, 2)
        XCTAssertTrue(sheet.isShowing)
    }

    func testAReadThatPrintsNothingAnswersWithNoRows() async throws {
        let (sheet, link) = await opened()

        sheet.show(need: .change)
        await link.end(link.sent[1])

        XCTAssertEqual(sheet.list.shown.count, 0)
        XCTAssertFalse(sheet.isShowing)
        XCTAssertTrue(sheet.calls.isEmpty)
    }

    func testAToggleThatFailsIsUndone() async throws {
        let (sheet, link) = sheet(kind: .toggle, triggers: Manifest.Triggers())
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
        let (sheet, link) = sheet(kind: .toggle, triggers: Manifest.Triggers())
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

        XCTAssertEqual(link.arguments(), [["show"], ["press", "a"], ["show"]])
    }

    func testNoReadFollowsWorkThatDrewAPicture() async throws {
        let (sheet, link) = await opened()

        sheet.pick(SpotItem(title: "A", run: "a"))
        await link.frame("item=b\ntitle=B\n", of: link.sent[1])
        await link.end(link.sent[1])

        XCTAssertEqual(link.arguments(), [["show"], ["press", "a"]])
        XCTAssertEqual(sheet.list.shown.map(\.run), ["b"])
    }

    func testWorkShowsOnceTheClockHasRunOneSecond() async throws {
        let (sheet, link) = sheet(kind: .launch, triggers: Manifest.Triggers())

        sheet.pressCard()
        try await sleeps()
        clock.advance(by: 0.9)
        XCTAssertTrue(sheet.acts.isEmpty)
        clock.advance(by: 0.1)

        try await wait("the shown work") { !sheet.acts.isEmpty }
        XCTAssertEqual(sheet.acts.map(\.id), [link.sent[0].made.id])
    }

    private func inMenuBar(triggers: Manifest.Triggers = Manifest.Triggers()) -> (SpotRun, FakeMode) {
        let spot = Spot(id: "script", name: "Script", url: URL(fileURLWithPath: "/script.spot/script.sh"), triggers: triggers)
        runs.take(ScanResult(files: [SpotFile(id: "script", spots: [spot])], refused: []), menuBar: ["script"])
        return (runs.sheets["script"]!, links["script"]!)
    }

    private func readInMenuBar() async -> (SpotRun, FakeMode, Int) {
        let (sheet, link) = inMenuBar(triggers: Manifest.Triggers(events: [SpotEvent.panelOpen, SpotEvent.sheetOpen, "clipboard.change"]))
        for call in link.sent { await link.end(call) }
        sheet.show(need: .change, event: .panel)
        return (sheet, link, link.sent.count - 1)
    }

    func testASheetOpenAndAnEventDuringOneReadEachReadWithTheirOwnReason() async throws {
        let (sheet, link, first) = await readInMenuBar()

        sheet.open {}
        sheet.show(need: .clock, event: .event("clipboard.change", value: nil))
        await link.end(link.sent[first])
        XCTAssertEqual(link.sent.dropFirst(first).map(\.request.event?.name), ["panel.open", "sheet.open"])
        await link.end(link.sent[first + 1])

        XCTAssertEqual(link.sent.dropFirst(first).map(\.request.event?.name), ["panel.open", "sheet.open", "clipboard.change"])
    }

    func testASheetThatClosesDuringAReadGetsNoReadForItsOpen() async throws {
        let (sheet, link, first) = await readInMenuBar()

        sheet.open {}
        sheet.close()
        await link.end(link.sent[first])

        XCTAssertFalse(link.sent[first].made.isStopped)
        XCTAssertEqual(link.sent.dropFirst(first).map(\.request.event?.name), ["panel.open"])
    }

    func testWorkShorterThanItsPauseTellsNoReaderOfTheWorkOrTheMenuBar() async throws {
        let (sheet, link) = inMenuBar()
        nonisolated(unsafe) var told: [String] = []
        withObservationTracking { _ = sheet.acts } onChange: { told.append("work") }
        withObservationTracking { _ = sheet.shownState } onChange: { told.append("state") }
        withObservationTracking { _ = self.runs.menuBarMarks } onChange: { told.append("marks") }
        withObservationTracking { _ = self.runs.runningSummary } onChange: { told.append("summary") }

        sheet.pressCard()
        await link.end(link.sent[0])

        XCTAssertEqual(told, [])
    }

    func testWorkPastItsPauseShowsInTheRunningSummaryUntilItEnds() async throws {
        let (sheet, link) = inMenuBar()
        sheet.pressCard()
        try await sleeps()
        nonisolated(unsafe) var told = 0
        withObservationTracking { _ = self.runs.runningSummary } onChange: { told += 1 }

        clock.advance(by: 1)
        try await wait("the summary") { self.runs.runningSummary == "Script is running" }
        XCTAssertEqual(told, 1)
        XCTAssertEqual(runs.actSpot, "script")
        await link.end(link.sent[0])

        XCTAssertNil(runs.runningSummary)
        XCTAssertTrue(sheet.acts.isEmpty)
    }

    func testANewReadingTellsTheReaderOfTheMarksAndTheSameReadingDoesNot() async throws {
        let (sheet, link) = inMenuBar(triggers: Manifest.Triggers(every: 60))
        try await wait("the first read") { link.sent.count == 1 }
        await link.frame("frame=\nclass=gap-part\n\nnumber=n\nclass=bar:flex\nvalue=3\n", of: link.sent[0])
        await link.end(link.sent[0])
        nonisolated(unsafe) var told = 0
        withObservationTracking { _ = self.runs.menuBarMarks } onChange: { told += 1 }

        sheet.show(need: .change)
        await link.frame("frame=\nclass=gap-part\n\nnumber=n\nclass=bar:flex\nvalue=3\n", of: link.sent[1])
        await link.end(link.sent[1])
        XCTAssertEqual(told, 0)
        sheet.show(need: .change)
        await link.frame("frame=\nclass=gap-part\n\nnumber=n\nclass=bar:flex\nvalue=4\n", of: link.sent[2])
        await link.end(link.sent[2])

        XCTAssertEqual(told, 1)
        XCTAssertEqual(runs.menuBarMarks.map(\.id), ["script"])
    }

    func testAnOpenPanelWithNothingDueSetsNoWake() async throws {
        let (sheet, _) = inMenuBar()

        runs.raise(.panel)
        sheet.pressCard()

        try await wait("the pause of the work") { self.clock.sleepCount >= 1 }
        await Task.yield()
        XCTAssertEqual(clock.sleepCount, 1)
    }

    func testAPanelOpenLooksAtTheClockOnce() async throws {
        runs.quit()
        let fake = clock.value
        nonisolated(unsafe) var looks = 0
        runs = SpotRuns(clock: RunClock(now: {
            looks += 1
            return fake.now()
        }, sleep: fake.sleep))
        runs.standIn = { [unowned self] spot in
            let link = FakeMode()
            links[spot.id] = link
            return link
        }
        let (_, link) = inMenuBar(triggers: Manifest.Triggers(every: 60))
        await link.end(link.sent[0])
        let before = looks

        runs.raise(.panel)

        XCTAssertEqual(looks - before, 1)
    }

    func testTheClockSleepsUntilTheNextReadIsDue() async throws {
        let (_, link) = inMenuBar(triggers: Manifest.Triggers(every: 60))
        await link.end(link.sent[0])
        try await wait("the schedule") { self.clock.isSleeping(for: 60) }

        clock.advance(by: 59)
        runs.raise(.panel)
        XCTAssertEqual(link.sent.count, 1)
        try await wait("the schedule kept") { self.clock.isSleeping(for: 1) && self.clock.sleepCount == 1 }
        clock.advance(by: 1)

        try await wait("the read from the clock") { link.sent.count == 2 }
    }

    func testASpotThatComesBackReadsAtOnce() async throws {
        let spot = Spot(id: "script", name: "Script", url: URL(fileURLWithPath: "/script.spot/script.sh"), triggers: Manifest.Triggers(every: 60))
        let scan = ScanResult(files: [SpotFile(id: "script", spots: [spot])], refused: [])
        runs.take(scan, menuBar: ["script"])
        await links["script"]!.end(links["script"]!.sent[0])
        clock.advance(by: 10)

        runs.take(ScanResult(files: [], refused: []), menuBar: ["script"])
        runs.take(scan, menuBar: ["script"])

        XCTAssertEqual(links["script"]?.sent.count, 1)
    }

    func testQuickPressesOfAKeyWaitUpToTheirLimit() async throws {
        let (sheet, link) = sheet(kind: .launch, triggers: Manifest.Triggers(), offers: Manifest(text: TestSpot.command, folder: "").actions.filter { $0.title != nil })

        for _ in 0..<10 { sheet.pressKey("go") }
        var ended = 0
        while ended < link.sent.count {
            await link.end(link.sent[ended])
            ended += 1
        }

        XCTAssertEqual(link.sent.count, 1 + SpotRun.waitingLimit)
    }

    func testAStayingSpotHoldsNoMoreKeyPressesThanTheLimit() async throws {
        let (sheet, link) = sheet(kind: .launch, triggers: Manifest.Triggers(), mode: .stay, offers: Manifest(text: TestSpot.command, folder: "").actions.filter { $0.title != nil })
        var toasts: [String] = []
        sheet.onReport = { if case .toast(let text) = $0 { toasts.append(text) } }

        for _ in 0..<50 { sheet.pressKey("go") }
        XCTAssertEqual(toasts.count, 50 - SpotRun.waitingLimit)
        XCTAssertEqual(toasts.first, "Script is still busy with 8 presses, so Openspot dropped this one. Wait for one to end, then press again.")
        XCTAssertEqual(link.sent.count, SpotRun.waitingLimit)
        XCTAssertEqual(sheet.calls.count, SpotRun.waitingLimit)
        await link.end(link.sent[0])
        sheet.pressKey("go")

        XCTAssertEqual(link.sent.count, SpotRun.waitingLimit + 1)
    }

    func testASecondPressStopsAStayingCallThatSaysNothingAfterTheStopPause() async throws {
        let (sheet, link) = sheet(kind: .launch, triggers: Manifest.Triggers(), mode: .stay)
        sheet.pressCard()
        clock.advance(by: 2)

        sheet.pressCard()
        XCTAssertEqual(sheet.calls.count, 1)
        try await wait("the stop pause") { self.clock.isSleeping(for: 2) }
        clock.advance(by: 2)

        try await wait("the stop") { sheet.calls.isEmpty }
        XCTAssertTrue(link.sent[0].made.isStopped)
    }

    func testAStayingCallThatPrintsAFrameAfterTheStopKeepsRunning() async throws {
        let (sheet, link) = sheet(kind: .launch, triggers: Manifest.Triggers(), mode: .stay)
        sheet.pressCard()
        clock.advance(by: 2)

        sheet.pressCard()
        await link.frame("call=1\n", of: link.sent[0])
        try await wait("the stop pause") { self.clock.isSleeping(for: 2) }
        clock.advance(by: 2)

        try await wait("the end of the stop pause") { sheet.pauses.isEmpty }
        XCTAssertEqual(sheet.calls.count, 1)
        XCTAssertFalse(link.sent[0].made.isStopped)
    }

    func testAThirdPressStartsTheStopPauseAgain() async throws {
        let (sheet, _) = sheet(kind: .launch, triggers: Manifest.Triggers(), mode: .stay)
        sheet.pressCard()
        clock.advance(by: 2)
        sheet.pressCard()
        try await wait("the stop pause") { self.clock.isSleeping(for: 2) }
        clock.advance(by: 1.5)

        sheet.pressCard()
        try await wait("the new stop pause") { self.clock.isSleeping(for: 2) }
        clock.advance(by: 1)
        await Task.yield()
        XCTAssertEqual(sheet.calls.count, 1)
        clock.advance(by: 1)

        try await wait("the stop") { sheet.calls.isEmpty }
    }

    func testWorkThatWakesBeforeItsTimeSleepsForTheTimeLeft() async throws {
        runs.quit()
        let fake = clock.value
        nonisolated(unsafe) var early = true
        runs = SpotRuns(clock: RunClock(now: fake.now, sleep: { duration, tolerance in
            if early {
                early = false
                return
            }
            try await fake.sleep(duration, tolerance)
        }))
        runs.standIn = { [unowned self] spot in
            let link = FakeMode()
            links[spot.id] = link
            return link
        }
        let (sheet, _) = sheet(kind: .launch, triggers: Manifest.Triggers())

        sheet.pressCard()
        try await sleeps()
        clock.advance(by: 1)

        try await wait("the shown work") { !sheet.acts.isEmpty }
    }

    func testAFormCallAnswersWithItsFrameOfFieldsAndTheRowItNames() async throws {
        let (sheet, link) = await opened()
        let action = CommandAction(id: "new", title: "New")
        async let answer = sheet.form(action, item: nil)
        try await wait("the form call") { link.sent.count == 2 }

        await link.frame("frame=\ntype=form\ntitle=New\n\nfield=a\ntitle=A\n", of: link.sent[1])
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

        XCTAssertEqual(records.map(\.arguments), [["show"], ["press"]])
        XCTAssertTrue(records.last?.input?.contains("input.item=a\n") == true, records.last?.input ?? "")
        XCTAssertEqual(records.last?.frames, ["toast=Done\n"])
        XCTAssertEqual(records.last?.end, .exited(2))
        XCTAssertEqual(runs.usage.counts["script"]?.runs, 2)
        XCTAssertEqual(runs.usage.counts["script"]?.failures.count, 1)
    }
}
