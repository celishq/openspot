import XCTest
@testable import OpenspotCore

@MainActor
final class SpotRunsStayTests: SpotRunsCase {
    private func reads() -> [String] {
        blocks().map { $0.split(separator: "\n").filter { !$0.hasPrefix("input.event=") && !$0.hasPrefix("input.alt=") }.joined(separator: "\n") }
    }

    private static let form = """
    while IFS= read -r line; do
      printf '%%s\\n' "$line" >> '%@'
      case "$line" in
        call=*) call=${line#call=}; name=; filled= ;;
        arg=*) [ -n "$name" ] || name=${line#arg=} ;;
        ?*) filled=1 ;;
        '')
          if [ "$name" = new ] && [ -z "$filled" ]; then
            printf 'frame=\\ntype=form\\ntitle=New\\nend=%%s\\n\\nfield=a\\ntitle=A\\n---\\n' "$call"
          else
            printf 'end=%%s\\n\\nbutton=new\\ntitle=New\\nscope=spot\\n\\nitem=a\\ntitle=A\\n---\\n' "$call"
          fi
          ;;
      esac
    done
    """

    private static let ends = """
    while IFS= read -r line; do
      printf '%%s\\n' "$line" >> '%@'
      case "$line" in
        call=*) id=${line#call=}; name= ;;
        arg=*) [ -n "$name" ] || name=${line#arg=} ;;
        stop=*) touch '%@'; name=stop ;;
        '')
          case "$name" in
            stop) ;;
            go) ( while [ ! -f '%@' ]; do sleep 0.05; done; printf 'end=%%s\\n---\\n' "$id" ) & ;;
            *) printf 'button=go\\ntitle=Go\\nscope=spot\\n\\nitem=a\\ntitle=A\\n\\nend=%%s\\n---\\n' "$id" ;;
          esac
          name= ;;
      esac
    done
    """

    private static let holds = """
    trap 'touch "%@"' EXIT
    while IFS= read -r line; do
      printf '%%s\\n' "$line" >> '%@'
      case "$line" in
        call=*) call=${line#call=} ;;
        arg=hold) name=hold ;;
        input.item=hold) name=hold ;;
        arg=*) [ -n "$name" ] || name=${line#arg=} ;;
        '')
          case "$name" in
            hold) sleep 600 > /dev/null 2>&1 & echo $! >> '%@' ;;
            ?*) printf 'end=%%s\\n\\nitem=a\\ntitle=A\\n---\\n' "$call" ;;
          esac
          name= ;;
      esac
    done
    """

    private func holding() throws {
        try script(toml: "stay = true", String(format: Self.holds, path("ended"), path("blocks"), path("children")))
    }

    func testAHeldCallKeepsItsStayingScriptPastTheReadLimitTheSheetAndThePanel() async throws {
        try holding()
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.pick(SpotItem(title: "Hold", run: "hold"))
        let child = try await pid("children")
        sheet.close()
        runs.panelClosed()
        time += 60
        try await pause()

        XCTAssertEqual(sheet.calls.map(\.key), ["call:press\nhold"])
        XCTAssertFalse(exists("ended"))
        XCTAssertEqual(kill(child, 0), 0)
    }

    func testASecondPressOfAKeyReachesAStayingScriptWhoseFirstCallIsHeld() async throws {
        try holding()
        let sheet = try sheet()

        sheet.pressKey("hold")
        try await wait("the held call") { self.reads().contains("arg=hold") }
        sheet.pressKey("hold")

        try await wait("the second press") { self.reads().filter { $0 == "arg=hold" }.count == 2 }
        XCTAssertEqual(sheet.calls.count, 2)
    }

    func testAQuitEndsTheProcessesThatAHeldCallStarted() async throws {
        try holding()
        let sheet = try sheet()
        sheet.pressKey("hold")
        let child = try await pid("children")

        runs.quit()

        try await wait("the end of the child") { kill(child, 0) != 0 }
        XCTAssertTrue(exists("ended"))
    }

    func testEachCallOfAStayingScriptHasItsOwnId() async throws {
        try staying(toml: "stay = true")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))

        try await wait("the call") { self.blocks(ids: true) == ["call=1\narg=show\ninput.event=sheet.open", "call=2\narg=press\ninput.item=a"] }
    }

    func testACallRunsUntilItsEndOnceTheScriptPrintsEnds() async throws {
        try script(toml: "stay = true", String(format: Self.ends, path("blocks"), path("done"), path("done")))
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the action") { sheet.spot.frameActions.count == 1 }

        sheet.run(try XCTUnwrap(sheet.spot.frameActions.first), item: nil)
        try await wait("the running call") { sheet.calls.count == 1 }
        try "".write(toFile: path("done"), atomically: true, encoding: .utf8)

        try await wait("the end") { sheet.calls.isEmpty }
    }

    func testASecondPressSendsAStopWithTheIdOfTheCall() async throws {
        try script(toml: "stay = true", String(format: Self.ends, path("blocks"), path("done"), path("done")))
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the action") { sheet.spot.frameActions.count == 1 }
        let action = try XCTUnwrap(sheet.spot.frameActions.first)
        sheet.run(action, item: nil)
        try await wait("the running call") { sheet.calls.count == 1 }
        time += 2

        sheet.run(action, item: nil)

        XCTAssertEqual(sheet.calls.count, 1)
        try await wait("the stop") { self.blocks(ids: true).last == "stop=2" }
        try await wait("the end that the script prints") { sheet.calls.isEmpty }
    }

    func testEachFrameWithABlockReplacesAllAndOnlyTheFrameThatEndsAReadAnswersIt() async throws {
        try script(toml: "stay = true", """
        while IFS= read -r line; do
          case "$line" in
            call=*) call=${line#call=} ;;
            '')
              printf 'frame=\\nclass=gap-part\\n\\ntext=peer\\ntitle=Early\\n---\\n'
              \(untilRelease)
              printf 'end=%s\\n\\nitem=a\\ntitle=A\\n---\\n' "$call"
              printf 'frame=\\nclass=gap-part\\n\\ntext=peer\\ntitle=Late\\n---\\n' ;;
          esac
        done
        """)
        let sheet = try sheet()
        let frames = FrameLog(sheet)
        var isReady = false
        runs.panelOpened()
        sheet.open { isReady = true }
        try await wait("the early frame") { frames.last?.contains("Early") == true }

        XCTAssertFalse(isReady)
        openGate()

        try await wait("the late frame") { frames.last?.contains("Late") == true }
        XCTAssertTrue(isReady)
        XCTAssertEqual(sheet.list.shown.map(\.run), [])
    }

    func testALaterFrameOfAStayingScriptPatchesANodeOfItsOpenSheet() async throws {
        try script(toml: "stay = true", """
        while IFS= read -r line; do
          case "$line" in
            call=*) call=${line#call=} ;;
            '')
              printf 'end=%s\\n\\nframe=\\nclass=gap-part\\n\\ntext=name\\ntitle=Home\\ndetail=Saved\\n\\nbutton=forget\\ntitle=Forget\\n---\\n' "$call"
              ( \(untilRelease); printf 'text=name\\ntitle=Office\\n---\\n' ) & ;;
          esac
        done
        """)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the first frame") { sheet.panel?.parts.first?.title == "Home" }

        openGate()

        try await wait("the patch") { sheet.panel?.parts.first?.title == "Office" }
        XCTAssertEqual(sheet.panel?.parts.first?.detail, "Saved")
        XCTAssertEqual(sheet.panel?.parts.map(\.id), ["name", "forget"])
    }

    func testAPickReachesTheRunningStayingScript() async throws {
        try staying(toml: "stay = true")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))

        try await wait("the call and its end") { self.reads().last == "arg=press\ninput.item=a" && sheet.calls.isEmpty }
        XCTAssertEqual(Set(reads().dropLast()), ["arg=show"])
        XCTAssertEqual(log().count, 1)
    }

    func testAReadOfAStayingScriptIsReadingUntilItsAnswerIsIn() async throws {
        try staying(toml: "stay = true")
        let sheet = try sheet()
        runs.panelOpened()

        sheet.open {}
        XCTAssertTrue(sheet.isShowing)
        let limit = ContinuousClock.now + .seconds(60)
        while sheet.isShowing, ContinuousClock.now < limit { await Task.yield() }

        XCTAssertFalse(sheet.isShowing)
        XCTAssertEqual(sheet.list.shown.count, 1)
    }

    func testAnActionReachesTheRunningStayingScript() async throws {
        try staying(toml: "stay = true", frame: "button=go\\ntitle=Go\\n\\nitem=a\\ntitle=A\\n")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        let action = try XCTUnwrap(sheet.spot.frameActions.first)

        sheet.run(action, item: sheet.list.selectedItem)
        sheet.run(action, item: nil)

        try? await wait("the calls") { self.reads() == ["arg=show", "arg=go\ninput.item=a", "arg=go"] }
        XCTAssertEqual(reads(), ["arg=show", "arg=go\ninput.item=a", "arg=go"])
        XCTAssertEqual(log().count, 1)
    }

    func testAFormOfAStayingScriptGoesAsTwoBlocks() async throws {
        try script(toml: "stay = true", String(format: Self.form, path("blocks")))
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the action") { sheet.spot.frameActions.count == 1 }
        let action = try XCTUnwrap(sheet.spot.frameActions.first)

        let asked = try await sheet.form(action, item: nil)
        let form = try XCTUnwrap(asked)
        XCTAssertEqual(form.fields.map(\.name), ["a"])
        XCTAssertEqual(sheet.spot.frameActions.count, 1)
        var draft = FormDraft(form: form, prefill: "")
        draft.set("one", for: "a")
        let answer = try await sheet.submit(action, item: nil, draft: draft)

        XCTAssertEqual(answer, .done)
        try await wait("the blocks") { self.reads() == ["arg=show", "arg=new", "arg=new\ninput.a=one"] }
        XCTAssertEqual(log().count, 1)
    }

    func testEachFrameOfASpotIsParsedOnceAndOffTheMainThread() async throws {
        let parses = FrameParses()
        try await FrameParses.$meter.withValue(parses) {
            try script("stay", toml: "stay = true", """
            while read -r line; do
              case "$line" in
                call=*) id=${line#call=} ;;
                "") printf 'call=%s\\n\\nitem=a\\ntitle=A\\n---\\nitem=a\\ntitle=A\\n\\nitem=b\\ntitle=B\\n---\\nend=%s\\n---\\n' "$id" "$id" ;;
              esac
            done
            """)
            try script("once", toml: "", """
            case "$1" in
              show) printf 'button=add\\ntitle=Add\\nscope=spot\\n\\nitem=a\\ntitle=A\\n' ;;
              add) case "$(cat)" in *name=*) printf 'frame=\\ntitle=Saved\\n' ;; *) printf 'frame=\\ntype=form\\ntitle=Name\\n\\nfield=name\\ntitle=Name\\n' ;; esac ;;
            esac
            """)
            let stay = try sheet("stay")
            let once = try sheet("once")
            runs.panelOpened()
            stay.open {}
            try await wait("the three frames of the staying spot") { stay.list.all.count == 2 && parses.count == 3 }
            let stayed = parses.count

            once.open {}
            try await wait("the read of the spot that runs once") { once.spot.frameActions.count == 1 && once.calls.isEmpty }
            XCTAssertEqual(parses.count, stayed + 1)

            let action = try XCTUnwrap(once.spot.frameActions.first)
            let asked = try await once.form(action, item: nil)
            XCTAssertEqual(parses.count, stayed + 2)
            try await wait("the end of the ask") { once.calls.isEmpty }
            var draft = FormDraft(form: try XCTUnwrap(asked))
            draft.set("x", for: "name")
            _ = try await once.submit(action, item: nil, draft: draft)
            try await wait("the read after the submit") { once.calls.isEmpty && !once.list.isLoading }
            XCTAssertEqual(parses.count, stayed + 3)
        }

        XCTAssertEqual(parses.countOnMain, 0)
    }

    private static let silentForm = """
    while IFS= read -r line; do
      printf '%%s\\n' "$line" >> '%@'
      case "$line" in
        call=*) call=${line#call=} ;;
        arg=new) ;;
        arg=show) printf 'end=%%s\\n\\nbutton=new\\ntitle=New\\nscope=spot\\n---\\n' "$call" ;;
      esac
    done
    """

    private func silentFormSheet() async throws -> (SpotRun, CommandAction) {
        try script(toml: "stay = true", String(format: Self.silentForm, path("asked")))
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the action") { sheet.spot.frameActions.count == 1 }
        return (sheet, try XCTUnwrap(sheet.spot.frameActions.first { $0.id == "new" }))
    }

    func testAPressAgainStopsAFormOfAStayingScript() async throws {
        let (sheet, new) = try await silentFormSheet()

        async let first = sheet.form(new, item: nil)
        try await wait("the ask") { self.log("asked").contains("arg=new") }
        time = time.addingTimeInterval(SpotRun.pressPause)
        let second = try await sheet.form(new, item: nil)
        let answer = try await first

        XCTAssertNil(second)
        XCTAssertNil(answer)
        try await wait("the stop of the form") { self.log("asked").contains { $0.hasPrefix("stop=") } }
    }

    func testASearchReachesTheRunningStayingScript() async throws {
        try staying(toml: "stay = true\n[on]\n\"sheet.text\" = true", frame: "item=a\\ntitle=A\\n")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.search("rep")

        try await wait("the search") { self.reads() == ["arg=show", "arg=sheet.text\ninput.value=rep"] }
        try await wait("the answer") { !sheet.list.isWaiting }
        XCTAssertEqual(log().count, 1)
    }

    private var answering: String {
        """
        while IFS= read -r line; do
          printf '%s\\n' "$line" >> '\(path("blocks"))'
          case "$line" in
            call=*) call=${line#call=}; n=0; text= ;;
            stop=*) call= ;;
            input.text=*) text=${line#input.text=} ;;
          esac
          [ -n "$line" ] || [ -z "$call" ] || {
            if [ -n "$text" ]; then printf 'end=%s\\n\\nitem=%s\\ntitle=%s\\n---\\n' "$call" "$text" "$text"; else printf 'end=%s\\n---\\n' "$call"; fi
          }
        done
        """
    }

    func testAStayingScriptAnswersTheMainSearchWithOnlyTheNewestOfFiveFastTexts() async throws {
        try script(toml: "stay = true\n[on]\nsearch = '^[0-9]'", answering)
        let sheet = try sheet()
        runs.panelOpened()
        var shown: [[String]] = []
        sheet.onReport = { if case .listChange = $0 { shown.append(sheet.answers.map(\.run)) } }

        for text in ["1", "12", "123", "1234", "12345"] { sheet.answer(text) }

        try await wait("the newest answer") { sheet.answers.map(\.run) == ["12345"] }
        try await wait("each older text stopped") { self.reads().filter { $0.hasPrefix("stop=") }.count == 4 }
        try await pause()
        XCTAssertEqual(shown, [["12345"]])
        XCTAssertEqual(log().count, 1)
    }

    func testAnAnswerOfAStayingScriptThatEndsIsNoLongerAwaited() async throws {
        try script(toml: "stay = true\n[on]\nsearch = '^[0-9]'", "while IFS= read -r line; do [ \"$line\" = input.text=12 ] && exit 1; done")
        let sheet = try sheet()
        runs.panelOpened()

        sheet.answer("12")

        try await wait("the end of the answer") { !sheet.isAnswering }
        XCTAssertEqual(sheet.answers, [])
    }

    func testThePictureOfAStayingScriptIsNoAnswerOfTheSearch() async throws {
        try script(toml: "stay = true\n[on]\n\"app.launch\" = true\nsearch = '^[0-9]'\n\"panel.open\" = true", """
        while IFS= read -r line; do
          case "$line" in call=*) call=${line#call=} ;; input.text=12) printf 'item=clock\\ntitle=Clock\\n---\\n' ;; esac
          [ -n "$line" ] || printf 'end=%s\\n---\\n' "$call"
        done
        """)
        let sheet = try sheet()
        runs.panelOpened()

        sheet.answer("12")

        try await wait("the end of the answer") { !sheet.isAnswering }
        XCTAssertEqual(sheet.answers, [])
    }

    func testAServedStayingScriptAnswersItsSheetAndTheMainSearchApart() async throws {
        try """
        #!/bin/sh
        . "$OPENSPOT_SH"
        main() {
          case "$1" in
            search) text=$(value text); printf 'item=%s\\ntitle=Is %s\\n' "$text" "$text" ;;
            show) printf 'item=a\\ntitle=A\\n' ;;
          esac
        }
        openspot_serve main "$@"
        """.writeScript(to: folder.spotFile("script"), toml: "stay = true\n[on]\n\"sheet.open\" = true\nsearch = '^[0-9]'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row of the sheet") { sheet.list.shown.map(\.run) == ["a"] }

        sheet.answer("12")

        try await wait("the answer") { sheet.answers.map(\.run) == ["12"] }
        XCTAssertEqual(sheet.list.shown.map(\.run), ["a"])
    }

    func testAToggleOfAStayingScriptThatFailsIsUndone() async throws {
        try script(toml: "stay = true", #"""
        while IFS= read -r line; do
          case "$line" in
            call=*) id=${line#call=}; name= ;;
            arg=*) [ -n "$name" ] || name=${line#arg=} ;;
            '')
              [ "$name" = power ] && exit 3
              [ -f '\#(path("started"))' ] || printf 'end=%s\n\nitem=a\ntitle=A\n---\n' "$id"
              touch '\#(path("started"))' ;;
          esac
        done
        """#)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        let before = sheet.state
        sheet.state = before.switched(on: true)

        sheet.send(SpotRun.Call(message: Message("power"), key: SpotRun.cardKey, purpose: .act(SpotRun.Act(undo: before))))

        XCTAssertTrue(sheet.isCardRunning)
        try await wait("the undo of the switch") { sheet.state == before }
        XCTAssertFalse(sheet.isCardRunning)
    }

    private func answeringOnce() throws {
        try script(toml: "stay = true", #"""
        while IFS= read -r line; do
          case "$line" in
            call=*) id=${line#call=} ;;
            '')
              [ -f '\#(path("started"))' ] || printf 'end=%s\n\nitem=a\ntitle=A\n---\n' "$id"
              touch '\#(path("started"))' ;;
          esac
        done
        """#)
    }

    func testRemovingARecordDropsItsAskItsTimerAndItsFrames() async throws {
        let clock = FakeClock()
        var logged: [CallLog.Record] = []
        runs.quit()
        runs = SpotRuns(clock: clock.value, stopPause: 0.2)
        runs.onCall = { record in logged.append(record) }
        try answeringOnce()
        let (sheet, told) = try toldSheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        let link = try XCTUnwrap(sheet.link as? StayMode)
        sheet.show(need: .change)
        let timer = try XCTUnwrap(link.records.values.first?.timer)

        link.end()
        await timer.value
        clock.advance(by: 60)

        XCTAssertTrue(link.records.isEmpty)
        XCTAssertFalse(sheet.isShowing)
        XCTAssertEqual(told(), [])
        XCTAssertEqual(logged.map(\.end), [.exited(0), .stopped])
        XCTAssertEqual(logged.last?.frames, [])
    }

    func testAReadOfAStayingScriptFailsAsSlowWhenTheClockPassesItsLimit() async throws {
        let clock = FakeClock()
        runs.quit()
        runs = SpotRuns(clock: clock.value, stopPause: 0.2)
        try answeringOnce()
        let (sheet, told) = try toldSheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        let link = try XCTUnwrap(sheet.link as? StayMode)
        sheet.show(need: .change)
        let timer = try XCTUnwrap(link.records.values.first?.timer)
        try await wait("the sleep of the timer") { clock.isSleeping(for: 10) }

        clock.advance(by: 9)
        XCTAssertEqual(told(), [])
        clock.advance(by: 1)
        await timer.value

        XCTAssertEqual(told(), ["Script took too long, so Openspot stopped it."])
        XCTAssertFalse(sheet.isShowing)
        XCTAssertEqual(link.records.values.map(\.isDropped), [true])
    }

    func testAnAnswerBeingAppliedIsNotFailedAsSlow() async throws {
        let clock = FakeClock()
        nonisolated(unsafe) var holds = false
        runs.quit()
        runs = SpotRuns(clock: clock.value, stopPause: 0.2, prepare: { _, _ in
            guard holds else { return }
            holds = false
            await MainActor.run { clock.advance(by: 10) }
            for _ in 0..<5 { await MainActor.run {} }
        })
        try script(toml: "stay = true", #"""
        while IFS= read -r line; do
          case "$line" in
            call=*) id=${line#call=} ;;
            '') printf 'end=%s\n\nitem=a\ntitle=A\n---\n' "$id" ;;
          esac
        done
        """#)
        let (sheet, told) = try toldSheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 && !sheet.isShowing }
        let link = try XCTUnwrap(sheet.link as? StayMode)

        holds = true
        sheet.show(need: .change)
        try await wait("the answer") { !holds && !sheet.isShowing && link.records.isEmpty }

        XCTAssertEqual(told(), [])
        XCTAssertNil(sheet.failure)
    }

    func testACardCallOfAStayingScriptReachesIt() async throws {
        try staying(toml: "stay = true")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.pressCard()

        try await wait("the call") { self.reads().count == 2 }
        try await wait("the end of the call") { !sheet.isCardRunning }
        XCTAssertEqual(log().count, 1)
    }

    func testAStayingMenuBarScriptRunsWithThePanelClosedAndItsFrameReachesTheMenuBar() async throws {
        menuBar.insert("script")
        try staying(toml: "stay = true", head: "\\nframe=\\nclass=gap-part\\n", frame: "text=n\\nclass=bar:flex\\ntitle=3\\n")
        _ = try scanned()

        try await wait("the mark") { self.runs.menuBarMarks.first?.mark.summary == "Script: 3" }

        XCTAssertFalse(runs.isPanelOpen)
        XCTAssertEqual(log().count, 1)
        XCTAssertEqual(reads(), ["arg=show"])
    }

    func testAStayingMenuBarScriptGoesOnWhenItsSheetAndThePanelCloseAndAScanComes() async throws {
        menuBar.insert("script")
        try staying(toml: "stay = true", frame: "frame=\\nclass=gap-part\\n\\ntext=n\\ntitle=3\\n\\nitems=list\\n\\nitem=a\\nparent=list\\ntitle=A\\n")
        let sheet = try sheet()
        try await wait("the row") { sheet.list.shown.count == 1 }
        runs.panelOpened()
        sheet.open {}
        sheet.close()
        runs.panelClosed()
        _ = try scanned()
        try await pause(0.15)

        XCTAssertFalse(exists("ended"))
        XCTAssertEqual(log().count, 1)

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))

        try await wait("the call") { self.reads().last == "arg=press\ninput.item=a" }
        XCTAssertEqual(log().count, 1)
    }

    func testAFrameOfAStayingMenuBarScriptIsItsWholePictureAndChangesItsMark() async throws {
        menuBar.insert("script")
        try script(toml: "stay = true", """
        while IFS= read -r line; do
          case "$line" in
            call=*) call=${line#call=} ;;
            arg=show) printf 'end=%s\\n\\nframe=\\nclass=gap-part\\n\\ntext=n\\nclass=bar:flex\\ntitle=3\\n---\\n' "$call" ;;
            arg=press) printf 'frame=\\nclass=gap-part\\n\\ntext=n\\nclass=bar:flex\\ntitle=4\\n---\\n' ;;
          esac
        done
        """)
        let sheet = try sheet()
        try await wait("the mark") { self.runs.menuBarMarks.first?.mark.summary == "Script: 3" }

        sheet.pick(SpotItem(title: "A", run: "a"))

        try await wait("the new mark") { self.runs.menuBarMarks.first?.mark.summary == "Script: 4" }
        XCTAssertEqual(runs.menuBarMarks.first?.mark.isStale, false)
    }

    func testASheetOfARunningStayingScriptOpensAtOnceWithItsLastFrame() async throws {
        menuBar.insert("script")
        try staying(toml: "stay = true", head: "\\nframe=\\nclass=gap-part\\n", frame: "text=n\\nclass=bar:flex\\ntitle=3\\n\\ntext=a\\ntitle=A\\n")
        let sheet = try sheet()
        try await wait("the mark") { self.runs.menuBarMarks.first?.mark.summary == "Script: 3" }
        XCTAssertNil(sheet.panel)
        var isReady = false

        sheet.open { isReady = true }

        XCTAssertTrue(isReady)
        XCTAssertEqual(sheet.panel?.parts.map(\.id), ["n", "a"])
        XCTAssertEqual(log().count, 1)
    }

    func testAStayingScriptIsWantedByThePanelOnlyWhileItIsOpen() async throws {
        try staying(toml: "stay = true\n[on]\n\"panel.open\" = true")
        let sheet = try sheet()
        try await pause(0.1)
        XCTAssertEqual(log(), [])

        runs.panelOpened()
        try await wait("the frame") { sheet.list.shown.count == 1 }
        XCTAssertEqual(reads(), ["arg=show"])

        runs.panelClosed()
        try await wait("the end") { self.exists("ended") }
        XCTAssertEqual(log().count, 1)
    }

    func testAStayingScriptThatListensToTheLaunchRunsFromTheStartWithNothingThatWantsIt() async throws {
        try staying(toml: "stay = true\n[on]\n\"app.launch\" = true")
        let sheet = try sheet()

        try await wait("the frame") { sheet.list.shown.count == 1 }
        XCTAssertEqual(blocks(ids: true), ["call=1\narg=show\ninput.event=panel.open"])

        runs.panelOpened()
        runs.panelClosed()
        runs.woke()
        try await pause(0.15)

        XCTAssertFalse(exists("ended"))
        XCTAssertEqual(log().count, 1)
    }

    func testAStayingScriptThatNothingWantsDoesNotStartOnAWake() async throws {
        try staying(toml: "stay = true\n[on]\nevery = 600")
        _ = try scanned()

        runs.woke()
        try await pause(0.15)

        XCTAssertEqual(log(), [])
    }

    func testAStayingScriptWithANumberGetsAReadOnItsTimer() async throws {
        menuBar.insert("script")
        try staying(toml: "stay = true\n[on]\nevery = 5", head: "\\nframe=\\nclass=gap-part\\n", frame: "text=n\\nclass=bar:flex\\ntitle=3\\n")
        _ = try scanned()
        try await wait("the mark") { self.runs.menuBarMarks.first?.mark.summary == "Script: 3" }
        XCTAssertEqual(reads(), ["arg=show"])

        time += 5
        runs.raise(.clock)

        try await wait("the read") { self.reads() == ["arg=show", "arg=every"] }
        XCTAssertEqual(log().count, 1)
    }

    func testAStayingScriptThatEndedStartsAgainAtTheNextMoment() async throws {
        menuBar.insert("script")
        try script(toml: "stay = true", """
        [ -f '\(path("second"))' ] || { touch '\(path("second"))'; printf 'end=1\\n\\nitem=n\\ntitle=1\\n'; exit 0; }
        while IFS= read -r line; do
          case "$line" in call=*) call=${line#call=} ;; esac
          [ -n "$line" ] || printf 'end=%s\\n\\nitem=n\\ntitle=2\\n---\\n' "$call"
        done
        """)
        let sheet = try sheet()
        try await wait("the end of the first run") { sheet.reading.isStale }
        XCTAssertEqual(sheet.reading.value?.title, "1")
        XCTAssertEqual(log().count, 1)

        runs.woke()

        try await wait("the second run") { sheet.reading.value?.title == "2" }
        XCTAssertFalse(sheet.reading.isStale)
        XCTAssertEqual(log().count, 2)
    }

    func testACallStartsAStayingScriptThatNothingWantsAndItEndsAfterTheCall() async throws {
        runs = SpotRuns(clock: clock.value, stopPause: 30)
        try staying(toml: "stay = true")
        let sheet = try sheet()

        sheet.pick(SpotItem(title: "A", run: "a"))

        try await wait("the end") { self.exists("ended") }
        XCTAssertEqual(reads(), ["arg=show", "arg=press\ninput.item=a"])
        XCTAssertEqual(log().count, 1)
    }

    func testAStayingScriptThatLeavesTheFolderEnds() async throws {
        menuBar.insert("script")
        let url = try staying(toml: "stay = true", head: "\\nframe=\\nclass=gap-part\\n", frame: "text=n\\nclass=bar:flex\\ntitle=3\\n")
        _ = try scanned()
        try await wait("the mark") { self.runs.menuBarMarks.first?.mark.summary == "Script: 3" }

        try FileManager.default.removeItem(at: url)
        _ = try scanned()

        try await wait("the end") { self.exists("ended") }
    }

    private static let givenUp = "Script failed 3 times in one minute. Openspot will not start it again until its file changes."

    func testThreeQuickFailuresStopNewStartsAndTellThePersonOnce() async throws {
        menuBar.insert("script")
        try script(toml: "stay = true", "echo broken >&2\nexit 1")
        let (sheet, told) = try toldSheet()

        _ = try scanned()
        try await wait("the first failure") { told().count == 1 }
        runs.woke()
        try await wait("the second failure") { told().count == 2 }
        XCTAssertEqual(told(), ["broken", "broken"])
        runs.woke()
        try await wait("the third failure") { told().count == 3 }
        XCTAssertEqual(told().last, Self.givenUp)
        XCTAssertEqual(log().count, 3)

        runs.woke()
        runs.panelOpened()
        runs.panelClosed()
        _ = try scanned()
        sheet.pick(SpotItem(title: "A", run: "a"))
        try await pause(0.15)

        XCTAssertEqual(log().count, 3)
        XCTAssertEqual(told().filter { $0 == Self.givenUp }.count, 1)
        XCTAssertEqual(told().count, 3)
    }

    func testFailuresMoreThanAMinuteApartDoNotStopNewStarts() async throws {
        menuBar.insert("script")
        try script(toml: "stay = true", "echo broken >&2\nexit 1")
        let (_, told) = try toldSheet()
        _ = try scanned()

        for count in 1...4 {
            try await wait("failure \(count)") { told().count == count }
            time += 31
            runs.woke()
        }

        try await wait("the fifth start") { self.log().count == 5 }
        XCTAssertEqual(told().filter { $0 == Self.givenUp }, [])
    }

    func testAChangedFileStartsAStoppedScriptAgainAndAnUnchangedOneStaysStopped() async throws {
        menuBar.insert("script")
        try script(toml: "stay = true", "echo broken >&2\nexit 1")
        let (_, told) = try toldSheet()
        _ = try scanned()
        try await wait("the first failure") { told().count == 1 }
        runs.woke()
        try await wait("the second failure") { told().count == 2 }
        runs.woke()
        try await wait("the third failure") { told().count == 3 }

        _ = try scanned()
        try await pause(0.1)
        XCTAssertEqual(log().count, 3)

        menuBar.insert("script")
        try staying(toml: "stay = true", head: "\\nframe=\\nclass=gap-part\\n", frame: "text=n\\nclass=bar:flex\\ntitle=3\\n")
        _ = try scanned()

        try await wait("the mark") { self.runs.menuBarMarks.first?.mark.summary == "Script: 3" }
        XCTAssertEqual(log().count, 4)
    }

    func testASheetOfAStoppedScriptDoesNotOpen() async throws {
        menuBar.insert("script")
        try script(toml: "stay = true", "exit 1")
        let (sheet, told) = try toldSheet()
        _ = try scanned()
        try await wait("the first failure") { told().count == 1 }
        runs.woke()
        try await wait("the second failure") { told().count == 2 }
        runs.woke()
        try await wait("the third failure") { told().count == 3 }
        var isReady = false

        sheet.open { isReady = true }
        try await pause(0.1)

        XCTAssertFalse(isReady)
        XCTAssertFalse(sheet.isOpen)
    }

    func testASheetThatAStayingScriptNeverShowedDoesNotStayOpen() async throws {
        try script(toml: "stay = true", "exit 1")
        let sheet = try sheet()
        var isReady = false

        sheet.open { isReady = true }
        try await wait("the end") { !sheet.isOpen }

        XCTAssertFalse(isReady)
    }

    func testASheetClosedBeforeItsAnswerOpensAgainWithAFreshAnswer() async throws {
        try script(toml: "stay = true", """
        while IFS= read -r line; do
          case "$line" in
            call=*) call=${line#call=} ;;
            '') \(untilRelease); printf 'end=%s\\n\\nitem=a\\ntitle=A\\n---\\n' "$call" ;;
          esac
        done
        """)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the first script") { self.log().count == 1 }

        sheet.close()
        try await allEnded()
        openGate()
        var isReady = false
        sheet.open { isReady = true }

        try await wait("the fresh answer") { isReady }
        XCTAssertTrue(sheet.isOpen)
        XCTAssertFalse(sheet.list.isLoading)
    }

    func testANewerSearchStopsTheOlderOneOfAStayingScriptAndItsLateAnswerChangesNothing() async throws {
        takeCalls()
        try script(toml: "stay = true\n[on]\n\"sheet.text\" = true", """
        while IFS= read -r line; do
          printf '%s\\n' "$line" >> '\(path("blocks"))'
          case "$line" in
            call=*) call=${line#call=}; args= ;;
            arg=*) args="$args ${line#arg=}" ;;
            input.value=*) args="$args ${line#input.value=}" ;;
            stop=*) touch '\(path("stopped"))'; args=stop ;;
            '')
              case "$args" in
                ' sheet.text a') ( \(untilRelease); printf 'end=%s\\n\\nitem=o\\ntitle=Old\\n---\\n' "$call"; \(TestSpot.toast) Done ) & ;;
                ' sheet.text ab') printf 'end=%s\\n\\nitem=n\\ntitle=New\\n---\\n' "$call" ;;
                ' show') printf 'end=%s\\n\\nitem=x\\ntitle=X\\n---\\n' "$call" ;;
              esac ;;
          esac
        done
        """)
        let sheet = try sheet()
        var toasts: [String] = []
        sheet.onReport = { if case .toast(let note) = $0 { toasts.append(note.words) } }
        runs.panelOpened()
        sheet.open {}
        try await wait("the first rows") { sheet.list.search == .script && sheet.list.shown.count == 1 }
        sheet.search("a")
        try await wait("the older search") { self.reads().contains("arg=sheet.text\ninput.value=a") }

        sheet.search("ab")

        try await wait("the newer answer") { sheet.list.shown.map(\.run) == ["n"] }
        XCTAssertTrue(exists("stopped"))
        openGate()
        try await wait("the toast after the late answer") { toasts == ["Done"] }
        XCTAssertEqual(sheet.list.shown.map(\.run), ["n"])
    }
    private func slowStaying(limit: TimeInterval = 1) throws -> (sheet: SpotRun, told: () -> [String]) {
        runs.quit()
        runs = SpotRuns(showLimit: limit, clock: clock.value, stopPause: 0.2)
        try script(toml: "stay = true", """
        first=; [ -f '\(path("started"))' ] || first=1; touch '\(path("started"))'
        while IFS= read -r line; do
          printf '%s\\n' "$line" >> '\(path("blocks"))'
          case "$line" in call=*) call=${line#call=} ;; stop=*) call= ;; esac
          if [ -z "$line" ] && [ -n "$call" ]; then
            if [ -n "$first" ]; then while [ -f '\(path("slow"))' ]; do sleep 0.02; done; fi
            printf 'end=%s\\n\\nitem=t\\ntitle=%s\\n---\\n' "$call" "$call"
            echo "$call" >> '\(path("answered"))'
          fi
        done
        """)
        _ = try scanned()
        return try toldSheet()
    }

    func testAReadOfAStayingScriptPastItsLimitFailsAsSlowAndItsLateAnswerChangesNothing() async throws {
        let (sheet, told) = try slowStaying()
        let frames = FrameLog(sheet)
        runs.panelOpened()
        sheet.open {}
        try await wait("the first answer") { sheet.reading.value?.title == "1" }
        FileManager.default.createFile(atPath: path("slow"), contents: Data())

        sheet.show(need: .change)

        try await wait("the failure") { told() == ["Script took too long, so Openspot stopped it."] }
        try FileManager.default.removeItem(atPath: path("slow"))
        try await wait("the stop of the slow read") { self.blocks(ids: true).contains { $0.contains("stop=2") } }
        sheet.show(need: .change)
        try await wait("the answer after the late one") { sheet.reading.value?.title == "3" }
        XCTAssertFalse(frames.frames.contains { $0.contains("title=2") })
    }

    func testASecondSlowReadStartsTheStayingScriptAgain() async throws {
        let (sheet, told) = try slowStaying()
        runs.panelOpened()
        sheet.open {}
        try await wait("the first answer") { sheet.reading.value?.title == "1" }
        FileManager.default.createFile(atPath: path("slow"), contents: Data())
        sheet.show(need: .change)
        try await wait("the first failure") { told().count == 1 }

        sheet.show(need: .change)

        try await wait("the second failure") { told().count == 2 }
        try await wait("a new process") { self.log("pids").count == 2 }
        try await wait("the answer of the new process") { sheet.reading.value?.title == "4" }
    }

    func testAReadInTimeBetweenTwoSlowReadsKeepsTheStayingScript() async throws {
        let (sheet, told) = try slowStaying()
        runs.panelOpened()
        sheet.open {}
        try await wait("the first answer") { sheet.reading.value?.title == "1" }
        FileManager.default.createFile(atPath: path("slow"), contents: Data())
        sheet.show(need: .change)
        try await wait("the first failure") { told().count == 1 }
        try FileManager.default.removeItem(atPath: path("slow"))
        try await wait("the late answer of the slow read") { self.log("answered").contains("2") }
        sheet.show(need: .change)
        try await wait("the answer in time") { sheet.reading.value?.title == "3" }
        FileManager.default.createFile(atPath: path("slow"), contents: Data())

        sheet.show(need: .change)

        try await wait("the second failure") { told().count == 2 }
        try FileManager.default.removeItem(atPath: path("slow"))
        try await wait("the late answer from the same process") { self.log("answered").contains("4") || self.log("pids").count > 1 }
        try await wait("the late answer from the same process") { self.log("answered").contains("4") }
        XCTAssertEqual(log("pids").count, 1)
    }

    func testTheFirstPartsOfAStayingScriptArriveThroughTheArrival() async throws {
        try staying(toml: "stay = true", frame: "frame=\\nclass=gap-part\\n\\ntext=a\\ntitle=A\\n")
        let sheet = try sheet()
        var arrivals = 0
        runs.partsArrival = { _, bring in
            arrivals += 1
            bring()
        }

        runs.panelOpened()
        sheet.open {}

        try await wait("the parts") { sheet.panel != nil }
        XCTAssertEqual(arrivals, 1)
    }

    func testTheRecordOfALongCallOfAStayingScriptKeepsOnlyTheFramesTheLogShows() async throws {
        runs = SpotRuns(clock: clock.value, stopPause: 0.2, log: CallLog(folder: folder.appendingPathComponent("logs"), limit: 2_000))
        nonisolated(unsafe) var kept: [Int] = []
        runs.onCall = { record in if record.arguments.first == "go" { kept.append(record.frames.count) } }
        try script(toml: "stay = true", #"""
        while IFS= read -r line; do
          case "$line" in
            call=*) id=${line#call=}; name= ;;
            arg=*) [ -n "$name" ] || name=${line#arg=} ;;
            '')
              if [ "$name" = go ]; then
                printf 'call=%s\n---\n' "$id"
                i=0; while [ $i -lt 300 ]; do printf 'frame=\ntitle=Frame %s of the long call\n---\n' "$i"; i=$((i+1)); done
                printf 'end=%s\n---\n' "$id"
              else
                printf 'button=go\ntitle=Go\nscope=spot\n\nitem=a\ntitle=A\n\nend=%s\n---\n' "$id"
              fi
              name= ;;
          esac
        done
        """#)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the action") { sheet.spot.frameActions.count == 1 }

        sheet.run(try XCTUnwrap(sheet.spot.frameActions.first), item: nil)

        try await wait("the record") { !kept.isEmpty }
        XCTAssertLessThan(kept[0], 30)
    }

    func testStoppedSearchesOfAStayingScriptLeaveNoCallBehind() async throws {
        try script(toml: "stay = true\n[on]\n\"sheet.text\" = true", #"""
        n=0
        while IFS= read -r line; do
          case "$line" in
            call=*) id=${line#call=} ;;
            '')
              n=$((n+1))
              if [ $n -eq 1 ]; then printf 'item=a\ntitle=A\n\nend=%s\n---\n' "$id"; else printf 'item=b\ntitle=B\n---\n'; fi
              ;;
          esac
        done
        """#)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        let link = try XCTUnwrap(sheet.link as? StayMode)

        for round in 1...150 {
            sheet.list.search("t\(round)")
            sheet.ask()
            try await wait("the picture of search \(round)") { link.records.keys.max().flatMap { link.records[$0] }?.isPictured == true }
        }

        XCTAssertLessThanOrEqual(link.records.values.filter { !$0.isDropped }.count, 1)
        XCTAssertLessThanOrEqual(link.records.values.filter(\.isDropped).count, StayMode.droppedLimit)
    }

    func testALateAnswerToACallPastTheLimitOfStoppedCallsChangesNothing() async throws {
        let last = StayMode.droppedLimit + 3
        try script(toml: "stay = true\n[on]\n\"sheet.text\" = true", #"""
        while IFS= read -r line; do
          case "$line" in
            call=*) id=${line#call=} ;;
            '')
              if [ "$id" = 1 ]; then printf 'item=a\ntitle=A\n\nend=1\n---\n'; fi
              if [ "$id" = \#(last) ]; then printf 'end=2\n\nitem=old\ntitle=Old\n---\nend=%s\n\nitem=fresh\ntitle=Fresh\n---\n' "$id"; id=; fi
              ;;
          esac
        done
        """#)
        let sheet = try sheet()
        nonisolated(unsafe) var shown: [[String]] = []
        let report = sheet.onReport
        sheet.onReport = {
            shown.append(sheet.list.all.map(\.run))
            report($0)
        }
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        for round in 2...last {
            sheet.list.search("t\(round)")
            sheet.ask()
        }

        try await wait("the answer after the late one") { sheet.list.all.map(\.run) == ["fresh"] }
        XCTAssertFalse(shown.contains { $0.contains("old") })
    }
}
