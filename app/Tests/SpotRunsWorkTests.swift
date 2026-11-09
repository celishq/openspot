import XCTest
@testable import OpenspotCore

/// Proves how running work shows, what a press does while a call runs, and what a quit stops.
@MainActor
final class SpotRunsWorkTests: SpotRunsCase {
    // MARK: L6, G1 to G4

    private static let progress = "printf 'gauge=progress\\ntitle=42%%\\ndetail=2 min left\\nvalue=0.42\\n---\\n'\nsleep 30"

    /// A body that waits for a file before each of these frames.
    private func steps(_ steps: [(file: String, frame: String)]) -> String {
        steps.map { "while [ ! -e '\(path($0.file))' ]; do sleep 0.02; done\nprintf '\($0.frame)\\n---\\n'" }.joined(separator: "\n") + "\nsleep 30"
    }

    private func touch(_ name: String) {
        FileManager.default.createFile(atPath: path(name), contents: nil)
    }

    func testWorkShowsOnlyAfterItsCallHasRunForOneSecond() async throws {
        try script(body: Self.progress)
        let sheet = try sheet()

        sheet.pressCard()
        try await wait("the frame") { sheet.calls.first?.output != nil }
        time += 0.9
        XCTAssertTrue(sheet.work.isEmpty)
        XCTAssertNil(sheet.cardWork)
        XCTAssertNil(runs.workMark)
        XCTAssertNil(runs.workSpot)
        XCTAssertEqual(sheet.shownState, sheet.state)

        time += 0.1
        XCTAssertEqual(sheet.work.map(\.id), sheet.calls.map(\.id))
        XCTAssertNotNil(runs.workMark)
        XCTAssertEqual(runs.workSpot, "script")
    }

    func testKeyPressesRunInOrderAndNeverStopACall() async throws {
        try script(body: "[ \"$1\" = a ] && while [ ! -e '\(path("go"))' ]; do sleep 0.02; done")
        let sheet = try sheet()

        sheet.pressKey("a")
        sheet.pressKey("a")
        sheet.pressKey("b")
        try await wait("the first call") { self.log() == ["a"] }
        time += 2
        sheet.pressKey("a")
        try await pause(0.1)
        XCTAssertEqual(log(), ["a"])

        touch("go")
        try await wait("each press") { self.log() == ["a", "a", "b", "a"] }
    }

    func testAQuickCallNeverShows() async throws {
        try script(body: "exit 0")
        let sheet = try sheet()

        sheet.pressCard()
        try await wait("the end") { sheet.calls.isEmpty }
        time += 5

        XCTAssertTrue(sheet.work.isEmpty)
        XCTAssertNil(runs.workMark)
    }

    func testAReadNeverShowsAsWork() async throws {
        try script(header: "read=sheet", "sleep 30")
        let sheet = try sheet()

        sheet.read()
        time += 5

        XCTAssertEqual(sheet.calls.count, 1)
        XCTAssertTrue(sheet.work.isEmpty)
        XCTAssertNil(runs.workMark)
        XCTAssertNil(runs.workSpot)
    }

    func testACallToAStayingScriptNeverShowsAsWorkAndItsFrameDoesNotMakeItShow() async throws {
        try staying(frame: "gauge=p\\ntitle=42%%\\nvalue=0.42\\n")
        let sheet = try sheet()
        let frames = FrameLog(sheet)
        runs.panelOpened()
        sheet.open {}
        try await wait("the frame") { self.blocks() == ["arg=read"] && frames.last != nil }
        let before = sheet.state

        sheet.pick(SpotItem(title: "A", run: "a"))
        try await wait("the call") { self.blocks() == ["arg=read", "arg=open\narg=a"] }
        time += 5

        XCTAssertTrue(sheet.calls.isEmpty)
        XCTAssertTrue(sheet.work.isEmpty)
        XCTAssertNil(runs.workMark)
        XCTAssertNil(runs.workSpot)
        XCTAssertEqual(sheet.shownState, before)
    }

    func testWorkShowsByItselfOnceItsSecondHasPassed() async throws {
        let live = SpotRuns()
        defer { live.quit() }
        try script(body: "sleep 30")
        live.take(try PluginFolder(url: folder).scan())
        let sheet = try XCTUnwrap(live.sheets["script"])
        sheet.pressCard()
        let changes = expectation(description: "the second has passed")

        XCTAssertNil(withObservationTracking { live.workMark } onChange: { changes.fulfill() })
        await fulfillment(of: [changes], timeout: 5)

        XCTAssertNotNil(live.workMark)
    }

    func testTheSpotShowsASpinnerWithNoValueAndARingFromValue() async throws {
        try script(body: steps([
            ("half", "gauge=progress\\nvalue=0.42"),
            ("over", "gauge=progress\\nvalue=7"),
            ("under", "gauge=progress\\nvalue=-1"),
            ("none", "gauge=progress\\ntitle=Almost")
        ]))
        let sheet = try sheet()
        sheet.pressCard()
        time += 1
        let call = try XCTUnwrap(sheet.work.first)
        XCTAssertNil(call.fill)

        touch("half")
        try await wait("the value") { call.fill == 0.42 }
        touch("over")
        try await wait("the top") { call.fill == 1 }
        touch("under")
        try await wait("the bottom") { call.fill == 0 }
        touch("none")
        try await wait("no value") { call.title == "Almost" }
        XCTAssertNil(call.fill)
    }

    func testAFramesWordsShowOnTheSpotOnlyWhileItsCallRuns() async throws {
        try script(header: "title=Encode\ndetail=Videos", "printf 'gauge=progress\\ntitle=42%%\\ndetail=2 min left\\n---\\n'\nwhile [ ! -e '\(path("end"))' ]; do sleep 0.02; done")
        let sheet = try sheet()
        sheet.pressCard()
        try await wait("the frame") { sheet.calls.first?.output != nil }
        XCTAssertEqual(sheet.shownState.title, "Encode")

        time += 1
        XCTAssertEqual(sheet.shownState.title, "42%")
        XCTAssertEqual(sheet.shownState.subtitle, "2 min left")
        XCTAssertEqual(sheet.state.title, "Encode")
        XCTAssertEqual(sheet.state.subtitle, "Videos")

        touch("end")
        try await wait("the end") { sheet.calls.isEmpty }
        XCTAssertEqual(sheet.shownState.title, "Encode")
        XCTAssertEqual(sheet.shownState.subtitle, "Videos")
    }

    func testAFrameWithOnlyATitleKeepsTheDetailOfTheSpot() async throws {
        try script(header: "title=Encode\ndetail=Videos", "printf 'gauge=progress\\ntitle=42%%\\n---\\n'\nsleep 30")
        let sheet = try sheet()
        sheet.pressCard()
        try await wait("the frame") { sheet.calls.first?.output != nil }
        time += 1

        XCTAssertEqual(sheet.shownState.title, "42%")
        XCTAssertEqual(sheet.shownState.subtitle, "Videos")
    }

    func testAStoppedCallLeavesNothingOnTheSpotOrInTheMenuBar() async throws {
        try script(header: "title=Encode", Self.progress)
        let sheet = try sheet()
        sheet.pressCard()
        try await wait("the frame") { sheet.calls.first?.output != nil }
        time += 1
        XCTAssertEqual(sheet.shownState.title, "42%")

        sheet.pressCard()

        XCTAssertTrue(sheet.work.isEmpty)
        XCTAssertEqual(sheet.shownState.title, "Encode")
        XCTAssertNil(sheet.shownState.subtitle)
        XCTAssertNil(runs.workMark)
        XCTAssertNil(runs.workSpot)
        try await pause()
        XCTAssertEqual(log(), ["run"])
    }

    func testTheMenuBarShowsTheOldestCallOfAllScriptsAndHowManyRun() async throws {
        try script("a", "sleep 30")
        try script("z", "printf 'gauge=progress\\nvalue=0.25\\n---\\n'\nsleep 30")
        _ = try scanned()
        let a = try XCTUnwrap(runs.sheets["a"])
        let z = try XCTUnwrap(runs.sheets["z"])

        z.pressCard()
        try await wait("the frame") { z.calls.first?.output != nil }
        time += 1
        a.pressCard()
        XCTAssertEqual(runs.workMark?.content, .work(fill: 0.25, count: nil))
        XCTAssertEqual(runs.workSpot, "z")

        time += 1
        XCTAssertEqual(runs.workMark?.content, .work(fill: 0.25, count: 2))
        XCTAssertEqual(runs.workSpot, "z")

        z.stop(try XCTUnwrap(z.calls.first))
        XCTAssertEqual(runs.workMark?.content, .work(fill: nil, count: nil))
        XCTAssertEqual(runs.workSpot, "a")
    }

    func testTheSpotShowsItsOldestCall() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'grid=a b\\n\\nbutton=a\\ntitle=A\\n\\nbutton=b\\ntitle=B\\n' ;;
          a) printf 'gauge=progress\\ntitle=A\\n---\\n'; sleep 30 ;;
          b) printf 'gauge=progress\\ntitle=B\\n---\\n'; sleep 30 ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the parts") { sheet.panel != nil }
        try await wait("the end of the read") { sheet.calls.isEmpty }
        let parts = try XCTUnwrap(sheet.panel?.parts)

        sheet.press(parts[1])
        time += 1
        sheet.press(parts[0])
        try await wait("both frames") { sheet.calls.count == 2 && sheet.calls.allSatisfy { $0.output != nil } }
        time += 1

        XCTAssertEqual(sheet.work.count, 2)
        XCTAssertEqual(sheet.shownState.title, "B")
    }

    func testARunningPartShowsOnThatPartOnly() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'grid=go other\\n\\nbutton=go\\ntitle=Go\\n\\ntext=other\\ntitle=Other\\n' ;;
          go) sleep 30 ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the parts") { sheet.panel != nil }
        let parts = try XCTUnwrap(sheet.panel?.parts)

        sheet.press(parts[0])
        XCTAssertNil(sheet.work(of: parts[0]))
        time += 1

        XCTAssertNotNil(sheet.work(of: parts[0]))
        XCTAssertNil(sheet.work(of: parts[1]))
        XCTAssertTrue(parts[0].isPressable)
        XCTAssertFalse(parts[1].isPressable)
        XCTAssertNil(sheet.cardWork)
    }

    func testARunningActionOrPickShowsOnItsRowOfTheMenu() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'button=go\\ntitle=Go\\nscope=command\\n\\nbutton=copy\\ntitle=Copy\\n\\nrow=a\\ntitle=A\\n' ;;
          go) sleep 30 ;;
          open) sleep 30 ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        let item = try XCTUnwrap(sheet.list.selectedItem)
        let menu = try XCTUnwrap(ActionMenu(command: sheet.command, item: item))
        let primary = try XCTUnwrap(menu.rows.first { $0.action == nil })
        let go = try XCTUnwrap(menu.rows.first { $0.action?.id == "go" })
        let copy = try XCTUnwrap(menu.rows.first { $0.action?.id == "copy" })

        sheet.run(try XCTUnwrap(go.action), item: nil)
        time += 1
        XCTAssertNotNil(sheet.work(of: go, item: nil))
        XCTAssertNil(sheet.work(of: copy, item: item))
        XCTAssertNil(sheet.work(of: primary, item: item))

        sheet.pick(item)
        time += 1
        XCTAssertNotNil(sheet.work(of: primary, item: item))
        XCTAssertNil(sheet.cardWork)
    }

    func testARunningCardSaysThatAPressStopsItAndAPressDoes() async throws {
        try script(body: "sleep 5\ntouch '\(path("went-on"))'")
        let sheet = try sheet()
        let menu = try XCTUnwrap(ActionMenu(command: sheet.command, item: nil))
        let row = try XCTUnwrap(menu.rows.first)

        sheet.pressCard()
        XCTAssertNil(sheet.cardWork)
        XCTAssertNil(sheet.work(of: row, item: nil))
        time += 1

        XCTAssertNotNil(sheet.cardWork)
        XCTAssertNotNil(sheet.work(of: row, item: nil))
        try await wait("the call") { self.log() == ["run"] }
        sheet.pressCard()
        XCTAssertNil(sheet.cardWork)
        XCTAssertFalse(sheet.isCardRunning)
        try await allEnded()
        XCTAssertFalse(exists("went-on"))
    }

    // MARK: L11

    func testAPressOfAPartWithinOneSecondOfItsStartDoesNothing() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'grid=go\\n\\nbutton=go\\ntitle=Go\\n' ;;
          go) sleep 0.2; touch '\(path("done"))' ;;
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
          read) printf 'button=go\\ntitle=Go\\nscope=command\\n\\nrow=a\\ntitle=A\\n' ;;
          go) sleep 0.2; touch '\(path("action"))' ;;
          open) sleep 0.2; touch '\(path("pick"))' ;;
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
        try script(header: "read=panel", "[ \"$1\" = read ] && { printf 'switch=power\\non=false\\n'; exit 0; }\nsleep 0.3\ntouch '\(path("done"))'\nprintf 'switch=power\\non=true\\n'")
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
          read) printf 'button=new\\ntitle=New\\nscope=command\\nform=true\\n\\nrow=a\\ntitle=A\\n' ;;
          new) \(untilRelease); printf 'title=New\\n\\nfield=a\\ntitle=A\\n' ;;
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
        openGate()
        let form = try await first
        XCTAssertEqual(form?.fields.map(\.name), ["a"])
    }

    func testAPickAsksWithAFormAndASubmitCanAnswerWithTheFormAgain() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'button=open\\ntitle=Open\\nform=true\\n\\nrow=a\\ntitle=A\\n' ;;
          open) case "$(cat)" in *name=x*) ;; *) printf 'title=Name\\n\\nfield=name\\ntitle=Name\\n' ;; esac ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the read") { sheet.command.pickForm != nil }
        let action = try XCTUnwrap(sheet.command.pickForm)
        let item = SpotItem(title: "A", run: "a")

        let asked = try await sheet.form(action, item: item)
        let form = try XCTUnwrap(asked)
        var draft = FormDraft(form: form)
        draft.set("y", for: "name")
        let again = try await sheet.submit(action, item: item, draft: draft)
        draft.set("x", for: "name")
        let done = try await sheet.submit(action, item: item, draft: draft)

        XCTAssertEqual(form.fields.map(\.name), ["name"])
        XCTAssertEqual(again, .form(form))
        XCTAssertEqual(done, .done)
    }

    func testAChangeAnswersWithTheFormOfItsScriptOrIsDone() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'row=a\\ntitle=A\\n' ;;
          editor) printf 'title=Editor\\n\\nchoice=editor\\ntitle=Editor\\noption=zed:Zed\\n' ;;
          folder) touch "\(path("folder"))" ;;
        esac
        """)
        let sheet = try sheet()

        let asked = try await sheet.change(CommandAction(id: "editor", title: "Change editor"))
        let done = try await sheet.change(CommandAction(id: "folder", title: "Change folder"))

        guard case .form(let form)? = asked else { return XCTFail("no form: \(String(describing: asked))") }
        XCTAssertEqual(form.fields.map(\.name), ["editor"])
        XCTAssertEqual(done, .done)
        XCTAssertTrue(exists("folder"))
    }

    func testQuittingStopsEachCall() async throws {
        try script(header: "read=sheet", """
        trap 'touch "\(path("stopped"))"; exit 0' TERM
        printf 'text=a\\ntitle=A\\n---\\n'
        \(String.longLoop)
        """)
        try script("deaf", "echo $$ > '\(path("deaf-pid"))'\ntrap '' TERM\n\(String.longLoop)")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the part") { sheet.panel != nil }
        let deaf = try XCTUnwrap(runs.sheets["deaf"])
        deaf.pressCard()
        let pid = try await pid("deaf-pid")
        let started = Date()

        runs.quit()

        XCTAssertLessThan(Date().timeIntervalSince(started), 3)
        try await wait("the stop") { self.exists("stopped") }
        try await wait("the end of the deaf script") { kill(pid, 0) != 0 }
    }

    func testQuittingLeavesNoChildThatIgnoresTheTerminateSignal() async throws {
        try script(body: "sh -c \"trap '' TERM; echo \\$\\$ > '\(path("pid"))'; exec sleep 30\" >/dev/null 2>&1 &\nsleep 30")
        let sheet = try sheet()
        sheet.pressCard()
        let pid = try await pid("pid")
        let started = Date()

        runs.quit()

        XCTAssertLessThan(Date().timeIntervalSince(started), 3)
        try await wait("the end of the child") { kill(pid, 0) != 0 }
    }

    func testQuittingLeavesNoChildOfACallThatItsStopAlreadyEnded() async throws {
        try script(body: "echo $$ > '\(path("script"))'\nsh -c \"trap '' TERM; echo \\$\\$ > '\(path("pid"))'; exec sleep 30\" >/dev/null 2>&1 &\nsleep 30")
        let sheet = try sheet()
        sheet.pressCard()
        let child = try await pid("pid")
        let parent = try await pid("script")

        sheet.stop(try XCTUnwrap(sheet.calls.first))
        try await wait("the end of the script") { kill(parent, 0) != 0 }
        try await pause(0.05)
        runs.quit()

        XCTAssertNotEqual(kill(child, 0), 0)
    }

    func testQuittingMarksEachCallAsStopped() async throws {
        try script(body: "sleep 30")
        let sheet = try sheet()
        sheet.pressCard()
        let call = try XCTUnwrap(sheet.calls.first)

        runs.quit()

        XCTAssertTrue(call.isStopped)
        XCTAssertTrue(sheet.calls.isEmpty)
    }

    func testAQuitStopsAToggleAndItGoesBack() async throws {
        try script(header: "read=panel", "[ \"$1\" = read ] && printf 'switch=power\\non=false\\n'\n[ \"$1\" = power ] && sleep 30\nexit 0")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the kind") { sheet.command.kind == .toggle && sheet.calls.isEmpty }
        sheet.pressCard()
        XCTAssertEqual(sheet.state.on, true)
        try await wait("the call") { self.log() == ["read", "power true"] }

        runs.quit()
        try await pause()

        XCTAssertEqual(sheet.state.on, false)
        XCTAssertEqual(log(), ["read", "power true"])
    }

    func testAReadThatWaitsToRunAgainDoesNotRunAfterAQuit() async throws {
        try script(header: "read=sheet", "printf 'row=a\\ntitle=A\\n---\\n'\nsleep 30")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        sheet.read(need: .change)

        runs.quit()
        try await pause()

        XCTAssertEqual(log(), ["read"])
    }

    func testAQuitChangesNothingOnAStayingScriptThatFailsAsItEnds() async throws {
        try script(header: "stay=true\nread=launch", """
        while IFS= read -r line; do
          case "$line" in call=*) call=${line#call=} ;; esac
          [ -n "$line" ] || printf 'end=%s\\n\\ntext=n\\ntitle=A\\n---\\n' "$call"
        done
        exit 3
        """)
        let (sheet, told) = try toldSheet()
        runs.arrive(.launch)
        try await wait("the value") { sheet.reading.value?.title == "A" }

        runs.quit()
        try await pause()

        XCTAssertEqual(told(), [])
        XCTAssertFalse(sheet.reading.isStale)
        XCTAssertEqual(log().count, 1)
    }
}
