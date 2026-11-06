import XCTest
@testable import OpenspotCore

/// Proves the rules of runs with real processes: one owner, one sheet for each script, the moments and how long a call runs.
@MainActor
final class SpotRunsTests: XCTestCase {
    private var folder: URL!
    private var runs: SpotRuns!
    private var time = Date(timeIntervalSince1970: 1000)

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-runs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        runs = SpotRuns(now: { [unowned self] in self.time })
    }

    override func tearDown() async throws {
        runs.quit()
        try? FileManager.default.removeItem(at: folder)
    }

    private func path(_ name: String) -> String {
        folder.appendingPathComponent(name).path
    }

    private func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: path(name))
    }

    /// The calls that a script logged, one line for each.
    private func log(_ name: String = "log") -> [String] {
        ((try? String(contentsOfFile: path(name), encoding: .utf8)) ?? "").split(separator: "\n", omittingEmptySubsequences: false).dropLast().map(String.init)
    }

    /// Writes a script with these header lines, which logs each call before its body runs.
    @discardableResult
    private func script(_ name: String = "script", header: String = "", log: String = "log", _ body: String = "") throws -> URL {
        let url = folder.appendingPathComponent("\(name).sh")
        let lines = header.split(separator: "\n").map { "# \($0)" }.joined(separator: "\n")
        try "#!/bin/sh\n\(lines)\necho \"$*\" >> '\(path(log))'\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    @discardableResult
    private func script(body: String) throws -> URL {
        try script("script", header: "", body)
    }

    private func scanned() throws -> ScanResult {
        let scan = try PluginFolder(url: folder).scan()
        XCTAssertEqual(scan.refused, [])
        runs.take(scan)
        return scan
    }

    private func sheet(_ id: String = "script") throws -> SpotSheet {
        _ = try scanned()
        return try XCTUnwrap(runs.sheets[id])
    }

    private func wait(_ what: String, until condition: () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited for \(what)")
    }

    private func pause(_ seconds: Double = 0.4) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }

    // MARK: A1, A2

    func testEachScriptWithACardOrNotHasOneSheetAndAWidgetHasNone() throws {
        try script("cups", header: "read=30")
        try script("tool", header: "read=sheet\nkey=t")
        try script("once")
        try "[[widgets]]\nname = \"W\"\nlayout = \"single\"\nplaces = [\"cups\"]\n".write(to: folder.appendingPathComponent("w.toml"), atomically: true, encoding: .utf8)

        let scan = try scanned()

        XCTAssertEqual(Set(runs.sheets.keys), ["cups", "tool", "once"])
        XCTAssertEqual(Set(scan.commands.map(\.id)), ["tool", "once", "w/W"])
    }

    func testASheetKeepsItsLastFrameRowsPartsAndValue() async throws {
        try script(header: "read=sheet", "printf 'title=3\\ntone=good\\n\\nrow=A\\nrun=a\\n\\npart=b\\ntitle=B\\n'")
        let sheet = try sheet()

        sheet.open {}

        try await wait("the answer") { sheet.list.shown.count == 1 }
        XCTAssertEqual(sheet.lastFrame, "title=3\ntone=good\n\nrow=A\nrun=a\n\npart=b\ntitle=B\n")
        XCTAssertEqual(sheet.panel?.parts.map(\.id), ["b"])
        XCTAssertEqual(sheet.reading.value?.title, "3")
        XCTAssertEqual(sheet.reading.value?.tone, .good)
        XCTAssertTrue(sheet.isOpen)
    }

    func testAScriptThatLeavesTheFolderLosesItsSheetAndItsRead() async throws {
        let url = try script(header: "read=sheet", "sleep 0.3\ntouch '\(path("went-on"))'")
        let sheet = try sheet()
        sheet.read()

        try FileManager.default.removeItem(at: url)
        _ = try scanned()
        try await pause(0.7)

        XCTAssertNil(runs.sheets["script"])
        XCTAssertFalse(exists("went-on"))
    }

    // MARK: M1, M2, M3, M4

    func testARequestJoinsTheReadThatRuns() async throws {
        try script(header: "read=sheet", "sleep 0.2\nprintf 'row=A\\nrun=a\\n'")
        let sheet = try sheet()

        sheet.read()
        sheet.read()
        sheet.read()

        try await wait("the row") { sheet.list.shown.count == 1 }
        XCTAssertEqual(log(), ["read"])
    }

    func testAPanelOpenAndASheetOpenWithinFiveSecondsRunOnce() async throws {
        try script(header: "read=panel\nrank=1", "printf 'row=A\\nrun=a\\n'")
        let sheet = try sheet()

        runs.panelOpened()
        try await wait("the row") { sheet.list.shown.count == 1 }
        sheet.open {}
        time += 4
        sheet.close()
        sheet.open {}
        try await pause(0.3)

        XCTAssertEqual(log(), ["read"])
    }

    func testAPanelOpenAndASheetOpenAtOnceRunOnce() async throws {
        try script(header: "read=panel\nkey=c", "sleep 0.2\nprintf 'detail=Off\\non=false\\n\\nrow=A\\nrun=a\\n'")
        let sheet = try sheet()

        runs.panelOpened()
        sheet.open {}

        try await wait("the row") { sheet.list.shown.count == 1 }
        XCTAssertEqual(log(), ["read"])
    }

    func testAnAnswerOlderThanFiveSecondsIsReadAgain() async throws {
        try script(header: "read=sheet", "printf 'row=A\\nrun=a\\n'")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        sheet.close()

        time += 5
        sheet.open {}

        try await wait("the second read") { self.log().count == 2 }
    }

    func testATimerReadAlwaysRuns() async throws {
        try script("fast", header: "read=1\ntray=true", "printf 'title=1\\n'")
        _ = try scanned()
        try await wait("the first read") { self.log().count == 1 }
        try await pause(0.2)

        time += 1
        runs.tick()

        try await wait("the second read") { self.log().count == 2 }
    }

    func testALaunchOrAWakeReadAlwaysRuns() async throws {
        try script(header: "read=launch,wake\nkey=a", "printf 'row=A\\nrun=a\\n'")
        let sheet = try sheet()

        runs.arrive(.launch)
        try await wait("the first read") { sheet.list.shown.count == 1 && sheet.calls.isEmpty }
        runs.arrive(.wake)

        try await wait("the second read") { self.log().count == 2 }
    }

    func testANumberInReadReadsAnOpenSheetOnItsTimerWithAYoungAnswer() async throws {
        try script(header: "read=1\nkey=a", "printf 'part=a\\ntitle=A\\n'")
        let sheet = try sheet()
        try await pause(1.2)
        XCTAssertEqual(log(), [])

        sheet.open {}
        try await wait("the first read") { sheet.panel != nil && sheet.calls.isEmpty }
        XCTAssertEqual(log(), ["read"])

        time += 1
        try await wait("the read from the timer") { self.log() == ["read", "read"] }

        sheet.close()
        time += 1
        try await pause(1.2)
        XCTAssertEqual(log(), ["read", "read"])
    }

    func testAScriptThatPrintsEveryIsNotReadAgain() async throws {
        try script(header: "read=sheet", "printf 'every=1\\n\\npart=a\\ntitle=A\\n'")
        let sheet = try sheet()

        sheet.open {}
        try await wait("the part") { sheet.panel != nil }
        try await pause(1.2)

        XCTAssertEqual(log(), ["read"])
        sheet.close()
    }

    func testEachScriptIsReadWhenItsTimePasses() async throws {
        try script("fast", header: "read=5\ntray=true", log: "fast", "printf 'title=1\\n'")
        try script("slow", header: "read=60\ntray=true", log: "slow", "printf 'title=1\\n'")
        _ = try scanned()
        try await wait("the first reads") { self.log("fast").count == 1 && self.log("slow").count == 1 }

        time += 4
        runs.tick()
        try await pause(0.2)
        XCTAssertEqual(log("fast").count, 1)

        time += 1
        runs.tick()
        try await wait("the next read") { self.log("fast").count == 2 }
        XCTAssertEqual(log("slow").count, 1)
    }

    func testATimerReadIsWantedByTheMenuBarAlwaysAndByAWidgetWithThePanelOpen() async throws {
        try script("tray", header: "read=5\ntray=true", log: "tray", "printf 'title=1\\n'")
        try script("placed", header: "read=5", log: "placed", "printf 'title=1\\n'")
        try script("idle", header: "read=5", log: "idle", "printf 'title=1\\n'")
        try "[[widgets]]\nname = \"W\"\nlayout = \"single\"\nplaces = [\"placed\"]\n".write(to: folder.appendingPathComponent("w.toml"), atomically: true, encoding: .utf8)

        _ = try scanned()
        try await wait("the tray read") { self.log("tray").count == 1 }
        XCTAssertEqual(log("placed"), [])

        runs.panelOpened()
        try await wait("the placed read") { self.log("placed").count == 1 }
        XCTAssertEqual(log("idle"), [])
    }

    func testAReadAfterAChangeOfStateUsesNoYoungAnswer() async throws {
        try script(header: "read=sheet", """
        [ "$1" = read ] && printf 'part=go\\ntitle=Go\\npress=true\\n'
        exit 0
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the part") { sheet.panel != nil }

        sheet.press(try XCTUnwrap(sheet.panel?.parts.first))

        try await wait("the read after the press") { self.log() == ["read", "go", "read"] }
    }

    func testAChangeDuringARunningReadReadsOnceMoreAfterIt() async throws {
        try script(header: "read=sheet", "sleep 0.3\nprintf 'row=A\\nrun=a\\n'")
        let sheet = try sheet()

        sheet.read()
        sheet.read(need: .change)

        try await wait("two reads") { self.log() == ["read", "read"] }
    }

    func testOneSlowScriptDoesNotDelayAnother() async throws {
        try script("slow", header: "read=panel\nrank=1", "sleep 2\nprintf 'row=S\\nrun=s\\n'")
        try script("fast", header: "read=panel\nrank=2", "printf 'row=F\\nrun=f\\n'")
        _ = try scanned()
        let started = Date()

        runs.panelOpened()

        let fast = try XCTUnwrap(runs.sheets["fast"])
        try await wait("the fast answer") { fast.list.shown.count == 1 }
        XCTAssertLessThan(Date().timeIntervalSince(started), 1)
        XCTAssertEqual(runs.sheets["slow"]?.list.shown.count, 0)
    }

    func testASpotShowsItsHeaderUntilItsAnswerArrives() async throws {
        try script(header: "read=panel\nsubtitle=Header", "sleep 0.2\nprintf 'detail=Answer\\non=true\\n'")
        let sheet = try sheet()

        runs.panelOpened()
        XCTAssertEqual(sheet.state.subtitle, "Header")
        XCTAssertEqual(sheet.command.kind, .launch)

        try await wait("the answer") { sheet.state.subtitle == "Answer" }
        XCTAssertEqual(sheet.command.kind, .toggle)
    }

    func testAKindThatARunTaughtStaysAfterANewScan() async throws {
        try script(header: "read=panel", "printf 'on=true\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the kind") { sheet.command.kind == .toggle }

        _ = try scanned()

        XCTAssertEqual(sheet.command.kind, .toggle)
        XCTAssertEqual(sheet.state.on, true)
    }

    func testAPressBeforeTheFirstAnswerWaitsForIt() async throws {
        try script(header: "read=panel\nkey=c", "sleep 0.2\nprintf 'row=A\\nrun=a\\n'")
        let sheet = try sheet()
        XCTAssertTrue(sheet.awaitsAnswer)
        var kind: SpotKind?

        sheet.afterAnswer { kind = sheet.command.kind }

        try await wait("the answer") { kind != nil }
        XCTAssertEqual(kind, .list)
        XCTAssertFalse(sheet.awaitsAnswer)
    }

    func testACallWithNoFrameReadsOnce() async throws {
        try script(header: "read=panel", "[ \"$1\" = read ] && printf 'on=false\\n'\nexit 0")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the kind") { sheet.command.kind == .toggle }

        sheet.pressCard()

        try await wait("the read after the call") { self.log() == ["read", "on", "read"] }
        try await pause(0.2)
        XCTAssertEqual(self.log().count, 3)
    }

    func testACallWithOnlyAToastReadsOnce() async throws {
        try script(header: "read=sheet", "[ \"$1\" = read ] && printf 'row=A\\nrun=a\\n'\n[ \"$1\" = open ] && printf 'toast=Done\\n'\nexit 0")
        let sheet = try sheet()
        var toasts: [String] = []
        sheet.onReport = { if case .toast(let text) = $0 { toasts.append(text) } }
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))

        try await wait("the read after the call") { self.log() == ["read", "open a", "read"] }
        XCTAssertEqual(toasts, ["Done"])
    }

    func testACallThatShowsItsStateIsNotReadAgain() async throws {
        try script(header: "read=panel", "[ \"$1\" = read ] && printf 'on=false\\n'\n[ \"$1\" = on ] && printf 'on=true\\n'\nexit 0")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the kind") { sheet.command.kind == .toggle }

        sheet.pressCard()
        try await wait("the call") { self.log() == ["read", "on"] }
        try await pause(0.3)

        XCTAssertEqual(log(), ["read", "on"])
        XCTAssertEqual(sheet.state.on, true)
    }

    func testAScriptWithNoReadIsNotReadAfterACall() async throws {
        try script()
        let sheet = try sheet()

        sheet.pressCard()
        try await wait("the call") { self.log() == [""] }
        try await pause(0.2)

        XCTAssertEqual(log(), [""])
    }

    // MARK: Section 7

    func testAReadHasTenSecondsAndAnyOtherNameHasNoLimit() async throws {
        XCTAssertEqual(SpotRuns().readLimit, 10)
        runs = SpotRuns(readLimit: 1)
        try script(header: "read=sheet", """
        case "$1" in
          read) [ -f '\(path("slow"))' ] && sleep 30; touch '\(path("slow"))'; printf 'title=1\\n\\nrow=A\\nrun=a\\n' ;;
          open) sleep 0.5; touch '\(path("done"))' ;;
        esac
        """)
        let sheet = try sheet()
        var failures: [String] = []
        sheet.onReport = { if case .failure(let text) = $0 { failures.append(text) } }
        sheet.read()
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.read(need: .change)
        try await wait("the time limit") { !failures.isEmpty }
        XCTAssertEqual(failures, ["Script failed. It took too long."])
        XCTAssertEqual(sheet.list.shown.count, 1)
        XCTAssertEqual(sheet.reading.value?.title, "1")
        XCTAssertTrue(sheet.reading.isStale)

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))
        try await wait("the end of the work") { self.exists("done") }
    }

    func testAFailedTimerReadKeepsTheValueAndDimsWithNoToast() async throws {
        try script(header: "read=5\ntray=true", """
        [ -f '\(path("second"))' ] && exit 1
        touch '\(path("second"))'
        printf 'title=3\\n'
        """)
        let sheet = try sheet()
        var failures: [String] = []
        sheet.onReport = { if case .failure(let text) = $0 { failures.append(text) } }
        try await wait("the value") { sheet.reading.value?.title == "3" }
        XCTAssertFalse(sheet.reading.isStale)
        XCTAssertEqual(runs.trayMarks.first?.mark.isStale, false)

        time += 5
        runs.tick()

        try await wait("the dim") { sheet.reading.isStale }
        XCTAssertEqual(sheet.reading.value?.title, "3")
        XCTAssertEqual(runs.trayMarks.first?.mark.isStale, true)
        XCTAssertEqual(failures, [])
    }

    func testAFailedCallAlwaysTellsThePerson() async throws {
        try script(body: "echo gone >&2\nexit 2")
        let sheet = try sheet()
        var failures: [String] = []
        sheet.onReport = { if case .failure(let text) = $0 { failures.append(text) } }

        sheet.pressCard()

        try await wait("the failure") { failures == ["Script failed. gone"] }
    }

    func testAReadStopsWhenThePanelThatWantedItCloses() async throws {
        try script(header: "read=panel\nrank=1", "printf 'row=A\\nrun=a\\n---\\n'\nsleep 0.4\ntouch '\(path("went-on"))'")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the first frame") { sheet.list.shown.count == 1 }

        runs.panelClosed()
        try await pause(0.7)

        XCTAssertFalse(exists("went-on"))
        XCTAssertEqual(sheet.calls.count, 0)
    }

    func testClosingASheetLeavesAReadThatThePanelWants() async throws {
        try script(header: "read=panel\nrank=1", "sleep 0.2\nprintf 'row=A\\nrun=a\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}

        sheet.close()

        try await wait("the row") { sheet.list.shown.count == 1 }
    }

    func testAStreamThatNothingWantsStopsAfterItsFirstFrame() async throws {
        try script(header: "read=sheet", "printf 'row=A\\nrun=a\\n---\\n'\nsleep 0.3\ntouch '\(path("went-on"))'")
        let sheet = try sheet()

        sheet.read()
        try await wait("the row") { sheet.list.shown.count == 1 }
        try await pause(0.6)

        XCTAssertFalse(exists("went-on"))
    }

    func testAStoppedReadChangesNothing() async throws {
        try script(header: "read=sheet", """
        [ -f '\(path("second"))' ] && { sleep 5; exit 0; }
        touch '\(path("second"))'
        printf 'row=A\\nrun=a\\n'
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        sheet.read(need: .change)
        XCTAssertTrue(sheet.list.isLoading)

        sheet.close()
        try await wait("the end of the read") { !sheet.list.isLoading }
        try await pause(0.2)

        XCTAssertEqual(sheet.list.shown.count, 1)
        XCTAssertFalse(sheet.list.hasFailed)
    }

    private static let worker = """
    case "$1" in
      read) printf 'layout=none\\n\\npart=go\\ntitle=Go\\npress=true\\n\\npart=bar\\ntitle=idle\\n' ;;
      go)
        printf 'toast=Started\\non=true\\n\\npart=bar\\ntitle=half\\n---\\n'
        sleep 0.5
        touch '%@'
        printf 'toast=Done\\n\\npart=bar\\ntitle=done\\n'
        ;;
    esac
    """

    func testAWorkCallGoesOnWithTheSheetAndThePanelClosedAndKeepsItsLastFrame() async throws {
        try script(header: "read=sheet", String(format: Self.worker, path("done")))
        let sheet = try sheet()
        var toasts: [String] = []
        sheet.onReport = { if case .toast(let text) = $0 { toasts.append(text) } }
        sheet.open {}
        try await wait("the part") { sheet.panel != nil }

        sheet.press(try XCTUnwrap(sheet.panel?.parts.first))
        try await wait("the first frame") { sheet.calls.first?.lastFrame != nil }
        let call = try XCTUnwrap(sheet.calls.first)
        XCTAssertTrue(call.doesWork)
        XCTAssertEqual(call.action.arguments, ["go"])
        XCTAssertEqual(call.output?.parts.first?.title, "half")
        sheet.close()
        runs.panelClosed()
        XCTAssertEqual(sheet.calls.count, 1)

        try await wait("the end of the work") { self.exists("done") && sheet.calls.isEmpty }
        XCTAssertEqual(toasts, ["Started", "Done"])
        XCTAssertEqual(sheet.lastFrame, "toast=Done\n\npart=bar\ntitle=done\n")
        XCTAssertNil(sheet.panel)
    }

    func testAFrameWithNoOpenSheetShowsOnlyItsToastAndItsState() async throws {
        try script(header: "read=panel", """
        case "$1" in
          read) printf 'on=false\\n\\nrow=A\\nrun=a\\n\\npart=bar\\ntitle=idle\\n' ;;
          open) printf 'toast=Saved\\non=true\\ntitle=Other\\n\\npart=bar\\ntitle=work\\n' ;;
        esac
        """)
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the state") { sheet.state.on == false }
        var toasts: [String] = []
        sheet.onReport = { if case .toast(let text) = $0 { toasts.append(text) } }

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))

        try await wait("the toast") { toasts == ["Saved"] }
        XCTAssertEqual(sheet.state.on, true)
        XCTAssertEqual(sheet.state.title, "Script")
        XCTAssertEqual(sheet.panel?.parts.first?.title, "idle")
    }

    func testOpeningASheetAddsTheLastFrameOfEachRunningCall() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'part=go\\ntitle=Go\\npress=true\\n\\npart=bar\\ntitle=idle\\n' ;;
          go) printf 'part=bar\\ntitle=half\\n---\\n'; sleep 30 ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the part") { sheet.panel != nil }
        sheet.press(try XCTUnwrap(sheet.panel?.parts.first))
        try await wait("the frame") { sheet.panel?.parts.last?.title == "half" }
        sheet.close()
        runs.panelClosed()
        XCTAssertNil(sheet.panel)

        sheet.open {}

        try await wait("the running frame") { sheet.panel?.parts.last?.title == "half" }
        XCTAssertEqual(sheet.calls.filter(\.doesWork).count, 1)
    }

    func testANewValueStopsTheOlderCallOfThatPartAndNoOther() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'part=a\\non=false\\n\\npart=b\\non=false\\n\\npart=out\\ntitle=none\\n' ;;
          a) [ "$2" = true ] && { sleep 0.4; touch '\(path("old-a"))'; exit 0; }; touch '\(path("new-a"))'; printf 'part=out\\ntitle=new\\n' ;;
          b) sleep 0.4; touch '\(path("b"))'; printf 'part=out\\ntitle=b\\n' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the parts") { sheet.panel != nil }
        let parts = try XCTUnwrap(sheet.panel?.parts)

        sheet.set(parts[1], to: "true")
        sheet.set(parts[0], to: "true")
        try await pause(0.1)
        sheet.set(parts[0], to: "false")

        try await wait("the other part") { self.exists("b") }
        try await pause(0.2)
        XCTAssertTrue(exists("new-a"))
        XCTAssertFalse(exists("old-a"))
        XCTAssertEqual(sheet.panel?.parts[0].value, "false")
        XCTAssertEqual(sheet.panel?.parts[2].title, "b")
    }

    func testAnOlderCallOfAnotherPartLeavesAPartThatChangedSince() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'part=a\\non=false\\n\\npart=b\\non=false\\n' ;;
          a) sleep 0.3; printf 'part=a\\non=true\\n\\npart=b\\non=false\\n' ;;
          b) printf 'part=b\\non=true\\n' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the parts") { sheet.panel != nil }
        let parts = try XCTUnwrap(sheet.panel?.parts)

        sheet.set(parts[0], to: "true")
        sheet.set(parts[1], to: "true")
        try await wait("the end of both") { sheet.calls.isEmpty && self.log().count >= 3 }

        XCTAssertEqual(sheet.panel?.parts[1].value, "true")
    }

    func testASecondPressOfARunningPartStopsItAndChangesNothing() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'part=go\\ntitle=Go\\npress=true\\n' ;;
          go) sleep 0.4; touch '\(path("went-on"))' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the part") { sheet.panel != nil }
        let part = try XCTUnwrap(sheet.panel?.parts.first)

        sheet.press(part)
        try await wait("the call") { self.log() == ["read", "go"] }
        time += 1
        sheet.press(part)
        XCTAssertTrue(sheet.calls.isEmpty)
        try await pause(0.6)

        XCTAssertFalse(exists("went-on"))
        XCTAssertEqual(log(), ["read", "go"])
    }

    func testASecondPressOfARunningActionStopsIt() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'action=go\\ntitle=Go\\nscope=command\\n\\nrow=A\\nrun=a\\n' ;;
          go) sleep 0.4; touch '\(path("went-on"))' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the action") { sheet.command.actions.count == 1 }
        let action = try XCTUnwrap(sheet.command.actions.first)

        sheet.run(action, item: nil)
        try await wait("the call") { self.log() == ["read", "go"] }
        time += 1
        sheet.run(action, item: nil)
        try await pause(0.6)

        XCTAssertFalse(exists("went-on"))
        XCTAssertEqual(log(), ["read", "go"])
    }

    func testASecondPressOfARunningCardStopsIt() async throws {
        try script(body: "sleep 0.4\ntouch '\(path("went-on"))'")
        let sheet = try sheet()

        sheet.pressCard()
        XCTAssertTrue(sheet.isCardRunning)
        try await wait("the call") { self.log() == [""] }
        time += 1
        sheet.pressCard()
        XCTAssertFalse(sheet.isCardRunning)
        try await pause(0.6)

        XCTAssertFalse(exists("went-on"))
    }

    func testAStoppedToggleGoesBack() async throws {
        try script(header: "read=panel", "[ \"$1\" = read ] && { printf 'on=false\\n'; exit 0; }\nsleep 5")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the kind") { sheet.command.kind == .toggle }

        sheet.pressCard()
        XCTAssertEqual(sheet.state.on, true)
        time += 1
        sheet.pressCard()

        try await wait("the old state") { sheet.state.on == false }
    }

    // MARK: C6

    private static let big = String(repeating: "line \\ one=two\n", count: 2_000_000 / 15)

    func testATwoMegabyteValueOfAPartIsLeftOutOfTheArgumentsAndStdinHoldsIt() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'part=input\\ntext=\\n' ;;
          input) printf '%s' "$#" > '\(path("count"))'; cat > '\(path("got"))'; touch '\(path("done"))' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the part") { sheet.panel != nil }

        sheet.set(try XCTUnwrap(sheet.panel?.parts.first), to: Self.big)

        try await wait("the call") { self.exists("done") }
        XCTAssertEqual(try String(contentsOfFile: path("count"), encoding: .utf8), "1")
        let got = try String(contentsOfFile: path("got"), encoding: .utf8)
        XCTAssertEqual(TextBlock.blocks(in: got).first?.value("input"), Self.big)
    }

    func testATwoMegabyteRunIsLeftOutOfTheArgumentsAndStdinHoldsItAsValue() async throws {
        let url = try script(body: "printf '%s\\n' \"$#\"\ncat")

        let text = try await runs.answer(of: PluginCommand(id: "script", name: "Script", url: url), .item(SpotItem(title: "A", run: Self.big)))

        XCTAssertTrue(text.hasPrefix("1\n"))
        XCTAssertEqual(TextBlock.blocks(in: String(text.dropFirst(2))).first?.value("value"), Self.big)
    }

    func testAValueOf64KilobytesStaysInTheArguments() async throws {
        let url = try script(body: "printf '%s' \"${#2}\"")
        let value = String(repeating: "x", count: 65_536)

        let text = try await runs.answer(of: PluginCommand(id: "script", name: "Script", url: url), .set("a", to: value), input: "a=\(value)\n")

        XCTAssertEqual(text, "65536")
    }

    // MARK: L11

    func testAPressOfAPartWithinOneSecondOfItsStartDoesNothing() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'part=go\\ntitle=Go\\npress=true\\n' ;;
          go) sleep 0.3; touch '\(path("done"))' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the part") { sheet.panel != nil }
        let part = try XCTUnwrap(sheet.panel?.parts.first)

        sheet.press(part)
        time += 0.9
        sheet.press(part)

        XCTAssertEqual(sheet.calls.filter(\.doesWork).count, 1)
        try await wait("the end of the work") { self.exists("done") }
        try await wait("the read after the work") { self.log() == ["read", "go", "read"] }
    }

    func testAPickOrAnActionWithinOneSecondOfItsStartDoesNothing() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'action=go\\ntitle=Go\\nscope=command\\n\\nrow=A\\nrun=a\\n' ;;
          go) sleep 0.3; touch '\(path("action"))' ;;
          open) sleep 0.3; touch '\(path("pick"))' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        let action = try XCTUnwrap(sheet.command.actions.first)
        let item = try XCTUnwrap(sheet.list.selectedItem)

        sheet.run(action, item: nil)
        sheet.pick(item)
        sheet.run(action, item: nil)
        sheet.pick(item)

        XCTAssertEqual(sheet.calls.filter(\.doesWork).count, 2)
        try await wait("the end of the work") { self.exists("action") && self.exists("pick") }
    }

    func testAPressOfACardWithinOneSecondOfItsStartDoesNothing() async throws {
        try script(header: "read=panel", "[ \"$1\" = read ] && { printf 'on=false\\n'; exit 0; }\nsleep 0.3\ntouch '\(path("done"))'\nprintf 'on=true\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the kind") { sheet.command.kind == .toggle }

        sheet.pressCard()
        sheet.pressCard()

        XCTAssertEqual(sheet.state.on, true)
        XCTAssertTrue(sheet.isCardRunning)
        try await wait("the end of the work") { self.exists("done") && !sheet.isCardRunning }
        XCTAssertEqual(sheet.state.on, true)
    }

    func testASecondAskForAFormWithinOneSecondLeavesTheFirstRunning() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'action=new\\ntitle=New\\nscope=command\\nform=true\\n\\nrow=A\\nrun=a\\n' ;;
          new) sleep 0.3; printf 'title=New\\n\\nfield=a\\nlabel=A\\n' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the action") { sheet.command.actions.count == 1 }
        let action = try XCTUnwrap(sheet.command.actions.first)

        async let first = sheet.form(action, item: nil)
        try await wait("the call") { sheet.calls.contains(where: \.doesWork) }
        let second = try await sheet.form(action, item: nil)

        XCTAssertNil(second)
        let form = try await first
        XCTAssertEqual(form?.fields.map(\.name), ["a"])
    }

    func testQuittingStopsEachCall() async throws {
        try script(header: "read=sheet", """
        trap 'touch "\(path("stopped"))"; exit 0' TERM
        printf 'part=a\\ntitle=A\\n---\\n'
        while :; do sleep 0.05; done
        """)
        try script("deaf", "echo $$ > '\(path("deaf-pid"))'\ntrap '' TERM\nwhile :; do sleep 0.05; done")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the part") { sheet.panel != nil }
        let deaf = try XCTUnwrap(runs.sheets["deaf"])
        deaf.pressCard()
        try await wait("the deaf script") { self.exists("deaf-pid") }
        try await pause(0.1)
        let started = Date()

        runs.quit()

        XCTAssertLessThan(Date().timeIntervalSince(started), 3)
        try await wait("the stop") { self.exists("stopped") }
        let pid = try XCTUnwrap(Int32(try String(contentsOfFile: path("deaf-pid"), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)))
        try await wait("the end of the deaf script") { kill(pid, 0) != 0 }
    }

    func testQuittingLeavesNoChildThatIgnoresTheTerminateSignal() async throws {
        try script(body: "sh -c \"trap '' TERM; echo \\$\\$ > '\(path("pid"))'; while :; do sleep 0.05; done\" >/dev/null 2>&1 &\nsleep 30")
        let sheet = try sheet()
        sheet.pressCard()
        try await wait("the child") { self.exists("pid") }
        try await pause(0.1)
        let pid = try XCTUnwrap(Int32(try String(contentsOfFile: path("pid"), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)))
        let started = Date()

        runs.quit()

        XCTAssertLessThan(Date().timeIntervalSince(started), 3)
        try await wait("the end of the child") { kill(pid, 0) != 0 }
    }

    // MARK: K5

    func testClosingThePanelClosesASheetOfPartsAndTheNextOpenReads() async throws {
        try script(header: "read=sheet", "printf 'part=a\\ntext=one\\n'")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the part") { sheet.panel != nil }
        sheet.set(try XCTUnwrap(sheet.panel?.parts.first), to: "typed")

        runs.panelClosed()

        XCTAssertFalse(sheet.isOpen)
        XCTAssertNil(sheet.panel)
        sheet.open {}
        try await wait("the new read") { sheet.panel?.parts.first?.value == "one" }
        XCTAssertEqual(log(), ["read", "read"])
    }

    func testClosingThePanelLeavesASheetOfRowsOpen() async throws {
        try script(header: "read=sheet", "printf 'row=A\\nrun=a\\n'")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        runs.panelClosed()

        XCTAssertTrue(sheet.isOpen)
        XCTAssertEqual(sheet.list.shown.count, 1)
    }

    // MARK: F7

    func testAWidgetCanPlaceAnyScriptWithARead() async throws {
        try script("onpanel", header: "read=panel\nkey=p", log: "onpanel", "printf 'title=P\\n'")
        try script("onsheet", header: "read=sheet\nkey=s", log: "onsheet", "printf 'title=S\\n'")
        try "[[widgets]]\nname = \"W\"\nlayout = \"pair\"\nplaces = [\"onpanel\", \"onsheet\"]\n".write(to: folder.appendingPathComponent("w.toml"), atomically: true, encoding: .utf8)
        _ = try scanned()
        XCTAssertEqual(log("onsheet"), [])

        runs.panelOpened()

        try await wait("the values") { self.runs.readings["onpanel"]?.value?.title == "P" && self.runs.readings["onsheet"]?.value?.title == "S" }
    }

    func testAWidgetCannotPlaceAScriptWithNoRead() throws {
        try script("once")
        try "[[widgets]]\nname = \"W\"\nlayout = \"single\"\nplaces = [\"once\"]\n".write(to: folder.appendingPathComponent("w.toml"), atomically: true, encoding: .utf8)

        let scan = try PluginFolder(url: folder).scan()

        XCTAssertEqual(scan.refused, [Refusal(file: "w", reason: "W names no metric called once")])
    }

    func testTheMenuBarShowsWhatTheSheetHolds() async throws {
        try script("pulls", header: "name=Pull requests\nread=120\nkey=g\ntray=true", "printf 'title=2\\n\\nrow=A\\nrun=a\\n\\nrow=B\\nrun=b\\n'")
        let sheet = try sheet("pulls")

        try await wait("the mark") { !self.runs.trayMarks.isEmpty }

        XCTAssertEqual(runs.trayMarks.first?.mark.summary, "Pull requests: 2")
        XCTAssertEqual(sheet.list.shown.count, 2)
    }

    // MARK: L3, moments

    func testEachMomentReadsOnlyTheScriptsThatListIt() async throws {
        try script("onlaunch", header: "read=launch", log: "onlaunch", "printf 'title=L\\n'")
        try script("onwake", header: "read=wake", log: "onwake", "printf 'title=W\\n'")
        try script("onpanel", header: "read=panel", log: "onpanel", "printf 'title=P\\n'")
        _ = try scanned()
        try await pause(0.2)
        XCTAssertEqual(log("onlaunch") + log("onwake") + log("onpanel"), [])

        runs.arrive(.launch)
        try await wait("the launch read") { self.log("onlaunch") == ["read"] }
        XCTAssertEqual(log("onwake"), [])

        runs.arrive(.wake)
        try await wait("the wake read") { self.log("onwake") == ["read"] }
        XCTAssertEqual(log("onlaunch"), ["read"])
        XCTAssertEqual(log("onpanel"), [])

        runs.arrive(.panel)
        try await wait("the panel read") { self.log("onpanel") == ["read"] }
        XCTAssertEqual(log("onlaunch"), ["read"])
        XCTAssertEqual(log("onwake"), ["read"])
    }

    func testAnOpenSheetOfRowsIsNotReadWithThePanelClosedAndIsReadWhenThePanelOpens() async throws {
        try script(header: "read=5\nkey=a", "printf 'row=A\\nrun=a\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 && sheet.calls.isEmpty }
        XCTAssertEqual(log(), ["read"])
        time += 5
        runs.tick()
        try await wait("the read from the number") { self.log() == ["read", "read"] && sheet.calls.isEmpty }

        runs.panelClosed()
        XCTAssertTrue(sheet.isOpen)
        time += 5
        runs.tick()
        try await pause(0.3)
        XCTAssertEqual(log(), ["read", "read"])

        time += 5
        runs.panelOpened()
        try await wait("the read when the panel opens") { self.log() == ["read", "read", "read"] }
    }

    func testAStreamOfAnOpenSheetOfRowsStopsWhenThePanelClosesAndStartsWhenItOpens() async throws {
        try script(header: "read=sheet", "printf 'row=A\\nrun=a\\n---\\n'\nsleep 0.5\ntouch '\(path("went-on"))'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        runs.panelClosed()
        try await pause(0.8)
        XCTAssertFalse(exists("went-on"))
        XCTAssertEqual(sheet.list.shown.count, 1)

        time += 5
        runs.panelOpened()
        try await wait("the new read") { self.log() == ["read", "read"] }
    }

    func testAScriptWithLaunchAndANumberIsReadWithThePanelClosed() async throws {
        try script(header: "read=launch,1\nkey=a", "printf 'title=1\\n'")
        _ = try scanned()
        try await wait("the first read") { self.log().count == 1 }

        time += 1

        try await wait("the read from the clock") { self.log().count == 2 }
    }

    // MARK: Y2, Y3, Y5

    /// Writes a staying script. It logs each line of its stdin, and prints the frame after each block.
    @discardableResult
    private func staying(header: String = "stay=true", frame: String = "row=A\\nrun=a\\n") throws -> URL {
        try script(header: header, """
        trap 'touch "\(path("ended"))"' EXIT
        while IFS= read -r line; do
          printf '%s\\n' "$line" >> '\(path("blocks"))'
          [ -n "$line" ] || printf '\(frame)---\\n'
        done
        """)
    }

    /// The blocks that a staying script got, one string for each.
    private func blocks() -> [String] {
        let text = (try? String(contentsOfFile: path("blocks"), encoding: .utf8)) ?? ""
        return text.components(separatedBy: "\n\n").filter { !$0.isEmpty }
    }

    /// The first scanned script's sheet, with each failure that it tells the person, before the script can start.
    private func toldSheet() throws -> (sheet: SpotSheet, told: () -> [String]) {
        let sheet = runs.sheet(for: try XCTUnwrap(PluginFolder(url: folder).scan().scripts.first))
        var failures: [String] = []
        sheet.onReport = { if case .failure(let text) = $0 { failures.append(text) } }
        return (sheet, { failures })
    }

    private static let form = """
    while IFS= read -r line; do
      printf '%%s\\n' "$line" >> '%@'
      case "$line" in
        name=*) name=${line#name=}; filled= ;;
        field.*) filled=1 ;;
        '')
          if [ "$name" = new ] && [ -z "$filled" ]; then
            printf 'title=New\\n\\nfield=a\\nlabel=A\\n---\\n'
          else
            printf 'action=new\\ntitle=New\\nscope=command\\nform=true\\n\\nrow=A\\nrun=a\\n---\\n'
          fi
          ;;
      esac
    done
    """

    func testAPickReachesTheRunningStayingScript() async throws {
        try staying()
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))

        try await wait("the call") { self.blocks() == ["name=read", "name=open\nvalue=a"] }
        XCTAssertEqual(log().count, 1)
        XCTAssertTrue(sheet.calls.isEmpty)
    }

    func testAnActionReachesTheRunningStayingScript() async throws {
        try staying(frame: "action=go\\ntitle=Go\\nscope=item\\n\\nrow=A\\nrun=a\\n")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        let action = try XCTUnwrap(sheet.command.actions.first)

        sheet.run(action, item: sheet.list.selectedItem)
        sheet.run(action, item: nil)

        try await wait("the calls") { self.blocks() == ["name=read", "name=go\nvalue=a", "name=go"] }
        XCTAssertEqual(log().count, 1)
    }

    func testAFormOfAStayingScriptGoesAsTwoBlocks() async throws {
        try script(header: "stay=true", String(format: Self.form, path("blocks")))
        let sheet = try sheet()
        sheet.open {}
        try await wait("the action") { sheet.command.actions.count == 1 }
        let action = try XCTUnwrap(sheet.command.actions.first)

        let asked = try await sheet.form(action, item: nil)
        let form = try XCTUnwrap(asked)
        XCTAssertEqual(form.fields.map(\.name), ["a"])
        XCTAssertEqual(sheet.command.actions.count, 1)
        var draft = FormDraft(form: form, prefill: "")
        draft.set("one", for: "a")
        let isDone = try await sheet.submit(action, item: nil, draft: draft)

        XCTAssertTrue(isDone)
        try await wait("the blocks") { self.blocks() == ["name=read", "name=new", "name=new\nfield.a=one"] }
        XCTAssertEqual(log().count, 1)
    }

    func testASecondAskForAFormOfAStayingScriptLeavesTheFirstWaiting() async throws {
        try script(header: "stay=true", """
        while IFS= read -r line; do
          case "$line" in
            name=new) sleep 0.3; printf 'title=New\\n\\nfield=a\\nlabel=A\\n---\\n' ;;
            name=read) printf 'action=new\\ntitle=New\\nscope=command\\nform=true\\n---\\n' ;;
          esac
        done
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the action") { sheet.command.actions.count == 1 }
        let action = try XCTUnwrap(sheet.command.actions.first)

        async let first = sheet.form(action, item: nil)
        try await pause(0.1)
        let second = try await sheet.form(action, item: nil)

        XCTAssertNil(second)
        let form = try await first
        XCTAssertEqual(form?.fields.map(\.name), ["a"])
    }

    func testAFormOfAStayingScriptThatEndsIsABadForm() async throws {
        try script(header: "stay=true", """
        while IFS= read -r line; do
          case "$line" in
            name=new) exit 0 ;;
            name=read) printf 'action=new\\ntitle=New\\nscope=command\\nform=true\\n---\\n' ;;
          esac
        done
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the action") { sheet.command.actions.count == 1 }
        let action = try XCTUnwrap(sheet.command.actions.first)

        do {
            _ = try await sheet.form(action, item: nil)
            XCTFail("It should have no form.")
        } catch {
            XCTAssertEqual(error as? PluginError, .badForm)
        }
    }

    func testASearchReachesTheRunningStayingScript() async throws {
        try staying(frame: "search=script\\n\\nrow=A\\nrun=a\\n")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.search("rep")

        try await wait("the search") { self.blocks() == ["name=read", "name=read\nvalue=rep"] }
        try await wait("the answer") { !sheet.list.isWaiting }
        XCTAssertEqual(log().count, 1)
    }

    func testACardCallOfAStayingScriptReachesIt() async throws {
        try staying()
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.pressCard()

        try await wait("the call") { self.blocks().count == 2 }
        XCTAssertEqual(log().count, 1)
        XCTAssertFalse(sheet.isCardRunning)
    }

    func testAStayingTrayScriptRunsWithThePanelClosedAndItsFrameReachesTheMenuBar() async throws {
        try staying(header: "stay=true\ntray=true", frame: "title=3\\n")
        _ = try scanned()

        try await wait("the mark") { self.runs.trayMarks.first?.mark.summary == "Script: 3" }

        XCTAssertFalse(runs.isPanelOpen)
        XCTAssertEqual(log().count, 1)
        XCTAssertEqual(blocks(), ["name=read"])
    }

    func testAStayingTrayScriptGoesOnWhenItsSheetAndThePanelCloseAndAScanComes() async throws {
        try staying(header: "stay=true\ntray=true", frame: "title=3\\n\\nrow=A\\nrun=a\\n")
        let sheet = try sheet()
        try await wait("the row") { sheet.list.shown.count == 1 }
        runs.panelOpened()
        sheet.open {}
        sheet.close()
        runs.panelClosed()
        _ = try scanned()
        try await pause(0.3)

        XCTAssertFalse(exists("ended"))
        XCTAssertEqual(log().count, 1)

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))

        try await wait("the call") { self.blocks().last == "name=open\nvalue=a" }
        XCTAssertEqual(log().count, 1)
    }

    func testAFrameOfPartsChangesNoMarkOfAStayingTrayScript() async throws {
        try script(header: "stay=true\ntray=true", """
        while IFS= read -r line; do
          case "$line" in
            name=read) printf 'title=3\\n---\\n' ;;
            name=open) printf 'part=a\\ntitle=A\\n---\\n'; touch '\(path("printed"))' ;;
          esac
        done
        """)
        let sheet = try sheet()
        try await wait("the mark") { !self.runs.trayMarks.isEmpty }

        sheet.pick(SpotItem(title: "A", run: "a"))
        try await wait("the frame") { self.exists("printed") }
        try await pause(0.2)

        XCTAssertEqual(runs.trayMarks.first?.mark.summary, "Script: 3")
        XCTAssertEqual(runs.trayMarks.first?.mark.isStale, false)
    }

    func testASheetOfARunningStayingScriptOpensAtOnceWithItsLastFrame() async throws {
        try staying(header: "stay=true\ntray=true", frame: "title=3\\n\\npart=a\\ntitle=A\\n")
        let sheet = try sheet()
        try await wait("the mark") { !self.runs.trayMarks.isEmpty }
        XCTAssertNil(sheet.panel)
        var isReady = false

        sheet.open { isReady = true }

        XCTAssertTrue(isReady)
        XCTAssertEqual(sheet.panel?.parts.map(\.id), ["a"])
        XCTAssertEqual(log().count, 1)
    }

    func testAStayingScriptIsWantedByThePanelOnlyWhileItIsOpen() async throws {
        try staying(header: "stay=true\nread=panel")
        let sheet = try sheet()
        try await pause(0.2)
        XCTAssertEqual(log(), [])

        runs.panelOpened()
        try await wait("the frame") { sheet.list.shown.count == 1 }
        XCTAssertEqual(blocks(), ["name=read"])

        runs.panelClosed()
        try await wait("the end") { self.exists("ended") }
        XCTAssertEqual(log().count, 1)
    }

    func testAStayingScriptWithLaunchRunsAtAllTimesAndEachMomentReachesIt() async throws {
        try staying(header: "stay=true\nread=launch,wake")
        let sheet = try sheet()

        runs.arrive(.launch)
        try await wait("the frame") { sheet.list.shown.count == 1 }
        XCTAssertEqual(blocks(), ["name=read"])

        runs.panelOpened()
        runs.panelClosed()
        runs.arrive(.wake)

        try await wait("the read of the wake") { self.blocks() == ["name=read", "name=read"] }
        XCTAssertFalse(exists("ended"))
        XCTAssertEqual(log().count, 1)
    }

    func testAStayingScriptWithOnlyWakeDoesNotStartAtItsMoment() async throws {
        try staying(header: "stay=true\nread=wake")
        _ = try scanned()

        runs.arrive(.wake)
        try await pause(0.3)

        XCTAssertEqual(log(), [])
    }

    func testAStayingScriptWithANumberGetsAReadOnItsTimer() async throws {
        try staying(header: "stay=true\ntray=true\nread=5", frame: "title=3\\n")
        _ = try scanned()
        try await wait("the mark") { !self.runs.trayMarks.isEmpty }
        XCTAssertEqual(blocks(), ["name=read"])

        time += 5
        runs.tick()

        try await wait("the read") { self.blocks() == ["name=read", "name=read"] }
        XCTAssertEqual(log().count, 1)
    }

    func testAStayingScriptThatEndedStartsAgainAtTheNextMoment() async throws {
        try script(header: "stay=true\ntray=true", """
        [ -f '\(path("second"))' ] || { touch '\(path("second"))'; printf 'title=1\\n'; exit 0; }
        while IFS= read -r line; do
          [ -n "$line" ] || printf 'title=2\\n---\\n'
        done
        """)
        let sheet = try sheet()
        try await wait("the end of the first run") { sheet.reading.isStale }
        XCTAssertEqual(sheet.reading.value?.title, "1")
        XCTAssertEqual(log().count, 1)

        runs.arrive(.wake)

        try await wait("the second run") { sheet.reading.value?.title == "2" }
        XCTAssertFalse(sheet.reading.isStale)
        XCTAssertEqual(log().count, 2)
    }

    func testACallStartsAStayingScriptThatNothingWantsAndItEndsAfterTheCall() async throws {
        try staying()
        let sheet = try sheet()

        sheet.pick(SpotItem(title: "A", run: "a"))

        try await wait("the end") { self.exists("ended") }
        XCTAssertEqual(blocks(), ["name=read", "name=open\nvalue=a"])
        XCTAssertEqual(log().count, 1)
    }

    func testAStayingScriptThatLeavesTheFolderEnds() async throws {
        let url = try staying(header: "stay=true\ntray=true", frame: "title=3\\n")
        _ = try scanned()
        try await wait("the mark") { !self.runs.trayMarks.isEmpty }

        try FileManager.default.removeItem(at: url)
        _ = try scanned()

        try await wait("the end") { self.exists("ended") }
    }

    private static let givenUp = "Script failed 3 times in one minute. Openspot will not start it again until its file changes."

    func testThreeQuickFailuresStopNewStartsAndTellThePersonOnce() async throws {
        try script(header: "stay=true\ntray=true\nread=wake", "echo broken >&2\nexit 1")
        let (sheet, told) = try toldSheet()

        _ = try scanned()
        try await wait("the first failure") { told().count == 1 }
        runs.arrive(.wake)
        try await wait("the second failure") { told().count == 2 }
        XCTAssertEqual(told(), ["Script failed. broken", "Script failed. broken"])
        runs.arrive(.wake)
        try await wait("the third failure") { told().count == 3 }
        XCTAssertEqual(told().last, Self.givenUp)
        XCTAssertEqual(log().count, 3)

        runs.arrive(.wake)
        runs.panelOpened()
        runs.panelClosed()
        _ = try scanned()
        sheet.pick(SpotItem(title: "A", run: "a"))
        try await pause(0.3)

        XCTAssertEqual(log().count, 3)
        XCTAssertEqual(told().filter { $0 == Self.givenUp }.count, 1)
        XCTAssertEqual(told().count, 3)
    }

    func testFailuresMoreThanAMinuteApartDoNotStopNewStarts() async throws {
        try script(header: "stay=true\ntray=true", "echo broken >&2\nexit 1")
        let (_, told) = try toldSheet()
        _ = try scanned()

        for count in 1...4 {
            try await wait("failure \(count)") { told().count == count }
            time += 31
            runs.arrive(.wake)
        }

        try await wait("the fifth start") { self.log().count == 5 }
        XCTAssertEqual(told().filter { $0 == Self.givenUp }, [])
    }

    func testAChangedFileStartsAStoppedScriptAgainAndAnUnchangedOneStaysStopped() async throws {
        try script(header: "stay=true\ntray=true", "echo broken >&2\nexit 1")
        let (_, told) = try toldSheet()
        _ = try scanned()
        try await wait("the first failure") { told().count == 1 }
        runs.arrive(.wake)
        try await wait("the second failure") { told().count == 2 }
        runs.arrive(.wake)
        try await wait("the third failure") { told().count == 3 }

        _ = try scanned()
        try await pause(0.2)
        XCTAssertEqual(log().count, 3)

        try staying(header: "stay=true\ntray=true", frame: "title=3\\n")
        _ = try scanned()

        try await wait("the mark") { self.runs.trayMarks.first?.mark.summary == "Script: 3" }
        XCTAssertEqual(log().count, 4)
    }

    func testASheetOfAStoppedScriptDoesNotOpen() async throws {
        try script(header: "stay=true\ntray=true", "exit 1")
        let (sheet, told) = try toldSheet()
        _ = try scanned()
        try await wait("the first failure") { told().count == 1 }
        runs.arrive(.wake)
        try await wait("the second failure") { told().count == 2 }
        runs.arrive(.wake)
        try await wait("the third failure") { told().count == 3 }
        var isReady = false

        sheet.open { isReady = true }
        try await pause(0.2)

        XCTAssertFalse(isReady)
        XCTAssertFalse(sheet.isOpen)
    }

    func testASheetThatAStayingScriptNeverShowedDoesNotStayOpen() async throws {
        try script(header: "stay=true", "exit 1")
        let sheet = try sheet()
        var isReady = false

        sheet.open { isReady = true }
        try await wait("the end") { !sheet.isOpen }

        XCTAssertFalse(isReady)
    }

    // MARK: C4, rank, sandbox

    func testSearchTextReachesTheScriptAfterAPause() async throws {
        try script(header: "read=sheet", "printf 'search=script\\n\\nrow=%s\\nrun=a\\n' \"${2:-none}\"")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the first answer") { sheet.list.shown.map(\.title) == ["none"] }

        for text in ["r", "re", "rep"] {
            sheet.search(text)
            try await pause(0.05)
        }
        XCTAssertEqual(log(), ["read"])

        try await wait("the answer") { sheet.list.shown.map(\.title) == ["rep"] }
        XCTAssertEqual(log(), ["read", "read rep"])
    }

    func testANewKeyStopsTheOlderSearch() async throws {
        try script(header: "read=sheet", """
        [ "$2" = slow ] && { sleep 0.8; touch '\(path("went-on"))'; }
        printf 'search=script\\n\\nrow=%s\\nrun=a\\n' "${2:-none}"
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the first answer") { sheet.list.shown.map(\.title) == ["none"] }

        sheet.search("slow")
        try await wait("the search") { self.log().count == 2 }
        sheet.search("slower")
        try await wait("the answer") { sheet.list.shown.map(\.title) == ["slower"] }
        try await pause(0.9)

        XCTAssertFalse(exists("went-on"))
    }

    func testARankWithANumberNeedsAKey() throws {
        try script("a", header: "read=30\nrank=1")
        try script("b", header: "read=panel,30\nrank=2")
        try script("c", header: "read=30\nrank=3\nkey=c")

        XCTAssertEqual(try PluginFolder(url: folder).scan().refused.map(\.file), ["a", "b"])
        XCTAssertEqual(
            try PluginFolder(url: folder).scan().refused.first?.reason,
            "A needs a key to join the main search, because a number in its read and no key gives it no spot"
        )
    }

    func testTheSandboxClicksAFileWithNoRead() async throws {
        let url = try script(body: "printf 'part=a\\ntitle=%s\\n' \"$#\"")
        let sheet = runs.sheet(for: SheetSandbox.command(file: url))

        sheet.open {}

        try await wait("the sheet") { sheet.panel?.parts.first?.title == "0" }
        XCTAssertEqual(log(), [""])
    }

    func testTheSandboxReadsAFileWithARead() async throws {
        let url = try script(header: "read=panel", "printf 'part=a\\ntitle=%s\\n' \"$1\"")
        let sheet = runs.sheet(for: SheetSandbox.command(file: url))

        sheet.open {}

        try await wait("the sheet") { sheet.panel?.parts.first?.title == "read" }
    }
}

private extension Date {
    static func += (date: inout Date, seconds: TimeInterval) {
        date = date.addingTimeInterval(seconds)
    }
}
