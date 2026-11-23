import XCTest
@testable import OpenspotCore

@MainActor
final class SpotRunsWorkTests: SpotRunsCase {
    private static let progress = "printf 'frame=\\ntitle=42%%\\ndetail=2 min left\\nprogress=0.42\\n---\\n'\nsleep 30"

    private func steps(_ steps: [(file: String, frame: String)]) -> String {
        steps.map { "while [ ! -e '\(path($0.file))' ]; do sleep 0.02; done\nprintf '\($0.frame)\\n---\\n'" }.joined(separator: "\n") + "\nsleep 30"
    }

    private func touch(_ name: String) {
        FileManager.default.createFile(atPath: path(name), contents: nil)
    }

    func testAReadTellsNoReaderOfTheWorkOfItsCard() async throws {
        try script(toml: "[on]\n\"panel.open\" = true", "printf 'frame=\\ntitle=Same\\n'")
        let sheet = try sheet()
        sheet.show(need: .change)
        try await wait("the first read") { self.log().count == 1 && sheet.calls.isEmpty }
        nonisolated(unsafe) var changed = false
        withObservationTracking { _ = sheet.acts; _ = sheet.cardAct; _ = sheet.shownState } onChange: { changed = true }

        sheet.show(need: .change)
        try await wait("the second read") { self.log().count == 2 && sheet.calls.isEmpty }

        XCTAssertFalse(changed)
    }

    func testWorkShowsOnlyAfterItsCallHasRunForOneSecond() async throws {
        try script(body: Self.progress)
        let sheet = try sheet()

        sheet.pressCard()
        try await wait("the frame") { sheet.calls.first?.status != nil }
        time += 0.9
        XCTAssertTrue(sheet.acts.isEmpty)
        XCTAssertNil(sheet.cardAct)
        XCTAssertNil(runs.runningSummary)
        XCTAssertNil(runs.actSpot)
        XCTAssertEqual(sheet.shownState, sheet.state)

        time += 0.1
        try await wait("the shown work") { !sheet.acts.isEmpty }
        XCTAssertEqual(sheet.acts.map(\.id), sheet.calls.map(\.id))
        XCTAssertNotNil(runs.runningSummary)
        XCTAssertEqual(runs.actSpot, "script")
    }

    func testKeyPressesRunInOrderAndNeverStopACall() async throws {
        try script(toml: "[actions.a]\ntitle = 'A'\n[actions.b]\ntitle = 'B'", "[ \"$1\" = a ] && while [ ! -e '\(path("go"))' ]; do sleep 0.02; done")
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

        XCTAssertTrue(sheet.acts.isEmpty)
        XCTAssertNil(runs.runningSummary)
    }

    func testAReadNeverShowsAsWork() async throws {
        try script(toml: "", "sleep 30")
        let sheet = try sheet()

        sheet.show()
        time += 5

        XCTAssertEqual(sheet.calls.count, 1)
        XCTAssertTrue(sheet.acts.isEmpty)
        XCTAssertNil(runs.runningSummary)
        XCTAssertNil(runs.actSpot)
    }

    func testACallToAStayingScriptShowsAsWorkAfterItsSecondAndLeavesItAtItsEnd() async throws {
        try script(toml: "stay = true", """
        while IFS= read -r line; do
          printf '%s\\n' "$line" >> '\(path("blocks"))'
          case "$line" in
            call=*) call=${line#call=}; name= ;;
            arg=*) [ -n "$name" ] || name=${line#arg=} ;;
            '')
              if [ "$name" != show ]; then \(untilRelease); fi
              printf 'end=%s\\n\\nnumber=p\\nvalue=42\\nmax=100\\n---\\n' "$call" ;;
          esac
        done
        """)
        let sheet = try sheet()
        let frames = FrameLog(sheet)
        runs.panelOpened()
        sheet.open {}
        try await wait("the frame") { self.blocks() == ["arg=show\ninput.event=sheet.open"] && frames.last != nil }
        let before = sheet.state

        sheet.pick(SpotItem(title: "A", run: "a"))
        try await wait("the call") { self.blocks() == ["arg=show\ninput.event=sheet.open", "arg=press\ninput.item=a"] }
        time += 5
        try await wait("the shown work") { sheet.acts.count == 1 }
        XCTAssertEqual(sheet.calls.count, 1)
        XCTAssertEqual(runs.actSpot, "script")

        openGate()
        try await wait("the end of the call") { sheet.calls.isEmpty }
        XCTAssertTrue(sheet.acts.isEmpty)
        XCTAssertNil(runs.runningSummary)
        XCTAssertNil(runs.actSpot)
        XCTAssertEqual(sheet.shownState, before)
    }

    func testWorkShowsByItselfOnceItsSecondHasPassed() async throws {
        let live = SpotRuns()
        defer { live.quit() }
        try script(body: "sleep 30")
        live.take(try SpotsFolder(url: folder).scan())
        let sheet = try XCTUnwrap(live.sheets["script"])
        sheet.pressCard()
        let changes = expectation(description: "the second has passed")

        XCTAssertNil(withObservationTracking { live.runningSummary } onChange: { changes.fulfill() })
        await fulfillment(of: [changes], timeout: 60)

        XCTAssertNotNil(live.runningSummary)
    }

    func testTheSpotShowsASpinnerWithNoValueAndARingFromValue() async throws {
        try script(body: steps([
            ("half", "frame=\\nprogress=0.42"),
            ("over", "frame=\\nprogress=7"),
            ("under", "frame=\\nprogress=-1"),
            ("none", "frame=\\ntitle=Almost")
        ]))
        let sheet = try sheet()
        sheet.pressCard()
        time += 1
        try await wait("the shown work") { !sheet.acts.isEmpty }
        let call = try XCTUnwrap(sheet.acts.first)
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
        try script(toml: "title = 'Encode'\ndetail = 'Videos'", "printf 'frame=\\ntitle=42%%\\ndetail=2 min left\\n---\\n'\nwhile [ ! -e '\(path("end"))' ]; do sleep 0.02; done")
        let sheet = try sheet()
        sheet.pressCard()
        try await wait("the frame") { sheet.calls.first?.status != nil }
        XCTAssertEqual(sheet.shownState.title, "Encode")

        time += 1
        try await wait("the shown work") { sheet.shownState.title == "42%" }
        XCTAssertEqual(sheet.shownState.subtitle, "2 min left")
        XCTAssertEqual(sheet.state.title, "Encode")
        XCTAssertEqual(sheet.state.subtitle, "Videos")

        touch("end")
        try await wait("the end") { sheet.calls.isEmpty }
        XCTAssertEqual(sheet.shownState.title, "Encode")
        XCTAssertEqual(sheet.shownState.subtitle, "Videos")
    }

    func testAFrameWithOnlyATitleKeepsTheDetailOfTheSpot() async throws {
        try script(toml: "title = 'Encode'\ndetail = 'Videos'", "printf 'frame=\\ntitle=42%%\\n---\\n'\nsleep 30")
        let sheet = try sheet()
        sheet.pressCard()
        try await wait("the frame") { sheet.calls.first?.status != nil }
        time += 1

        try await wait("the shown work") { sheet.shownState.title == "42%" }
        XCTAssertEqual(sheet.shownState.subtitle, "Videos")
    }

    func testAStoppedCallLeavesNothingOnTheSpotOrInTheMenuBar() async throws {
        try script(toml: "title = 'Encode'", Self.progress)
        let sheet = try sheet()
        sheet.pressCard()
        try await wait("the frame") { sheet.calls.first?.status != nil }
        time += 1
        try await wait("the shown work") { sheet.shownState.title == "42%" }

        sheet.pressCard()

        XCTAssertTrue(sheet.acts.isEmpty)
        XCTAssertEqual(sheet.shownState.title, "Encode")
        XCTAssertNil(sheet.shownState.subtitle)
        XCTAssertNil(runs.runningSummary)
        XCTAssertNil(runs.actSpot)
        try await pause()
        XCTAssertEqual(log(), ["press"])
    }

    func testTheMenuBarShowsTheOldestCallOfAllScriptsAndHowManyRun() async throws {
        try script("a", "sleep 30")
        try script("z", "printf 'frame=\\nprogress=0.25\\n---\\n'\nsleep 30")
        _ = try scanned()
        let a = try XCTUnwrap(runs.sheets["a"])
        let z = try XCTUnwrap(runs.sheets["z"])

        z.pressCard()
        try await wait("the frame") { z.calls.first?.status != nil }
        time += 1
        a.pressCard()
        try await wait("the summary") { self.runs.runningSummary == "\(z.spot.name) is running" }
        XCTAssertEqual(runs.actSpot, "z")

        time += 1
        try await wait("the summary of both") { self.runs.runningSummary == "2 running. \(z.spot.name) is the oldest" }
        XCTAssertEqual(runs.actSpot, "z")

        z.stop(try XCTUnwrap(z.calls.first))
        XCTAssertEqual(runs.runningSummary, "\(a.spot.name) is running")
        XCTAssertEqual(runs.actSpot, "a")
    }

    func testTheSpotShowsItsOldestCall() async throws {
        try script(toml: "", """
        case "$1" in
          show) printf 'frame=\\nclass=grid grid-cols-2 gap-part\\n\\nbutton=a\\ntitle=A\\n\\nbutton=b\\ntitle=B\\n' ;;
          a) printf 'frame=\\ntitle=A\\n---\\n'; sleep 30 ;;
          b) printf 'frame=\\ntitle=B\\n---\\n'; sleep 30 ;;
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
        try await wait("both frames") { sheet.calls.count == 2 && sheet.calls.allSatisfy { $0.status != nil } }
        time += 1

        try await wait("both shown") { sheet.acts.count == 2 }
        XCTAssertEqual(sheet.shownState.title, "B")
    }

    func testARunningPartShowsOnThatPartOnly() async throws {
        try script(toml: "", """
        case "$1" in
          show) printf 'frame=\\nclass=grid grid-cols-2 gap-part\\n\\nbutton=go\\ntitle=Go\\n\\ntext=other\\ntitle=Other\\n' ;;
          go) sleep 30 ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the parts") { sheet.panel != nil }
        let parts = try XCTUnwrap(sheet.panel?.parts)

        sheet.press(parts[0])
        XCTAssertNil(sheet.act(of: parts[0]))
        time += 1

        try await wait("the shown work") { sheet.act(of: parts[0]) != nil }
        XCTAssertNil(sheet.act(of: parts[1]))
        XCTAssertTrue(parts[0].isPressable)
        XCTAssertFalse(parts[1].isPressable)
        XCTAssertNil(sheet.cardAct)
    }

    func testAPartWhoseCallDrewItsOwnFrameShowsThatFrameAndNoWork() async throws {
        try script(toml: "", """
        case "$1" in
          show) printf 'frame=\\nclass=gap-part\\n\\nbutton=go\\ntitle=Go\\n' ;;
          go) printf 'frame=\\nclass=gap-part\\n\\nbutton=go\\ntitle=Done\\n---\\n'; sleep 30 ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the parts") { sheet.panel != nil }
        let go = try XCTUnwrap(sheet.panel?.parts.first)

        sheet.press(go)
        try await wait("the frame of the call") { sheet.panel?.parts.first?.title == "Done" }
        time += 1

        XCTAssertNil(sheet.act(of: go))
        XCTAssertEqual(sheet.calls.count, 1)
    }

    func testARunningActionOrPickShowsOnItsRowOfTheMenu() async throws {
        try script(toml: "", """
        case "$1" in
          show) printf 'button=go\\ntitle=Go\\nscope=spot\\n\\nbutton=copy\\ntitle=Copy\\n\\nitem=a\\ntitle=A\\n' ;;
          go) sleep 30 ;;
          press) sleep 30 ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        let item = try XCTUnwrap(sheet.list.selectedItem)
        let menu = try XCTUnwrap(ActionMenu(spot: sheet.spot, item: item))
        let primary = try XCTUnwrap(menu.rows.first { $0.action == nil })
        let go = try XCTUnwrap(menu.rows.first { $0.action?.id == "go" })
        let copy = try XCTUnwrap(menu.rows.first { $0.action?.id == "copy" })

        sheet.run(try XCTUnwrap(go.action), item: nil)
        time += 1
        try await wait("the shown action") { sheet.act(of: go, item: nil) != nil }
        XCTAssertNil(sheet.act(of: copy, item: item))
        XCTAssertNil(sheet.act(of: primary, item: item))

        sheet.pick(item)
        time += 1
        try await wait("the shown pick") { sheet.act(of: primary, item: item) != nil }
        XCTAssertNil(sheet.cardAct)
    }

    func testARunningCardSaysThatAPressStopsItAndAPressDoes() async throws {
        try script(body: "sleep 5\ntouch '\(path("went-on"))'")
        let sheet = try sheet()
        let menu = try XCTUnwrap(ActionMenu(spot: sheet.spot, item: nil))
        let row = try XCTUnwrap(menu.rows.first)

        sheet.pressCard()
        XCTAssertNil(sheet.cardAct)
        XCTAssertNil(sheet.act(of: row, item: nil))
        time += 1

        try await wait("the shown card") { sheet.cardAct != nil }
        XCTAssertNotNil(sheet.act(of: row, item: nil))
        try await wait("the call") { self.log() == ["press"] }
        sheet.pressCard()
        XCTAssertNil(sheet.cardAct)
        XCTAssertFalse(sheet.isCardRunning)
        try await allEnded()
        XCTAssertFalse(exists("went-on"))
    }

    func testAPressOfAPartWithinOneSecondOfItsStartDoesNothing() async throws {
        try script(toml: "", """
        case "$1" in
          show) printf 'frame=\\nclass=gap-part\\n\\nbutton=go\\ntitle=Go\\nclose=false\\n' ;;
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

        XCTAssertEqual(sheet.calls.filter(\.isAct).count, 1)
        try await wait("the end of the work") { self.exists("done") }
        try await wait("the read after the work") { self.log() == ["show", "go", "show"] }
    }

    func testAPickOrAnActionWithinOneSecondOfItsStartDoesNothing() async throws {
        try script(toml: "", """
        case "$1" in
          show) printf 'button=go\\ntitle=Go\\nscope=spot\\n\\nitem=a\\ntitle=A\\n' ;;
          go) sleep 0.2; touch '\(path("action"))' ;;
          press) sleep 0.2; touch '\(path("pick"))' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        let action = try XCTUnwrap(sheet.spot.frameActions.first)
        let item = try XCTUnwrap(sheet.list.selectedItem)

        sheet.run(action, item: nil)
        sheet.pick(item)
        sheet.run(action, item: nil)
        sheet.pick(item)

        XCTAssertEqual(sheet.calls.filter(\.isAct).count, 2)
        try await wait("the end of the work") { self.exists("action") && self.exists("pick") }
    }

    func testAPressOfACardWithinOneSecondOfItsStartDoesNothing() async throws {
        try script(toml: "[on]\n\"panel.open\" = true", "[ \"$1\" = show ] && { printf 'switch=power\\nclass=card:flex\\nvalue=false\\n'; exit 0; }\nsleep 0.3\ntouch '\(path("done"))'\nprintf 'switch=power\\nclass=card:flex\\nvalue=true\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the kind") { sheet.spot.kind == .toggle }

        sheet.pressCard()
        sheet.pressCard()

        XCTAssertEqual(sheet.state.on, true)
        XCTAssertTrue(sheet.isCardRunning)
        try await wait("the end of the work") { self.exists("done") && !sheet.isCardRunning }
        XCTAssertEqual(sheet.state.on, true)
    }

    func testASecondAskForAFormWithinOneSecondLeavesTheFirstRunning() async throws {
        try script(toml: "", """
        case "$1" in
          show) printf 'button=new\\ntitle=New\\nscope=spot\\n\\ntext=a\\ntitle=A\\n' ;;
          new) \(untilRelease); printf 'frame=\\ntype=form\\ntitle=New\\n\\nfield=a\\ntitle=A\\n' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the action") { sheet.spot.frameActions.count == 1 }
        let action = try XCTUnwrap(sheet.spot.frameActions.first)

        async let first = sheet.form(action, item: nil)
        try await wait("the call") { sheet.calls.contains(where: \.isAct) }
        let second = try await sheet.form(action, item: nil)

        XCTAssertNil(second)
        openGate()
        let form = try await first
        XCTAssertEqual(form?.fields.map(\.name), ["a"])
    }

    func testAPressOfAnItemAsksWithAFormAndASubmitCanAnswerWithTheFormAgain() async throws {
        try script(toml: "", """
        case "$1" in
          show) printf 'text=a\\ntitle=A\\n' ;;
          press) case "$(cat)" in *input.name=x*) ;; *) printf 'frame=\\ntype=form\\ntitle=Name\\n\\nfield=name\\ntitle=Name\\n' ;; esac ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the read") { sheet.calls.isEmpty }
        let item = SpotItem(title: "A", run: "a")
        let press = CommandAction(id: Handler.press.name, title: item.title)

        guard case .form(let form) = await sheet.answer(toPick: item) else { return XCTFail("the press asked with no form") }
        try await wait("the end of the press") { sheet.calls.isEmpty }
        var draft = FormDraft(form: form)
        draft.set("y", for: "name")
        let again = try await sheet.submit(press, item: item, draft: draft)
        draft.set("x", for: "name")
        let done = try await sheet.submit(press, item: item, draft: draft)

        XCTAssertEqual(form.fields.map(\.name), ["name"])
        XCTAssertEqual(again, .form(form))
        XCTAssertEqual(done, .done)
    }

    func testAChangeAnswersWithTheFormOfItsScriptOrIsDone() async throws {
        try script(toml: "", """
        case "$1" in
          show) printf 'text=a\\ntitle=A\\n' ;;
          editor) printf 'frame=\\ntype=form\\ntitle=Editor\\n\\nchoice=editor\\ntitle=Editor\\n\\noption=zed\\ntitle=Zed\\n' ;;
          folder) touch "\(path("folder"))" ;;
        esac
        """)
        let sheet = try sheet()

        let asked = try await sheet.change(CommandAction(id: "editor", title: "Change editor"))
        let done = try await sheet.change(CommandAction(id: "folder", title: "Change folder"))

        guard case .form(let form) = asked else { return XCTFail("no form: \(String(describing: asked))") }
        XCTAssertEqual(form.fields.map(\.name), ["editor"])
        XCTAssertEqual(done, .done)
        XCTAssertTrue(exists("folder"))
    }

    func testQuittingStopsEachCall() async throws {
        try script(toml: "", """
        trap 'touch "\(path("stopped"))"; exit 0' TERM
        printf 'frame=\\nclass=gap-part\\n\\ntext=a\\ntitle=A\\n---\\n'
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
        try script(toml: "[on]\n\"panel.open\" = true", "[ \"$1\" = show ] && printf 'switch=power\\nclass=card:flex\\nvalue=false\\n'\n[ \"$1\" = power ] && sed -n 's/^input\\.value=//p' > '\(path("value"))'\n[ \"$1\" = power ] && sleep 30\nexit 0")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the kind") { sheet.spot.kind == .toggle && sheet.calls.isEmpty }
        sheet.pressCard()
        XCTAssertEqual(sheet.state.on, true)
        try await wait("the call with its value") { self.log() == ["show", "power"] && (try? String(contentsOfFile: self.path("value"), encoding: .utf8)) == "true\n" }

        runs.quit()
        try await pause()

        XCTAssertEqual(sheet.state.on, false)
        XCTAssertEqual(log(), ["show", "power"])
    }

    func testAReadThatWaitsToRunAgainDoesNotRunAfterAQuit() async throws {
        try script(toml: "", "printf 'item=a\\ntitle=A\\n---\\n'\nsleep 30")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        sheet.show(need: .change)

        runs.quit()
        try await pause()

        XCTAssertEqual(log(), ["show"])
    }

    func testAQuitChangesNothingOnAStayingScriptThatFailsAsItEnds() async throws {
        try script(toml: "stay = true\n[on]\n\"app.launch\" = true", """
        while IFS= read -r line; do
          case "$line" in call=*) call=${line#call=} ;; esac
          [ -n "$line" ] || printf 'end=%s\\n\\ntext=n\\ntitle=A\\n---\\n' "$call"
        done
        exit 3
        """)
        let (sheet, told) = try toldSheet()
        _ = try scanned()
        try await wait("the value") { sheet.reading.value?.title == "A" }

        runs.quit()
        try await pause()

        XCTAssertEqual(told(), [])
        XCTAssertFalse(sheet.reading.isStale)
        XCTAssertEqual(log().count, 1)
    }
}
