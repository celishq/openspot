import XCTest
@testable import OpenspotCore

/// Proves how a script that stays starts, takes calls and ends.
@MainActor
final class SpotRunsStayTests: SpotRunsCase {
    // MARK: Modes

    private static let form = """
    while IFS= read -r line; do
      printf '%%s\\n' "$line" >> '%@'
      case "$line" in
        call=*) call=${line#call=}; name=; filled= ;;
        arg=*) [ -n "$name" ] || name=${line#arg=} ;;
        ?*) filled=1 ;;
        '')
          if [ "$name" = new ] && [ -z "$filled" ]; then
            printf 'title=New\\nend=%%s\\n\\nfield=a\\ntitle=A\\n---\\n' "$call"
          else
            printf 'end=%%s\\n\\nbutton=new\\ntitle=New\\nscope=spot\\nform=true\\n\\nrow=a\\ntitle=A\\n---\\n' "$call"
          fi
          ;;
      esac
    done
    """

    // MARK: Modes

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
            *) printf 'button=go\\ntitle=Go\\nscope=spot\\n\\nrow=a\\ntitle=A\\n\\nend=%%s\\n---\\n' "$id" ;;
          esac
          name= ;;
      esac
    done
    """

    func testEachCallOfAStayingScriptHasItsOwnId() async throws {
        try staying()
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))

        try await wait("the call") { self.blocks(ids: true) == ["call=1\narg=read\nenv.OPENSPOT_REASON=sheet.open", "call=2\narg=open\narg=a"] }
    }

    func testACallRunsUntilItsEndOnceTheScriptPrintsEnds() async throws {
        try script(header: "mode=stay", String(format: Self.ends, path("blocks"), path("done"), path("done")))
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the action") { sheet.spot.actions.count == 1 }

        sheet.run(try XCTUnwrap(sheet.spot.actions.first), item: nil)
        try await wait("the running call") { sheet.calls.count == 1 }
        try "".write(toFile: path("done"), atomically: true, encoding: .utf8)

        try await wait("the end") { sheet.calls.isEmpty }
    }

    func testASecondPressSendsAStopWithTheIdOfTheCall() async throws {
        try script(header: "mode=stay", String(format: Self.ends, path("blocks"), path("done"), path("done")))
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the action") { sheet.spot.actions.count == 1 }
        let action = try XCTUnwrap(sheet.spot.actions.first)
        sheet.run(action, item: nil)
        try await wait("the running call") { sheet.calls.count == 1 }
        time += 2

        sheet.run(action, item: nil)

        XCTAssertTrue(sheet.calls.isEmpty)
        try await wait("the stop") { self.blocks(ids: true).last == "stop=2" }
    }

    func testEachFrameWithABlockReplacesAllAndOnlyTheFrameThatEndsAReadAnswersIt() async throws {
        try script(header: "mode=stay", """
        while IFS= read -r line; do
          case "$line" in
            call=*) call=${line#call=} ;;
            '')
              printf 'text=peer\\ntitle=Early\\n---\\n'
              \(untilRelease)
              printf 'end=%s\\n\\nrow=a\\ntitle=A\\n---\\n' "$call"
              printf 'text=peer\\ntitle=Late\\n---\\n' ;;
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

    func testAPickReachesTheRunningStayingScript() async throws {
        try staying()
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))

        try await wait("the call") { self.blocks() == ["arg=read", "arg=open\narg=a"] }
        XCTAssertEqual(log().count, 1)
        XCTAssertTrue(sheet.calls.isEmpty)
    }

    func testAnActionReachesTheRunningStayingScript() async throws {
        try staying(frame: "button=go\\ntitle=Go\\n\\nrow=a\\ntitle=A\\n")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        let action = try XCTUnwrap(sheet.spot.actions.first)

        sheet.run(action, item: sheet.list.selectedItem)
        sheet.run(action, item: nil)

        try await wait("the calls") { self.blocks() == ["arg=read", "arg=go\narg=a", "arg=go"] }
        XCTAssertEqual(log().count, 1)
    }

    func testAFormOfAStayingScriptGoesAsTwoBlocks() async throws {
        try script(header: "mode=stay", String(format: Self.form, path("blocks")))
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the action") { sheet.spot.actions.count == 1 }
        let action = try XCTUnwrap(sheet.spot.actions.first)

        let asked = try await sheet.form(action, item: nil)
        let form = try XCTUnwrap(asked)
        XCTAssertEqual(form.fields.map(\.name), ["a"])
        XCTAssertEqual(sheet.spot.actions.count, 1)
        var draft = FormDraft(form: form, prefill: "")
        draft.set("one", for: "a")
        let answer = try await sheet.submit(action, item: nil, draft: draft)

        XCTAssertEqual(answer, .done)
        try await wait("the blocks") { self.blocks() == ["arg=read", "arg=new", "arg=new\ninput=a=one\\n"] }
        XCTAssertEqual(log().count, 1)
    }

    func testASecondAskForAFormOfAStayingScriptLeavesTheFirstWaiting() async throws {
        try script(header: "mode=stay", """
        while IFS= read -r line; do
          printf '%s\\n' "$line" >> '\(path("asked"))'
          case "$line" in
            call=*) call=${line#call=} ;;
            arg=new) \(untilRelease); printf 'title=New\\n\\nfield=a\\ntitle=A\\n---\\n' ;;
            arg=read) printf 'end=%s\\n\\nbutton=new\\ntitle=New\\nscope=spot\\nform=true\\n---\\n' "$call" ;;
          esac
        done
        """)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the action") { sheet.spot.actions.count == 1 }
        let action = try XCTUnwrap(sheet.spot.actions.first)

        async let first = sheet.form(action, item: nil)
        try await wait("the first ask") { self.log("asked").contains("arg=new") }
        let second = try await sheet.form(action, item: nil)

        XCTAssertNil(second)
        openGate()
        let form = try await first
        XCTAssertEqual(form?.fields.map(\.name), ["a"])
    }

    func testAFormOfAStayingScriptThatEndsIsABadForm() async throws {
        try script(header: "mode=stay", """
        while IFS= read -r line; do
          case "$line" in
            call=*) call=${line#call=} ;;
            arg=new) exit 0 ;;
            arg=read) printf 'end=%s\\n\\nbutton=new\\ntitle=New\\nscope=spot\\nform=true\\n---\\n' "$call" ;;
          esac
        done
        """)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the action") { sheet.spot.actions.count == 1 }
        let action = try XCTUnwrap(sheet.spot.actions.first)

        do {
            _ = try await sheet.form(action, item: nil)
            XCTFail("It should have no form.")
        } catch {
            XCTAssertEqual(error as? SpotError, .badForm)
        }
    }

    func testASearchReachesTheRunningStayingScript() async throws {
        try staying(header: "mode=stay\non=sheet.text", frame: "row=a\\ntitle=A\\n")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.search("rep")

        try await wait("the search") { self.blocks() == ["arg=read", "arg=read\ninput=search=rep\\n"] }
        try await wait("the answer") { !sheet.list.isWaiting }
        XCTAssertEqual(log().count, 1)
    }

    /// A staying script that answers each text of the main search with one row of that text, and a stop with nothing.
    private var answering: String {
        """
        while IFS= read -r line; do
          printf '%s\\n' "$line" >> '\(path("blocks"))'
          case "$line" in
            call=*) call=${line#call=}; n=0; text= ;;
            stop=*) call= ;;
            env.OPENSPOT_VALUE=*) text=${line#env.OPENSPOT_VALUE=} ;;
          esac
          [ -n "$line" ] || [ -z "$call" ] || {
            if [ -n "$text" ]; then printf 'end=%s\\n\\nrow=%s\\ntitle=%s\\n---\\n' "$call" "$text" "$text"; else printf 'end=%s\\n---\\n' "$call"; fi
          }
        done
        """
    }

    func testAStayingScriptAnswersTheMainSearchWithOnlyTheNewestOfFiveFastTexts() async throws {
        try script(header: "mode=stay\non=search.text ^[0-9]", answering)
        let sheet = try sheet()
        runs.panelOpened()
        var shown: [[String]] = []
        sheet.onReport = { if case .listChange = $0 { shown.append(sheet.answers.map(\.run)) } }

        for text in ["1", "12", "123", "1234", "12345"] { sheet.answer(text) }

        try await wait("the newest answer") { sheet.answers.map(\.run) == ["12345"] }
        try await wait("each older text stopped") { self.blocks().filter { $0.hasPrefix("stop=") }.count == 4 }
        try await pause()
        XCTAssertEqual(shown, [["12345"]])
        XCTAssertEqual(log().count, 1)
    }

    func testAnAnswerOfAStayingScriptThatEndsIsNoLongerAwaited() async throws {
        try script(header: "mode=stay\non=search.text ^[0-9]", "while IFS= read -r line; do [ \"$line\" = env.OPENSPOT_VALUE=12 ] && exit 1; done")
        let sheet = try sheet()
        runs.panelOpened()

        sheet.answer("12")

        try await wait("the end of the answer") { !sheet.isAnswering }
        XCTAssertEqual(sheet.answers, [])
    }

    func testThePictureOfAStayingScriptIsNoAnswerOfTheSearch() async throws {
        try script(header: "mode=always\non=search.text ^[0-9]\non=panel.open", """
        while IFS= read -r line; do
          case "$line" in call=*) call=${line#call=} ;; arg=12) printf 'row=clock\\ntitle=Clock\\n---\\n' ;; esac
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
        # mode=stay
        # on=sheet.open
        # on=search.text ^[0-9]
        . "$OPENSPOT_SH"
        main() {
          case "$1" in
            read) if [ -n "$OPENSPOT_VALUE" ]; then printf 'row=%s\\ntitle=Is %s\\n' "$OPENSPOT_VALUE" "$OPENSPOT_VALUE"; else printf 'row=a\\ntitle=A\\n'; fi ;;
          esac
        }
        openspot_serve main "$@"
        """.writeScript(to: folder.spotFile("script"))
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row of the sheet") { sheet.list.shown.map(\.run) == ["a"] }

        sheet.answer("12")

        try await wait("the answer") { sheet.answers.map(\.run) == ["12"] }
        XCTAssertEqual(sheet.list.shown.map(\.run), ["a"])
    }

    func testACardCallOfAStayingScriptReachesIt() async throws {
        try staying()
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.pressCard()

        try await wait("the call") { self.blocks().count == 2 }
        try await wait("the end of the call") { !sheet.isCardRunning }
        XCTAssertEqual(log().count, 1)
    }

    func testAStayingMenuBarScriptRunsWithThePanelClosedAndItsFrameReachesTheMenuBar() async throws {
        menuBar.insert("script")
        try staying(header: "mode=stay", frame: "text=n\\ntitle=3\\n")
        _ = try scanned()

        try await wait("the mark") { self.runs.menuBarMarks.first?.mark.summary == "Script: 3" }

        XCTAssertFalse(runs.isPanelOpen)
        XCTAssertEqual(log().count, 1)
        XCTAssertEqual(blocks(), ["arg=read"])
    }

    func testAStayingMenuBarScriptGoesOnWhenItsSheetAndThePanelCloseAndAScanComes() async throws {
        menuBar.insert("script")
        try staying(header: "mode=stay", frame: "text=n\\ntitle=3\\n\\nrow=a\\ntitle=A\\n")
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

        try await wait("the call") { self.blocks().last == "arg=open\narg=a" }
        XCTAssertEqual(log().count, 1)
    }

    func testAFrameOfAStayingMenuBarScriptIsItsWholePictureAndChangesItsMark() async throws {
        menuBar.insert("script")
        try script(header: "mode=stay", """
        while IFS= read -r line; do
          case "$line" in
            call=*) call=${line#call=} ;;
            arg=read) printf 'end=%s\\n\\ntext=n\\ntitle=3\\n---\\n' "$call" ;;
            arg=open) printf 'text=n\\ntitle=4\\n---\\n' ;;
          esac
        done
        """)
        let sheet = try sheet()
        try await wait("the mark") { !self.runs.menuBarMarks.isEmpty }

        sheet.pick(SpotItem(title: "A", run: "a"))

        try await wait("the new mark") { self.runs.menuBarMarks.first?.mark.summary == "Script: 4" }
        XCTAssertEqual(runs.menuBarMarks.first?.mark.isStale, false)
    }

    func testASheetOfARunningStayingScriptOpensAtOnceWithItsLastFrame() async throws {
        menuBar.insert("script")
        try staying(header: "mode=stay", head: "main=n\\n", frame: "text=n\\ntitle=3\\n\\ntext=a\\ntitle=A\\n")
        let sheet = try sheet()
        try await wait("the mark") { !self.runs.menuBarMarks.isEmpty }
        XCTAssertNil(sheet.panel)
        var isReady = false

        sheet.open { isReady = true }

        XCTAssertTrue(isReady)
        XCTAssertEqual(sheet.panel?.parts.map(\.id), ["n", "a"])
        XCTAssertEqual(log().count, 1)
    }

    func testAStayingScriptIsWantedByThePanelOnlyWhileItIsOpen() async throws {
        try staying(header: "mode=stay\non=panel.open")
        let sheet = try sheet()
        try await pause(0.1)
        XCTAssertEqual(log(), [])

        runs.panelOpened()
        try await wait("the frame") { sheet.list.shown.count == 1 }
        XCTAssertEqual(blocks(), ["arg=read"])

        runs.panelClosed()
        try await wait("the end") { self.exists("ended") }
        XCTAssertEqual(log().count, 1)
    }

    func testAStayingScriptWithAlwaysRunsFromTheStartWithNothingThatWantsIt() async throws {
        try staying(header: "mode=always")
        let sheet = try sheet()

        try await wait("the frame") { sheet.list.shown.count == 1 }
        XCTAssertEqual(blocks(ids: true), ["call=1\narg=read\nenv.OPENSPOT_REASON=panel.open"])

        runs.panelOpened()
        runs.panelClosed()
        runs.woke()
        try await pause(0.15)

        XCTAssertFalse(exists("ended"))
        XCTAssertEqual(log().count, 1)
    }

    func testAStayingScriptThatNothingWantsDoesNotStartOnAWake() async throws {
        try staying(header: "mode=stay\non=clock.600")
        _ = try scanned()

        runs.woke()
        try await pause(0.15)

        XCTAssertEqual(log(), [])
    }

    func testAStayingScriptWithANumberGetsAReadOnItsTimer() async throws {
        menuBar.insert("script")
        try staying(header: "mode=stay\non=clock.5", frame: "text=n\\ntitle=3\\n")
        _ = try scanned()
        try await wait("the mark") { !self.runs.menuBarMarks.isEmpty }
        XCTAssertEqual(blocks(), ["arg=read"])

        time += 5
        runs.raise(.clock)

        try await wait("the read") { self.blocks() == ["arg=read", "arg=read"] }
        XCTAssertEqual(log().count, 1)
    }

    func testAStayingScriptThatEndedStartsAgainAtTheNextMoment() async throws {
        menuBar.insert("script")
        try script(header: "mode=stay", """
        [ -f '\(path("second"))' ] || { touch '\(path("second"))'; printf 'end=1\\n\\ntext=n\\ntitle=1\\n'; exit 0; }
        while IFS= read -r line; do
          case "$line" in call=*) call=${line#call=} ;; esac
          [ -n "$line" ] || printf 'end=%s\\n\\ntext=n\\ntitle=2\\n---\\n' "$call"
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
        runs = SpotRuns(now: { [unowned self] in self.time }, stopPause: 30, tickPause: .milliseconds(50))
        try staying()
        let sheet = try sheet()

        sheet.pick(SpotItem(title: "A", run: "a"))

        try await wait("the end") { self.exists("ended") }
        XCTAssertEqual(blocks(), ["arg=read", "arg=open\narg=a"])
        XCTAssertEqual(log().count, 1)
    }

    func testAStayingScriptThatLeavesTheFolderEnds() async throws {
        menuBar.insert("script")
        let url = try staying(header: "mode=stay", frame: "text=n\\ntitle=3\\n")
        _ = try scanned()
        try await wait("the mark") { !self.runs.menuBarMarks.isEmpty }

        try FileManager.default.removeItem(at: url)
        _ = try scanned()

        try await wait("the end") { self.exists("ended") }
    }

    private static let givenUp = "Script failed 3 times in one minute. Openspot will not start it again until its file changes."

    func testThreeQuickFailuresStopNewStartsAndTellThePersonOnce() async throws {
        menuBar.insert("script")
        try script(header: "mode=stay", "echo broken >&2\nexit 1")
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
        try script(header: "mode=stay", "echo broken >&2\nexit 1")
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
        try script(header: "mode=stay", "echo broken >&2\nexit 1")
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
        try staying(header: "mode=stay", frame: "text=n\\ntitle=3\\n")
        _ = try scanned()

        try await wait("the mark") { self.runs.menuBarMarks.first?.mark.summary == "Script: 3" }
        XCTAssertEqual(log().count, 4)
    }

    func testASheetOfAStoppedScriptDoesNotOpen() async throws {
        menuBar.insert("script")
        try script(header: "mode=stay", "exit 1")
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
        try script(header: "mode=stay", "exit 1")
        let sheet = try sheet()
        var isReady = false

        sheet.open { isReady = true }
        try await wait("the end") { !sheet.isOpen }

        XCTAssertFalse(isReady)
    }

    func testASheetClosedBeforeItsAnswerOpensAgainWithAFreshAnswer() async throws {
        try script(header: "mode=stay", """
        while IFS= read -r line; do
          case "$line" in
            call=*) call=${line#call=} ;;
            '') \(untilRelease); printf 'end=%s\\n\\nrow=a\\ntitle=A\\n---\\n' "$call" ;;
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
        try script(header: "mode=stay\non=sheet.text", """
        while IFS= read -r line; do
          printf '%s\\n' "$line" >> '\(path("blocks"))'
          case "$line" in
            call=*) call=${line#call=}; args= ;;
            arg=*) args="$args ${line#arg=}" ;;
            env.OPENSPOT_VALUE=*) args="$args ${line#env.OPENSPOT_VALUE=}" ;;
            stop=*) touch '\(path("stopped"))'; args=stop ;;
            '')
              case "$args" in
                ' read a') ( \(untilRelease); printf 'end=%s\\n\\nrow=o\\ntitle=Old\\n---\\n' "$call"; printf 'toast=Done\\n---\\n' ) & ;;
                ' read ab') printf 'end=%s\\n\\nrow=n\\ntitle=New\\n---\\n' "$call" ;;
                ' read') printf 'end=%s\\n\\nrow=x\\ntitle=X\\n---\\n' "$call" ;;
              esac ;;
          esac
        done
        """)
        let sheet = try sheet()
        let frames = FrameLog(sheet)
        runs.panelOpened()
        sheet.open {}
        try await wait("the first rows") { sheet.list.search == .script && sheet.list.shown.count == 1 }
        sheet.search("a")
        try await wait("the older search") { self.blocks().contains("arg=read\ninput=search=a\\n") }

        sheet.search("ab")

        try await wait("the newer answer") { sheet.list.shown.map(\.run) == ["n"] }
        XCTAssertTrue(exists("stopped"))
        openGate()
        try await wait("the frame after the late answer") { frames.last?.contains("Done") == true }
        XCTAssertEqual(sheet.list.shown.map(\.run), ["n"])
    }
    /// New runs whose read has `limit` seconds, and a staying script whose first process busy-waits 5 seconds on each call
    /// while the file `slow` exists, then answers with the number of the call as its title.
    private func slowStaying(limit: TimeInterval = 1) throws -> (sheet: SpotRun, told: () -> [String]) {
        runs.quit()
        runs = SpotRuns(readLimit: limit, now: { [unowned self] in self.time }, stopPause: 0.2, tickPause: .milliseconds(50))
        try script(header: "mode=stay\non=sheet.open", """
        first=; [ -f '\(path("started"))' ] || first=1; touch '\(path("started"))'
        while IFS= read -r line; do
          printf '%s\\n' "$line" >> '\(path("blocks"))'
          case "$line" in call=*) call=${line#call=} ;; stop=*) call= ;; esac
          if [ -z "$line" ] && [ -n "$call" ]; then
            if [ -n "$first" ] && [ -f '\(path("slow"))' ]; then end=$(($(date +%s) + 5)); while [ "$(date +%s)" -lt "$end" ]; do :; done; fi
            printf 'end=%s\\n\\ntext=t\\ntitle=%s\\n---\\n' "$call" "$call"
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

        sheet.read(need: .change)

        try await wait("the failure") { told() == ["Script took too long, so Openspot stopped it."] }
        try await wait("the stop of the slow read") { self.blocks(ids: true).contains { $0.contains("stop=2") } }
        try FileManager.default.removeItem(atPath: path("slow"))
        sheet.read(need: .change)
        try await wait("the answer after the late one") { sheet.reading.value?.title == "3" }
        XCTAssertFalse(frames.frames.contains { $0.contains("title=2") })
    }

    func testASecondSlowReadStartsTheStayingScriptAgain() async throws {
        let (sheet, told) = try slowStaying()
        runs.panelOpened()
        sheet.open {}
        try await wait("the first answer") { sheet.reading.value?.title == "1" }
        FileManager.default.createFile(atPath: path("slow"), contents: Data())
        sheet.read(need: .change)
        try await wait("the first failure") { told().count == 1 }

        sheet.read(need: .change)

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
        sheet.read(need: .change)
        try await wait("the first failure") { told().count == 1 }
        try FileManager.default.removeItem(atPath: path("slow"))
        try await wait("the late answer of the slow read") { self.log("answered").contains("2") }
        sheet.read(need: .change)
        try await wait("the answer in time") { sheet.reading.value?.title == "3" }
        FileManager.default.createFile(atPath: path("slow"), contents: Data())

        sheet.read(need: .change)

        try await wait("the second failure") { told().count == 2 }
        try await wait("the late answer from the same process") { self.log("answered").contains("4") || self.log("pids").count > 1 }
        try await wait("the late answer from the same process") { self.log("answered").contains("4") }
        XCTAssertEqual(log("pids").count, 1)
    }

    func testTheFirstPartsOfAStayingScriptArriveThroughTheArrival() async throws {
        try staying(frame: "text=a\\ntitle=A\\n")
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

    // MARK: Bounds

    func testTheRecordOfALongCallOfAStayingScriptKeepsOnlyTheFramesTheLogShows() async throws {
        runs = SpotRuns(now: { [unowned self] in self.time }, stopPause: 0.2, tickPause: .milliseconds(50), log: CallLog(folder: folder.appendingPathComponent("logs"), limit: 2_000))
        nonisolated(unsafe) var kept: [Int] = []
        runs.onCall = { record, _ in if record.arguments.first == "go" { kept.append(record.frames.count) } }
        try script(header: "mode=stay", #"""
        while IFS= read -r line; do
          case "$line" in
            call=*) id=${line#call=}; name= ;;
            arg=*) [ -n "$name" ] || name=${line#arg=} ;;
            '')
              if [ "$name" = go ]; then
                printf 'call=%s\n---\n' "$id"
                i=0; while [ $i -lt 300 ]; do printf 'title=Frame %s of the long call\n---\n' "$i"; i=$((i+1)); done
                printf 'end=%s\n---\n' "$id"
              else
                printf 'button=go\ntitle=Go\nscope=spot\n\nrow=a\ntitle=A\n\nend=%s\n---\n' "$id"
              fi
              name= ;;
          esac
        done
        """#)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the action") { sheet.spot.actions.count == 1 }

        sheet.run(try XCTUnwrap(sheet.spot.actions.first), item: nil)

        try await wait("the record") { !kept.isEmpty }
        XCTAssertLessThan(kept[0], 30)
    }

    func testStoppedSearchesOfAStayingScriptLeaveNoCallBehind() async throws {
        try script(header: "mode=stay\non=sheet.text", #"""
        n=0
        while IFS= read -r line; do
          case "$line" in
            call=*) id=${line#call=} ;;
            '')
              n=$((n+1))
              if [ $n -eq 1 ]; then printf 'row=a\ntitle=A\n\nend=%s\n---\n' "$id"; else printf 'row=b\ntitle=B\n---\n'; fi
              ;;
          esac
        done
        """#)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }
        let link = try XCTUnwrap(sheet.link as? StayLink)

        for round in 1...150 {
            sheet.list.search("t\(round)")
            sheet.ask()
            try await wait("the picture of search \(round)") { link.sent.keys.max().map(link.pictured.contains) == true }
        }

        XCTAssertLessThanOrEqual(link.sent.count, 1)
        XCTAssertLessThanOrEqual(link.pictured.count, 1)
        XCTAssertLessThanOrEqual(link.dropped.count, StayLink.droppedLimit)
    }

    func testALateAnswerToACallPastTheLimitOfStoppedCallsChangesNothing() async throws {
        let last = StayLink.droppedLimit + 3
        try script(header: "mode=stay\non=sheet.text", #"""
        while IFS= read -r line; do
          case "$line" in
            call=*) id=${line#call=} ;;
            '')
              if [ "$id" = 1 ]; then printf 'row=a\ntitle=A\n\nend=1\n---\n'; fi
              if [ "$id" = \#(last) ]; then printf 'end=2\n\nrow=old\ntitle=Old\n---\ntoast=done\n---\n'; id=; fi
              ;;
          esac
        done
        """#)
        let sheet = try sheet()
        nonisolated(unsafe) var toasts: [String] = []
        let report = sheet.onReport
        sheet.onReport = {
            if case .toast(let text) = $0 { toasts.append(text) }
            report($0)
        }
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        for round in 2...last {
            sheet.list.search("t\(round)")
            sheet.ask()
        }

        try await wait("the late answer") { toasts == ["done"] }
        XCTAssertEqual(sheet.list.all.map(\.run), ["a"])
    }
}
