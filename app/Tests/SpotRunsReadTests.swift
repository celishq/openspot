import XCTest
@testable import OpenspotCore

@MainActor
final class SpotRunsReadTests: SpotRunsCase {
    func testAnOpenAtLaunchWaitsForEachReadAndServesTheNextOpen() async throws {
        try script(toml: "on = ['panel.open']", "echo run >> '\(path("runs"))'\nsleep 0.1\nprintf 'frame=\\ntitle=Read\\n'")
        let sheet = try sheet()

        runs.panelOpened()
        XCTAssertTrue(runs.isShowing)
        try await wait("the answer") { !self.runs.isShowing }
        runs.panelClosed()
        runs.panelOpened()
        try await pause(0.1)

        XCTAssertEqual(sheet.state.title, "Read")
        XCTAssertEqual(try String(contentsOfFile: path("runs"), encoding: .utf8), "run\n")
    }

    func testAnOpenAfterAQuitStartsNoRead() throws {
        try script(toml: "on = ['panel.open']", "printf 'frame=\\ntitle=Read\\n'")
        _ = try sheet()

        runs.quit()
        runs.panelOpened()

        XCTAssertFalse(runs.isShowing)
    }

    func testAReadThatAnswersWithItsHeadAtItsEndIsReadingUntilTheAnswerIsIn() async throws {
        try script(toml: "on = ['panel.open']", "printf 'frame=\\ntitle=Read\\n'")
        let sheet = try sheet()

        runs.panelOpened()
        let limit = ContinuousClock.now + .seconds(60)
        while runs.isShowing, ContinuousClock.now < limit { await Task.yield() }

        XCTAssertFalse(runs.isShowing)
        XCTAssertEqual(sheet.state.title, "Read")
    }

    func testEachCallKnowsTheIDOfItsSpot() async throws {
        try script("coffee", toml: "", "printf 'item=%s\\n' \"$OPENSPOT_ID\"")
        let command = try XCTUnwrap(try scanned().spots.first { $0.id == "coffee" })

        let items = try await command.items(timeout: 60).items

        XCTAssertEqual(items.map(\.run), ["coffee"])
    }

    func testALaterFrameOfAReadWithABlockReplacesItsValue() async throws {
        try script(toml: "", "printf 'frame=\\nmain=m\\n\\ntext=m\\ntitle=3\\n---\\n'\nsleep 0.05\nprintf 'frame=\\n\\ntext=b\\ntitle=B\\n---\\n'")
        let sheet = try sheet()
        let frames = FrameLog(sheet)

        runs.panelOpened()
        sheet.open {}

        try await wait("the later frame") { frames.last?.contains("B") == true }
        XCTAssertEqual(sheet.reading.value?.title, "B")
    }

    func testALaterFrameWithARootReplacesThePartsOfTheRead() async throws {
        try script(toml: "", "printf 'frame=\\nclass=gap-part\\ntitle=S\\n\\ntext=a\\ntitle=A\\n\\ntext=b\\ntitle=B\\n---\\n'\nsleep 0.05\nprintf 'frame=\\nclass=gap-part\\ntitle=S\\n\\ntext=a\\ntitle=A2\\n---\\n'")
        let sheet = try sheet()
        let frames = FrameLog(sheet)

        runs.panelOpened()
        sheet.open {}

        try await wait("the later frame") { frames.frames.count == 2 }
        XCTAssertEqual(sheet.panel?.parts.map(\.id), ["a"])
        XCTAssertEqual(sheet.panel?.parts.first?.title, "A2")
    }

    func testALaterFrameOfOnlyAHeadKeepsTheList() async throws {
        try script(toml: "", "printf 'frame=\\ntitle=L\\n\\nitem=a\\ntitle=A\\n---\\n'\nsleep 0.05\nprintf 'frame=\\ntitle=L\\n---\\n'")
        let sheet = try sheet()
        let frames = FrameLog(sheet)

        runs.panelOpened()
        sheet.open {}

        try await wait("the later frame") { frames.frames.count == 2 }
        XCTAssertEqual(sheet.list.shown.map(\.run), ["a"])
    }

    func testALaterFrameWithNoRootChangesOnlyThePartsItPrints() async throws {
        try script(toml: "", "printf 'frame=\\nclass=gap-part\\ntitle=S\\n\\ntext=a\\ntitle=A\\n\\ntext=b\\ntitle=B\\n---\\n'\nsleep 0.05\nprintf 'text=a\\ntitle=A2\\n---\\n'")
        let sheet = try sheet()
        let frames = FrameLog(sheet)

        runs.panelOpened()
        sheet.open {}

        try await wait("the later frame") { frames.frames.count == 2 }
        XCTAssertEqual(sheet.panel?.parts.map(\.id), ["a", "b"])
        XCTAssertEqual(sheet.panel?.parts.first?.title, "A2")
    }

    func testABigFrameAndASmallFrameAfterItShowInTheirOrder() async throws {
        try script(toml: "", """
        i=0
        while [ $i -lt 3000 ]; do printf 'item=r%s\\ntitle=Row number %s\\n\\n' $i $i; i=$((i+1)); done
        printf -- '---\\nframe=\\n\\nitem=last\\ntitle=Last\\n---\\n'
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
        try script(toml: "on = ['panel.open', 'sheet.open']", "\(TestSpot.event)\necho \"$ev\" >> '\(path("reasons"))'\nprintf 'text=a\\ntitle=A\\n'")
        let sheet = try sheet()
        var expected: [String] = []
        func step(_ reason: String, _ act: () -> Void) async throws {
            time += 10
            act()
            expected.append(reason)
            try await wait("the \(reason) read") { self.log("reasons") == expected }
            try await wait("the end of the \(reason) read") { !self.runs.isShowing }
        }

        try await step("panel.open") { runs.panelOpened() }
        try await step("sheet.open") { sheet.open(onReady: {}) }
        try await step("spot.change") { sheet.show(need: .change) }
    }

    func testAReadOnItsClockSaysSo() async throws {
        try script(toml: "on = ['clock.60']", "\(TestSpot.event)\necho \"$ev\" >> '\(path("reasons"))'\nprintf 'frame=\\ntitle=1\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open(onReady: {})
        try await wait("the sheet read") { self.log("reasons") == ["sheet.open"] && !self.runs.isShowing }

        time += 61
        runs.raise(.clock)

        try await wait("the timer read") { self.log("reasons") == ["sheet.open", "clock.60"] }
    }

    func testAReadOfTheSearchSaysSo() async throws {
        try script(toml: "on = ['sheet.open', 'sheet.text']", "\(TestSpot.event)\necho \"$ev $*\" >> '\(path("reasons"))'\nprintf 'text=a\\ntitle=A\\n'")
        let sheet = try sheet()

        sheet.open(onReady: {})
        try await wait("the first read") { self.log("reasons") == ["sheet.open show"] }
        sheet.search("k")

        try await wait("the search read") { self.log("reasons") == ["sheet.open show", "sheet.text show"] }
    }

    func testAReadOfTheSearchSendsTheFieldsOfTheSheetWithTheText() async throws {
        try script(toml: "on = ['sheet.open', 'sheet.text']", "\(TestSpot.event)\n[ \"$ev\" = sheet.text ] && printf '%s\\n' \"$in\" >> '\(path("stdin"))'\nprintf 'frame=\\nclass=gap-part\\n\\nfield=note\\nvalue=hello\\n'")
        let sheet = try sheet()
        sheet.open(onReady: {})
        try await wait("the sheet") { sheet.panel?.inputs == [.init(key: "note", value: "hello")] }

        sheet.search("k")

        try await wait("the search read") { self.log("stdin").contains("search=k") }
        XCTAssertEqual(log("stdin"), ["event=sheet.text", "event.value=k", "input.note=hello", "search=k"])
    }

    func testAnOpenAtLaunchRunsNoScriptThatReadsOnlyAtItsSheet() async throws {
        try script(toml: "", "echo run >> '\(path("runs"))'")
        _ = try sheet()

        runs.panelOpened()
        try await pause(0.1)

        XCTAssertFalse(runs.isShowing)
        XCTAssertFalse(exists("runs"))
    }

    func testEachScriptHasOneSheet() throws {
        try script("cups", toml: "on = ['clock.30']")
        try script("tool", toml: "")
        try script("once")

        let scan = try scanned()

        XCTAssertEqual(Set(runs.sheets.keys), ["cups", "tool", "once"])
        XCTAssertEqual(Set(scan.spots.map(\.id)), ["cups", "tool", "once"])
        XCTAssertEqual(scan.spots.first { $0.id == "cups" }?.headerState.isOnGrid, false)
    }

    func testASheetReportsItsFrameAndKeepsItsRowsPartsAndValue() async throws {
        try script(toml: "", "printf 'frame=\\nclass=gap-part\\n\\ntext=m\\ntitle=3\\ntone=good\\nclass=bar:flex\\n\\nitems=list\\n\\nitem=a\\nparent=list\\ntitle=A\\n\\ntext=b\\ntitle=B\\n'")
        let sheet = try sheet()
        let frames = FrameLog(sheet)

        sheet.open {}

        try await wait("the answer") { sheet.list.shown.count == 1 }
        XCTAssertEqual(frames.last, "frame=\nclass=gap-part\n\ntext=m\ntitle=3\ntone=good\nclass=bar:flex\n\nitems=list\n\nitem=a\nparent=list\ntitle=A\n\ntext=b\ntitle=B\n")
        XCTAssertEqual(sheet.panel?.parts.map(\.id), ["m", "b"])
        XCTAssertEqual(sheet.reading.value?.title, "3")
        XCTAssertEqual(sheet.reading.value?.tone, .good)
        XCTAssertTrue(sheet.isOpen)
    }

    func testAScriptThatLeavesTheFolderLosesItsSheetAndItsRead() async throws {
        let url = try script(toml: "", "sleep 0.2\ntouch '\(path("went-on"))'")
        let sheet = try sheet()
        sheet.show()

        try FileManager.default.removeItem(at: url)
        _ = try scanned()
        try await pause(0.35)

        XCTAssertNil(runs.sheets["script"])
        XCTAssertFalse(exists("went-on"))
    }

    func testARequestJoinsTheReadThatRuns() async throws {
        try script(toml: "", "sleep 0.2\nprintf 'item=a\\ntitle=A\\n'")
        let sheet = try sheet()

        sheet.show()
        sheet.show()
        sheet.show()

        try await wait("the row") { sheet.list.shown.count == 1 }
        XCTAssertEqual(log(), ["show"])
    }

    func testAPanelOpenAndASheetOpenWithinFiveSecondsRunOnce() async throws {
        try script(toml: "on = ['panel.open']\noffers = ['search']", "printf 'item=a\\ntitle=A\\n'")
        let sheet = try sheet()

        runs.panelOpened()
        try await wait("the row") { sheet.list.shown.count == 1 && !self.runs.isShowing }
        sheet.open {}
        time += 4
        sheet.close()
        sheet.open {}
        try await pause(0.15)

        XCTAssertEqual(log(), ["show"])
    }

    func testASheetOpenThatTheSpotListsReadsAfterAYoungPanelAnswer() async throws {
        try script(toml: "on = ['panel.open', 'sheet.open']", "\(TestSpot.event)\necho \"$ev\" >> '\(path("reasons"))'\nprintf 'item=a\\ntitle=A\\n'")
        let sheet = try sheet()

        runs.panelOpened()
        try await wait("the row") { sheet.list.shown.count == 1 }
        sheet.open {}

        try await wait("the sheet read") { self.log("reasons") == ["panel.open", "sheet.open"] }
    }

    func testASheetOpenBetweenTheFrameOfAPanelReadAndItsEndReadsAsTheSheetOpen() async throws {
        try script(toml: "on = ['panel.open', 'sheet.open']", "\(TestSpot.event)\necho \"$ev\" >> '\(path("reasons"))'\nprintf 'item=a\\ntitle=A\\n---\\n'\n\(untilRelease)")
        let sheet = try sheet()

        runs.panelOpened()
        try await wait("the row") { sheet.list.shown.count == 1 }
        sheet.open {}
        openGate()

        try await wait("the sheet read", seconds: 20) { self.log("reasons") == ["panel.open", "sheet.open"] }
    }

    func testASheetOpenThatTheSpotListsDuringAPanelReadReadsAgain() async throws {
        try script(toml: "on = ['panel.open', 'sheet.open']", "sleep 0.2\n\(TestSpot.event)\necho \"$ev\" >> '\(path("reasons"))'\nprintf 'text=a\\ntitle=A\\n'")
        let sheet = try sheet()

        runs.panelOpened()
        sheet.open {}

        try await wait("the second read") { self.log("reasons").count == 2 }
        XCTAssertEqual(log("reasons").first, "panel.open")
    }

    func testAPanelOpenAndASheetOpenAtOnceRunOnce() async throws {
        try script(toml: "on = ['panel.open']", "sleep 0.2\nprintf 'frame=\\ndetail=Off\\n\\nitem=a\\ntitle=A\\n'")
        let sheet = try sheet()

        runs.panelOpened()
        sheet.open {}

        try await wait("the row") { sheet.list.shown.count == 1 }
        XCTAssertEqual(log(), ["show"])
    }

    func testAnAnswerOlderThanFiveSecondsIsReadAgain() async throws {
        try script(toml: "", "printf 'item=a\\ntitle=A\\n'")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 && !self.runs.isShowing }
        sheet.close()

        time += 5
        sheet.open {}

        try await wait("the second read") { self.log().count == 2 }
    }

    func testASheetWithNothingToTypeOpensAfterAPanelCloseWithItsPartsAtOnce() async throws {
        try script(toml: "", "printf 'frame=\\nclass=gap-part\\n\\ntext=bar\\ntitle=Go\\n\\nitems=list\\n\\nitem=a\\nparent=list\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the parts") { sheet.panel != nil && !sheet.isShowing }
        runs.panelClosed()
        runs.panelOpened()
        var partsAtOpen: String?

        sheet.open(waits: true) { partsAtOpen = sheet.panel?.parts.first?.title }

        XCTAssertEqual(partsAtOpen, "Go")
        XCTAssertEqual(sheet.list.shown.map(\.run), ["a"])
        XCTAssertEqual(log(), ["show"])
    }

    func testASheetWithNothingToTypeReadsAgainAfterFiveSecondsAndKeepsItsPartsMeanwhile() async throws {
        try script(toml: "", "sleep 0.2\nprintf 'frame=\\nclass=gap-part\\n\\ntext=bar\\ntitle=Go\\n\\nitems=list\\n\\ntext=a\\nparent=list\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the parts") { sheet.panel != nil && !sheet.isShowing }
        runs.panelClosed()
        runs.panelOpened()
        time += 5

        sheet.open {}

        XCTAssertEqual(sheet.panel?.parts.first?.title, "Go")
        XCTAssertTrue(sheet.isShowing)
        try await wait("the second read") { self.log().count == 2 && !sheet.isShowing }
        XCTAssertEqual(sheet.panel?.parts.first?.title, "Go")
    }

    func testASheetWithAFieldDropsWhatWasTypedWhenThePanelClosesAndReadsAgain() async throws {
        try script(toml: "", "printf 'frame=\\nclass=gap-part\\n\\nfield=note\\nvalue=\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the field") { sheet.panel != nil && !sheet.isShowing }
        sheet.set(try XCTUnwrap(sheet.panel?.parts.first), to: "typed")
        runs.panelClosed()
        runs.panelOpened()

        XCTAssertNil(sheet.panel)
        sheet.open {}

        try await wait("the second read") { self.log().filter { $0 == "show" }.count == 2 && sheet.panel != nil }
        XCTAssertEqual(sheet.panel?.parts.first?.value, "")
    }

    func testAViewSendsAValueToItsSpotWithItsID() async throws {
        try script(toml: "views = ['steps.swift']", "printf 'frame=\\nclass=gap-part\\n\\nsteps=steps\\n'")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the view") { sheet.panel != nil && !sheet.isShowing }

        sheet.set(try XCTUnwrap(sheet.panel?.parts.first { $0.kind == "steps" }), to: "pick 4 ecology")

        try await wait("the call") { self.log().contains("steps pick 4 ecology") }
    }

    func testATimerReadAlwaysRuns() async throws {
        menuBar.insert("fast")
        try script("fast", toml: "on = ['clock.1']", "printf 'frame=\\ntitle=1\\n'")
        _ = try scanned()
        try await wait("the first read") { self.log().count == 1 && !self.runs.isShowing }
        try await pause(0.1)

        time += 1
        runs.raise(.clock)

        try await wait("the second read") { self.log().count == 2 }
    }

    func testAWakeReadsAWantedScriptWithANumberAtOnceAsATimerRead() async throws {
        menuBar.insert("script")
        try script(toml: "on = ['clock.600']", "\(TestSpot.event)\necho \"$ev\" >> '\(path("reasons"))'\nprintf 'text=a\\ntitle=A\\n'")
        try script("idle", toml: "on = ['clock.600']", log: "idle", "printf 'text=b\\ntitle=B\\n'")
        _ = try scanned()
        try await wait("the first read") { self.log("reasons") == ["clock.600"] && !self.runs.isShowing }

        time += 10
        runs.woke()

        try await wait("the wake read") { self.log("reasons") == ["clock.600", "clock.600"] }
        try await pause(0.1)
        XCTAssertEqual(log("idle"), [])
    }

    func testANumberInReadReadsAnOpenSheetOnItsTimerWithAYoungAnswer() async throws {
        try script(toml: "on = ['clock.1']", "printf 'frame=\\nclass=gap-part\\n\\ntext=a\\ntitle=A\\n'")
        let sheet = try sheet()
        try await pause(0.1)
        XCTAssertEqual(log(), [])

        runs.panelOpened()
        sheet.open {}
        try await wait("the first read") { sheet.panel != nil && sheet.calls.isEmpty }
        XCTAssertEqual(log(), ["show"])

        time += 1
        try await wait("the read from the timer") { self.log() == ["show", "show"] }

        sheet.close()
        time += 1
        try await pause(0.1)
        XCTAssertEqual(log(), ["show", "show"])
    }

    func testAScriptThatPrintsEveryIsNotReadAgain() async throws {
        try script(toml: "", "printf 'on=clock.1\\n\\nframe=\\nclass=gap-part\\n\\ntext=a\\ntitle=A\\n'")
        let sheet = try sheet()

        sheet.open {}
        try await wait("the part") { sheet.panel != nil }
        try await pause(0.1)

        XCTAssertEqual(log(), ["show"])
        sheet.close()
    }

    func testEachScriptIsReadWhenItsTimePasses() async throws {
        menuBar.insert("fast")
        try script("fast", toml: "on = ['clock.5']", log: "fast", "printf 'frame=\\ntitle=1\\n'")
        menuBar.insert("slow")
        try script("slow", toml: "on = ['clock.60']", log: "slow", "printf 'frame=\\ntitle=1\\n'")
        _ = try scanned()
        try await wait("the first reads") { self.log("fast").count == 1 && self.log("slow").count == 1 && !self.runs.isShowing }

        time += 4
        runs.raise(.clock)
        try await pause(0.1)
        XCTAssertEqual(log("fast").count, 1)

        time += 1
        runs.raise(.clock)
        try await wait("the next read") { self.log("fast").count == 2 }
        XCTAssertEqual(log("slow").count, 1)
    }

    func testATimerReadIsWantedByTheMenuBarAlwaysAndByACardOnTheGridWithThePanelOpen() async throws {
        menuBar.insert("tray")
        try script("tray", toml: "on = ['clock.5']", log: "tray", "printf 'frame=\\ntitle=1\\n'")
        try script("placed", toml: "on = ['clock.5']", log: "placed", "printf 'frame=\\ntitle=1\\n'")
        try script("idle", toml: "on = ['clock.5']", log: "idle", "printf 'frame=\\ntitle=1\\n'")

        _ = try scanned()
        runs.take(grid: ["placed"])
        try await wait("the tray read") { self.log("tray").count == 1 }
        XCTAssertEqual(log("placed"), [])

        runs.panelOpened()
        try await wait("the placed read") { self.log("placed").count == 1 }
        XCTAssertEqual(log("idle"), [])
    }

    func testAnOpenPanelReadsEachCardOnTheGridOnceAtItsEventOrWithSpotWant() async throws {
        try script("sheeted", toml: "", log: "sheeted", "\(TestSpot.event)\necho \"$ev\" >> '\(path("reasons"))'\nprintf 'frame=\\ntitle=1\\n'")
        try script("paneled", toml: "on = ['panel.open']", log: "paneled", "\(TestSpot.event)\necho \"$ev\" >> '\(path("reasons"))'\nprintf 'frame=\\ntitle=1\\n'")
        try script("evented", toml: "on = ['device.connect']", log: "evented", "\(TestSpot.event)\necho \"$ev\" >> '\(path("reasons"))'\nprintf 'frame=\\ntitle=1\\n'")
        _ = try scanned()
        runs.take(grid: ["sheeted", "paneled", "evented"])

        runs.panelOpened()

        try await wait("the reads") { self.log("reasons").count == 2 }
        try await allEnded()
        XCTAssertEqual(log("reasons").sorted(), ["panel.open", "spot.want"])
        XCTAssertEqual(log("sheeted"), [])
    }

    func testAReadAfterAChangeOfStateUsesNoYoungAnswer() async throws {
        try script(toml: "", """
        [ "$1" = show ] && printf 'frame=\\nclass=gap-part\\n\\nbutton=go\\ntitle=Go\\nclose=false\\n'
        exit 0
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the part") { sheet.panel != nil }

        sheet.press(try XCTUnwrap(sheet.panel?.parts.first))

        try await wait("the read after the press") { self.log() == ["show", "go", "show"] }
    }

    func testAChangeDuringARunningReadReadsOnceMoreAfterIt() async throws {
        try script(toml: "", "sleep 0.2\nprintf 'text=a\\ntitle=A\\n'")
        let sheet = try sheet()

        sheet.show()
        sheet.show(need: .change)

        try await wait("two reads") { self.log() == ["show", "show"] }
    }

    func testOneSlowScriptDoesNotDelayAnother() async throws {
        try script("slow", toml: "on = ['panel.open']\noffers = ['search']", "\(untilRelease)\nprintf 'item=s\\ntitle=S\\n'")
        try script("fast", toml: "on = ['panel.open']\noffers = ['search']", "printf 'item=f\\ntitle=F\\n'")
        _ = try scanned()

        runs.panelOpened()

        let fast = try XCTUnwrap(runs.sheets["fast"])
        try await wait("the fast answer") { fast.list.shown.count == 1 }
        XCTAssertEqual(runs.sheets["slow"]?.list.shown.count, 0)
    }

    func testASpotShowsItsHeaderUntilItsAnswerArrives() async throws {
        try script(toml: "on = ['panel.open']\ndetail = 'Header'", "sleep 0.2\nprintf 'frame=\\ndetail=Answer\\n\\nswitch=power\\nclass=card:flex\\nvalue=true\\n'")
        let sheet = try sheet()

        runs.panelOpened()
        XCTAssertEqual(sheet.state.subtitle, "Header")
        XCTAssertEqual(sheet.spot.kind, .list)

        try await wait("the answer") { sheet.state.subtitle == "Answer" }
        XCTAssertEqual(sheet.spot.kind, .toggle)
    }

    func testAKindThatARunTaughtStaysAfterANewScan() async throws {
        try script(toml: "on = ['panel.open']", "printf 'switch=power\\nclass=card:flex\\nvalue=true\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the kind") { sheet.spot.kind == .toggle }

        _ = try scanned()

        XCTAssertEqual(sheet.spot.kind, .toggle)
        XCTAssertEqual(sheet.state.on, true)
    }

    func testAPressBeforeTheFirstAnswerWaitsForIt() async throws {
        try script(toml: "on = ['panel.open']", "sleep 0.2\nprintf 'text=a\\ntitle=A\\n'")
        let sheet = try sheet()
        XCTAssertTrue(sheet.awaitsAnswer)
        var kind: SpotKind?

        sheet.afterAnswer { kind = sheet.spot.kind }

        try await wait("the answer") { kind != nil }
        XCTAssertEqual(kind, .list)
        XCTAssertFalse(sheet.awaitsAnswer)
    }

    func testACallWithNoFrameReadsOnce() async throws {
        try script(toml: "on = ['panel.open']", "[ \"$1\" = show ] && printf 'switch=power\\nclass=card:flex\\nvalue=false\\n'\nexit 0")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the kind") { sheet.spot.kind == .toggle }

        sheet.pressCard()

        try await wait("the read after the call") { self.log() == ["show", "power true", "show"] }
        try await pause(0.1)
        XCTAssertEqual(self.log().count, 3)
    }

    func testACallWithOnlyAToastReadsOnce() async throws {
        takeCalls()
        try script(toml: "", "[ \"$1\" = show ] && printf 'item=a\\ntitle=A\\n'\n[ \"$1\" = open ] && \(TestSpot.toast) Done\nexit 0")
        let sheet = try sheet()
        var toasts: [String] = []
        sheet.onReport = { if case .toast(let text) = $0 { toasts.append(text) } }
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))

        try await wait("the read after the call") { self.log() == ["show", "open a", "show"] }
        XCTAssertEqual(toasts, ["Done"])
    }

    func testACallThatShowsItsStateIsNotReadAgain() async throws {
        try script(toml: "on = ['panel.open']", "[ \"$1\" = show ] && printf 'switch=power\\nclass=card:flex\\nvalue=false\\n'\n[ \"$1\" = power ] && printf 'switch=power\\nclass=card:flex\\nvalue=true\\n'\nexit 0")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the kind") { sheet.spot.kind == .toggle }

        sheet.pressCard()
        try await wait("the call") { self.log() == ["show", "power true"] }
        try await pause(0.15)

        XCTAssertEqual(log(), ["show", "power true"])
        XCTAssertEqual(sheet.state.on, true)
    }

    func testAScriptWithCommandsAndNoEventsIsNotReadAfterACall() async throws {
        try script(toml: "[commands.left]\ntitle = 'Left'")
        let sheet = try sheet()

        sheet.pressCard()
        try await wait("the call") { self.log() == ["open"] }
        try await pause(0.1)

        XCTAssertEqual(log(), ["open"])
    }

    func testAScriptWithNoCommandsAndNoEventsIsReadAfterACall() async throws {
        try script()
        let sheet = try sheet()

        sheet.pressCard()

        try await wait("the read after the call") { self.log() == ["open", "show"] }
    }
}
