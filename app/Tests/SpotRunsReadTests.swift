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

    func testEachCallKnowsTheIDOfItsSpot() async throws {
        try script("coffee", header: "read=sheet", "printf 'row=%s\\n' \"$OPENSPOT_ID\"")
        let command = try XCTUnwrap(try scanned().spots.first { $0.id == "coffee" })

        let items = try await command.items(timeout: 5).items

        XCTAssertEqual(items.map(\.run), ["coffee"])
    }

    // MARK: M6

    func testALaterFrameOfAReadWithABlockReplacesItsValue() async throws {
        try script(header: "read=sheet", "printf 'main=m\\n\\ntext=m\\ntitle=3\\n---\\n'\nsleep 0.05\nprintf 'text=b\\ntitle=B\\n---\\n'")
        let sheet = try sheet()
        let frames = FrameLog(sheet)

        runs.panelOpened()
        sheet.open {}

        try await wait("the later frame") { frames.last?.contains("B") == true }
        XCTAssertEqual(sheet.reading.value?.title, "B")
    }

    func testALaterFrameWithAHeadReplacesThePartsOfTheRead() async throws {
        try script(header: "read=sheet", "printf 'title=S\\n\\ntext=a\\ntitle=A\\n\\ntext=b\\ntitle=B\\n---\\n'\nsleep 0.05\nprintf 'title=S\\n\\ntext=a\\ntitle=A2\\n---\\n'")
        let sheet = try sheet()
        let frames = FrameLog(sheet)

        runs.panelOpened()
        sheet.open {}

        try await wait("the later frame") { frames.frames.count == 2 }
        XCTAssertEqual(sheet.panel?.parts.map(\.id), ["a"])
        XCTAssertEqual(sheet.panel?.parts.first?.title, "A2")
    }

    func testALaterFrameOfOnlyAHeadKeepsTheList() async throws {
        try script(header: "read=sheet", "printf 'title=L\\n\\nrow=a\\ntitle=A\\n---\\n'\nsleep 0.05\nprintf 'title=L\\n---\\n'")
        let sheet = try sheet()
        let frames = FrameLog(sheet)

        runs.panelOpened()
        sheet.open {}

        try await wait("the later frame") { frames.frames.count == 2 }
        XCTAssertEqual(sheet.list.shown.map(\.run), ["a"])
    }

    func testALaterFrameWithNoHeadReplacesAllTheParts() async throws {
        try script(header: "read=sheet", "printf 'title=S\\n\\ntext=a\\ntitle=A\\n\\ntext=b\\ntitle=B\\n---\\n'\nsleep 0.05\nprintf 'text=a\\ntitle=A2\\n---\\n'")
        let sheet = try sheet()
        let frames = FrameLog(sheet)

        runs.panelOpened()
        sheet.open {}

        try await wait("the later frame") { frames.frames.count == 2 }
        XCTAssertEqual(sheet.panel?.parts.map(\.id), ["a"])
        XCTAssertEqual(sheet.panel?.parts.first?.title, "A2")
    }

    func testABigFrameAndASmallFrameAfterItShowInTheirOrder() async throws {
        try script(header: "read=sheet", """
        i=0
        while [ $i -lt 3000 ]; do printf 'row=r%s\\ntitle=Row number %s\\n\\n' $i $i; i=$((i+1)); done
        printf -- '---\\nrow=last\\ntitle=Last\\n---\\n'
        """)
        let sheet = try sheet()
        let frames = FrameLog(sheet)

        runs.panelOpened()
        sheet.open {}

        try await wait("both frames") { frames.frames.count == 2 }
        XCTAssertGreaterThan(frames.frames.first?.utf8.count ?? 0, 64 << 10)
        XCTAssertEqual(sheet.list.shown.map(\.run), ["last"])
    }

    func testEachReadKnowsWhyItRuns() async throws {
        try script(header: "read=panel,sheet", "echo \"$OPENSPOT_REASON\" >> '\(path("reasons"))'\nprintf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()
        var expected: [String] = []
        func step(_ reason: String, _ act: () -> Void) async throws {
            time += 10
            act()
            expected.append(reason)
            try await wait("the \(reason) read") { self.log("reasons") == expected }
            try await wait("the end of the \(reason) read") { !self.runs.isReading }
        }

        try await step("panel") { runs.panelOpened() }
        try await step("sheet") { sheet.open(onReady: {}) }
        try await step("change") { sheet.read(need: .change) }
    }

    func testAReadOnItsClockSaysSo() async throws {
        try script(header: "every=60", "echo \"$OPENSPOT_REASON\" >> '\(path("reasons"))'\nprintf 'title=1\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open(onReady: {})
        try await wait("the sheet read") { self.log("reasons") == ["sheet"] && !self.runs.isReading }

        time += 61
        runs.raise(.clock)

        try await wait("the timer read") { self.log("reasons") == ["sheet", "timer"] }
    }

    func testAReadOfTheSearchSaysSo() async throws {
        try script(header: "read=sheet", "echo \"$OPENSPOT_REASON $*\" >> '\(path("reasons"))'\nprintf 'search=script\\n\\nrow=a\\ntitle=A\\n'")
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
        try script("cups", header: "every=30")
        try script("tool", header: "read=sheet")
        try script("once")
        try "[[widgets]]\ntitle = \"W\"\ngrid = [\"cups\"]\nsize = \"square\"\n".write(to: folder.appendingPathComponent("w.toml"), atomically: true, encoding: .utf8)

        let scan = try scanned()

        XCTAssertEqual(Set(runs.sheets.keys), ["cups", "tool", "once"])
        XCTAssertEqual(Set(scan.spots.map(\.id)), ["cups", "tool", "once", "w/W"])
        XCTAssertEqual(scan.spots.first { $0.id == "cups" }?.headerState.isOnGrid, false)
    }

    func testASheetReportsItsFrameAndKeepsItsRowsPartsAndValue() async throws {
        try script(header: "read=sheet", "printf 'main=m\\n\\ntext=m\\ntitle=3\\ntone=good\\n\\nrow=a\\ntitle=A\\n\\ntext=b\\ntitle=B\\n'")
        let sheet = try sheet()
        let frames = FrameLog(sheet)

        sheet.open {}

        try await wait("the answer") { sheet.list.shown.count == 1 }
        XCTAssertEqual(frames.last, "main=m\n\ntext=m\ntitle=3\ntone=good\n\nrow=a\ntitle=A\n\ntext=b\ntitle=B\n")
        XCTAssertEqual(sheet.panel?.parts.map(\.id), ["m", "b"])
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
        try script(header: "read=sheet", "sleep 0.2\nprintf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()

        sheet.read()
        sheet.read()
        sheet.read()

        try await wait("the row") { sheet.list.shown.count == 1 }
        XCTAssertEqual(log(), ["read"])
    }

    func testAPanelOpenAndASheetOpenWithinFiveSecondsRunOnce() async throws {
        try script(header: "read=panel\noffers=search", "printf 'row=a\\ntitle=A\\n'")
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
        try script(header: "read=panel", "sleep 0.2\nprintf 'detail=Off\\n\\nrow=a\\ntitle=A\\n'")
        let sheet = try sheet()

        runs.panelOpened()
        sheet.open {}

        try await wait("the row") { sheet.list.shown.count == 1 }
        XCTAssertEqual(log(), ["read"])
    }

    func testAnAnswerOlderThanFiveSecondsIsReadAgain() async throws {
        try script(header: "read=sheet", "printf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        sheet.close()

        time += 5
        sheet.open {}

        try await wait("the second read") { self.log().count == 2 }
    }

    func testASheetWithNothingToTypeOpensAfterAPanelCloseWithItsPartsAtOnce() async throws {
        try script(header: "read=sheet", "printf 'text=bar\\ntitle=Go\\n\\nrow=a\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the parts") { sheet.panel != nil && !sheet.isReading }
        runs.panelClosed()
        runs.panelOpened()
        var partsAtOpen: String?

        sheet.open(waits: true) { partsAtOpen = sheet.panel?.parts.first?.title }

        XCTAssertEqual(partsAtOpen, "Go")
        XCTAssertEqual(sheet.list.shown.map(\.run), ["a"])
        XCTAssertEqual(log(), ["read"])
    }

    func testASheetWithNothingToTypeReadsAgainAfterFiveSecondsAndKeepsItsPartsMeanwhile() async throws {
        try script(header: "read=sheet", "sleep 0.2\nprintf 'text=bar\\ntitle=Go\\n\\nrow=a\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the parts") { sheet.panel != nil && !sheet.isReading }
        runs.panelClosed()
        runs.panelOpened()
        time += 5

        sheet.open {}

        XCTAssertEqual(sheet.panel?.parts.first?.title, "Go")
        XCTAssertTrue(sheet.isReading)
        try await wait("the second read") { self.log().count == 2 && !sheet.isReading }
        XCTAssertEqual(sheet.panel?.parts.first?.title, "Go")
    }

    func testASheetWithAFieldDropsWhatWasTypedWhenThePanelClosesAndReadsAgain() async throws {
        try script(header: "read=sheet", "printf 'field=note\\nvalue=\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the field") { sheet.panel != nil && !sheet.isReading }
        sheet.set(try XCTUnwrap(sheet.panel?.parts.first), to: "typed")
        runs.panelClosed()
        runs.panelOpened()

        XCTAssertNil(sheet.panel)
        sheet.open {}

        try await wait("the second read") { self.log().filter { $0 == "read" }.count == 2 && sheet.panel != nil }
        XCTAssertEqual(sheet.panel?.parts.first?.value, "")
    }

    func testATimerReadAlwaysRuns() async throws {
        menuBar.insert("fast")
        try script("fast", header: "every=1", "printf 'title=1\\n'")
        _ = try scanned()
        try await wait("the first read") { self.log().count == 1 }
        try await pause(0.1)

        time += 1
        runs.raise(.clock)

        try await wait("the second read") { self.log().count == 2 }
    }

    func testAWakeReadsAWantedScriptWithANumberAtOnceAsATimerRead() async throws {
        menuBar.insert("script")
        try script(header: "every=600", "echo \"$OPENSPOT_REASON\" >> '\(path("reasons"))'\nprintf 'text=a\\ntitle=A\\n'")
        try script("idle", header: "every=600", log: "idle", "printf 'text=b\\ntitle=B\\n'")
        _ = try scanned()
        try await wait("the first read") { self.log("reasons") == ["timer"] && !self.runs.isReading }

        time += 10
        runs.woke()

        try await wait("the wake read") { self.log("reasons") == ["timer", "timer"] }
        try await pause(0.1)
        XCTAssertEqual(log("idle"), [])
    }

    func testANumberInReadReadsAnOpenSheetOnItsTimerWithAYoungAnswer() async throws {
        try script(header: "every=1", "printf 'text=a\\ntitle=A\\n'")
        let sheet = try sheet()
        try await pause(0.1)
        XCTAssertEqual(log(), [])

        runs.panelOpened()
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
        menuBar.insert("fast")
        try script("fast", header: "every=5", log: "fast", "printf 'title=1\\n'")
        menuBar.insert("slow")
        try script("slow", header: "every=60", log: "slow", "printf 'title=1\\n'")
        _ = try scanned()
        try await wait("the first reads") { self.log("fast").count == 1 && self.log("slow").count == 1 }

        time += 4
        runs.raise(.clock)
        try await pause(0.1)
        XCTAssertEqual(log("fast").count, 1)

        time += 1
        runs.raise(.clock)
        try await wait("the next read") { self.log("fast").count == 2 }
        XCTAssertEqual(log("slow").count, 1)
    }

    func testATimerReadIsWantedByTheMenuBarAlwaysAndByAWidgetWithThePanelOpen() async throws {
        menuBar.insert("tray")
        try script("tray", header: "every=5", log: "tray", "printf 'title=1\\n'")
        try script("placed", header: "every=5", log: "placed", "printf 'title=1\\n'")
        try script("idle", header: "every=5", log: "idle", "printf 'title=1\\n'")
        try "[[widgets]]\ntitle = \"W\"\ngrid = [\"placed\"]\nsize = \"square\"\n".write(to: folder.appendingPathComponent("w.toml"), atomically: true, encoding: .utf8)

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
        try script(header: "read=sheet", "sleep 0.2\nprintf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()

        sheet.read()
        sheet.read(need: .change)

        try await wait("two reads") { self.log() == ["read", "read"] }
    }

    func testOneSlowScriptDoesNotDelayAnother() async throws {
        try script("slow", header: "read=panel\noffers=search", "\(untilRelease)\nprintf 'row=s\\ntitle=S\\n'")
        try script("fast", header: "read=panel\noffers=search", "printf 'row=f\\ntitle=F\\n'")
        _ = try scanned()

        runs.panelOpened()

        let fast = try XCTUnwrap(runs.sheets["fast"])
        try await wait("the fast answer") { fast.list.shown.count == 1 }
        XCTAssertEqual(runs.sheets["slow"]?.list.shown.count, 0)
    }

    func testASpotShowsItsHeaderUntilItsAnswerArrives() async throws {
        try script(header: "read=panel\ndetail=Header", "sleep 0.2\nprintf 'switch=power\\ndetail=Answer\\nvalue=true\\n'")
        let sheet = try sheet()

        runs.panelOpened()
        XCTAssertEqual(sheet.state.subtitle, "Header")
        XCTAssertEqual(sheet.spot.kind, .launch)

        try await wait("the answer") { sheet.state.subtitle == "Answer" }
        XCTAssertEqual(sheet.spot.kind, .toggle)
    }

    func testAKindThatARunTaughtStaysAfterANewScan() async throws {
        try script(header: "read=panel", "printf 'switch=power\\nvalue=true\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the kind") { sheet.spot.kind == .toggle }

        _ = try scanned()

        XCTAssertEqual(sheet.spot.kind, .toggle)
        XCTAssertEqual(sheet.state.on, true)
    }

    func testAPressBeforeTheFirstAnswerWaitsForIt() async throws {
        try script(header: "read=panel", "sleep 0.2\nprintf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()
        XCTAssertTrue(sheet.awaitsAnswer)
        var kind: SpotKind?

        sheet.afterAnswer { kind = sheet.spot.kind }

        try await wait("the answer") { kind != nil }
        XCTAssertEqual(kind, .list)
        XCTAssertFalse(sheet.awaitsAnswer)
    }

    func testACallWithNoFrameReadsOnce() async throws {
        try script(header: "read=panel", "[ \"$1\" = read ] && printf 'switch=power\\nvalue=false\\n'\nexit 0")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the kind") { sheet.spot.kind == .toggle }

        sheet.pressCard()

        try await wait("the read after the call") { self.log() == ["read", "power true", "read"] }
        try await pause(0.1)
        XCTAssertEqual(self.log().count, 3)
    }

    func testACallWithOnlyAToastReadsOnce() async throws {
        try script(header: "read=sheet", "[ \"$1\" = read ] && printf 'row=a\\ntitle=A\\n'\n[ \"$1\" = open ] && printf 'toast=Done\\n'\nexit 0")
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
        try script(header: "read=panel", "[ \"$1\" = read ] && printf 'switch=power\\nvalue=false\\n'\n[ \"$1\" = power ] && printf 'switch=power\\nvalue=true\\n'\nexit 0")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the kind") { sheet.spot.kind == .toggle }

        sheet.pressCard()
        try await wait("the call") { self.log() == ["read", "power true"] }
        try await pause(0.15)

        XCTAssertEqual(log(), ["read", "power true"])
        XCTAssertEqual(sheet.state.on, true)
    }

    func testAScriptWithNoReadIsNotReadAfterACall() async throws {
        try script()
        let sheet = try sheet()

        sheet.pressCard()
        try await wait("the call") { self.log() == ["open"] }
        try await pause(0.1)

        XCTAssertEqual(log(), ["open"])
    }
}
