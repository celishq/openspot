import XCTest
@testable import OpenspotCore

/// Proves one owner, one sheet for each script, and when a script is read.
@MainActor
final class SpotRunsReadTests: SpotRunsCase {
    // MARK: A1, A2

    func testAnOpenAtLaunchWaitsForEachReadAndServesTheNextOpen() async throws {
        try script(header: "read=panel", "echo run >> '\(path("runs"))'\nsleep 0.1\nprintf 'title=Read\\n'")
        let sheet = try sheet()

        runs.panelOpened()
        XCTAssertTrue(runs.isReading)
        try await wait("the answer") { !self.runs.isReading }
        runs.panelClosed()
        runs.panelOpened()
        try await pause(0.1)

        XCTAssertEqual(sheet.state.title, "Read")
        XCTAssertEqual(try String(contentsOfFile: path("runs"), encoding: .utf8), "run\n")
    }

    // MARK: M6

    func testEachReadKnowsWhyItRuns() async throws {
        try script(header: "read=launch,wake,panel,sheet\nkey=r", "echo \"$OPENSPOT_REASON\" >> '\(path("reasons"))'\nprintf 'row=A\\nrun=a\\n'")
        let sheet = try sheet()
        var expected: [String] = []
        func step(_ reason: String, _ act: () -> Void) async throws {
            time += 10
            act()
            expected.append(reason)
            try await wait("the \(reason) read") { self.log("reasons") == expected }
            try await wait("the end of the \(reason) read") { !self.runs.isReading }
        }

        try await step("launch") { runs.arrive(.launch) }
        try await step("wake") { runs.arrive(.wake) }
        try await step("panel") { runs.panelOpened() }
        try await step("sheet") { sheet.open(onReady: {}) }
        try await step("change") { sheet.read(need: .change) }
    }

    func testAReadOnItsClockSaysSo() async throws {
        try script(header: "read=60\nkey=r", "echo \"$OPENSPOT_REASON\" >> '\(path("reasons"))'\nprintf 'title=1\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open(onReady: {})
        try await wait("the sheet read") { self.log("reasons") == ["sheet"] && !self.runs.isReading }

        time += 61
        runs.tick()

        try await wait("the timer read") { self.log("reasons") == ["sheet", "timer"] }
    }

    func testAReadOfTheSearchSaysSo() async throws {
        try script(header: "read=sheet\nkey=r", "echo \"$OPENSPOT_REASON $*\" >> '\(path("reasons"))'\nprintf 'search=script\\n\\nrow=A\\nrun=a\\n'")
        let sheet = try sheet()

        sheet.open(onReady: {})
        try await wait("the first read") { self.log("reasons") == ["sheet read"] }
        sheet.search("k")

        try await wait("the search read") { self.log("reasons") == ["sheet read", "search read k"] }
    }

    func testAnOpenAtLaunchRunsNoScriptThatReadsOnlyAtItsSheet() async throws {
        try script(header: "read=sheet", "echo run >> '\(path("runs"))'")
        _ = try sheet()

        runs.panelOpened()
        try await pause(0.1)

        XCTAssertFalse(runs.isReading)
        XCTAssertFalse(exists("runs"))
    }

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
        try script(header: "read=sheet", "printf 'title=3\\ntone=good\\n\\nrow=A\\nrun=a\\n\\ntext=b\\ntitle=B\\n'")
        let sheet = try sheet()

        sheet.open {}

        try await wait("the answer") { sheet.list.shown.count == 1 }
        XCTAssertEqual(sheet.lastFrame, "title=3\ntone=good\n\nrow=A\nrun=a\n\ntext=b\ntitle=B\n")
        XCTAssertEqual(sheet.panel?.parts.map(\.id), ["b"])
        XCTAssertEqual(sheet.reading.value?.title, "3")
        XCTAssertEqual(sheet.reading.value?.tone, .good)
        XCTAssertTrue(sheet.isOpen)
    }

    func testAScriptThatLeavesTheFolderLosesItsSheetAndItsRead() async throws {
        let url = try script(header: "read=sheet", "sleep 0.2\ntouch '\(path("went-on"))'")
        let sheet = try sheet()
        sheet.read()

        try FileManager.default.removeItem(at: url)
        _ = try scanned()
        try await pause(0.35)

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
        try script(header: "read=panel\nglobal=true", "printf 'row=A\\nrun=a\\n'")
        let sheet = try sheet()

        runs.panelOpened()
        try await wait("the row") { sheet.list.shown.count == 1 }
        sheet.open {}
        time += 4
        sheet.close()
        sheet.open {}
        try await pause(0.15)

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
        try await pause(0.1)

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
        try script(header: "read=1\nkey=a", "printf 'text=a\\ntitle=A\\n'")
        let sheet = try sheet()
        try await pause(0.1)
        XCTAssertEqual(log(), [])

        sheet.open {}
        try await wait("the first read") { sheet.panel != nil && sheet.calls.isEmpty }
        XCTAssertEqual(log(), ["read"])

        time += 1
        try await wait("the read from the timer") { self.log() == ["read", "read"] }

        sheet.close()
        time += 1
        try await pause(0.1)
        XCTAssertEqual(log(), ["read", "read"])
    }

    func testAScriptThatPrintsEveryIsNotReadAgain() async throws {
        try script(header: "read=sheet", "printf 'every=1\\n\\ntext=a\\ntitle=A\\n'")
        let sheet = try sheet()

        sheet.open {}
        try await wait("the part") { sheet.panel != nil }
        try await pause(0.1)

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
        try await pause(0.1)
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
        [ "$1" = read ] && printf 'grid=go\\n\\nbutton=go\\ntitle=Go\\n'
        exit 0
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the part") { sheet.panel != nil }

        sheet.press(try XCTUnwrap(sheet.panel?.parts.first))

        try await wait("the read after the press") { self.log() == ["read", "go", "read"] }
    }

    func testAChangeDuringARunningReadReadsOnceMoreAfterIt() async throws {
        try script(header: "read=sheet", "sleep 0.2\nprintf 'row=A\\nrun=a\\n'")
        let sheet = try sheet()

        sheet.read()
        sheet.read(need: .change)

        try await wait("two reads") { self.log() == ["read", "read"] }
    }

    func testOneSlowScriptDoesNotDelayAnother() async throws {
        try script("slow", header: "read=panel\nglobal=true", "\(untilRelease)\nprintf 'row=S\\nrun=s\\n'")
        try script("fast", header: "read=panel\nglobal=true", "printf 'row=F\\nrun=f\\n'")
        _ = try scanned()

        runs.panelOpened()

        let fast = try XCTUnwrap(runs.sheets["fast"])
        try await wait("the fast answer") { fast.list.shown.count == 1 }
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
        try await pause(0.1)
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
        try await pause(0.15)

        XCTAssertEqual(log(), ["read", "on"])
        XCTAssertEqual(sheet.state.on, true)
    }

    func testAScriptWithNoReadIsNotReadAfterACall() async throws {
        try script()
        let sheet = try sheet()

        sheet.pressCard()
        try await wait("the call") { self.log() == [""] }
        try await pause(0.1)

        XCTAssertEqual(log(), [""])
    }
}
