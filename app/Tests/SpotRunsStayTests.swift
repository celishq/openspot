import XCTest
@testable import OpenspotCore

/// Proves how a script that stays starts, takes calls and ends.
@MainActor
final class SpotRunsStayTests: SpotRunsCase {
    // MARK: Y2, Y3, Y5

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

    // MARK: Y7

    private static let ends = """
    while IFS= read -r line; do
      printf '%%s\\n' "$line" >> '%@'
      case "$line" in
        name=*) name=${line#name=} ;;
        id=*) id=${line#id=} ;;
        stop=*) touch '%@'; name=stop ;;
        '')
          case "$name" in
            stop) ;;
            go) ( while [ ! -f '%@' ]; do sleep 0.05; done; printf 'end=%%s\\n---\\n' "$id" ) & ;;
            *) printf 'action=go\\ntitle=Go\\nscope=command\\n\\nrow=A\\nrun=a\\n\\nend=%%s\\n---\\n' "$id" ;;
          esac
          name= ;;
      esac
    done
    """

    func testEachCallOfAStayingScriptHasItsOwnId() async throws {
        try staying()
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))

        try await wait("the call") { self.blocks(ids: true) == ["name=read\nid=1", "name=open\nvalue=a\nid=2"] }
    }

    func testACallRunsUntilItsEndOnceTheScriptPrintsEnds() async throws {
        try script(header: "stay=true", String(format: Self.ends, path("blocks"), path("done"), path("done")))
        let sheet = try sheet()
        sheet.open {}
        try await wait("the action") { sheet.command.actions.count == 1 }

        sheet.run(try XCTUnwrap(sheet.command.actions.first), item: nil)
        try await wait("the running call") { sheet.calls.count == 1 }
        try "".write(toFile: path("done"), atomically: true, encoding: .utf8)

        try await wait("the end") { sheet.calls.isEmpty }
    }

    func testASecondPressSendsAStopWithTheIdOfTheCall() async throws {
        try script(header: "stay=true", String(format: Self.ends, path("blocks"), path("done"), path("done")))
        let sheet = try sheet()
        sheet.open {}
        try await wait("the action") { sheet.command.actions.count == 1 }
        let action = try XCTUnwrap(sheet.command.actions.first)
        sheet.run(action, item: nil)
        try await wait("the running call") { sheet.calls.count == 1 }
        time += 2

        sheet.run(action, item: nil)

        XCTAssertTrue(sheet.calls.isEmpty)
        try await wait("the stop") { self.blocks(ids: true).last == "stop=2" }
    }

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
          printf '%s\\n' "$line" >> '\(path("asked"))'
          case "$line" in
            name=new) \(untilRelease); printf 'title=New\\n\\nfield=a\\nlabel=A\\n---\\n' ;;
            name=read) printf 'action=new\\ntitle=New\\nscope=command\\nform=true\\n---\\n' ;;
          esac
        done
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the action") { sheet.command.actions.count == 1 }
        let action = try XCTUnwrap(sheet.command.actions.first)

        async let first = sheet.form(action, item: nil)
        try await wait("the first ask") { self.log("asked").contains("name=new") }
        let second = try await sheet.form(action, item: nil)

        XCTAssertNil(second)
        openGate()
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
        try await pause(0.15)

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
        try await pause(0.1)

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
        try await pause(0.1)
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
        try await pause(0.15)

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
        runs = SpotRuns(now: { [unowned self] in self.time }, stopPause: 30, tickPause: .milliseconds(50))
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
        XCTAssertEqual(told(), ["broken", "broken"])
        runs.arrive(.wake)
        try await wait("the third failure") { told().count == 3 }
        XCTAssertEqual(told().last, Self.givenUp)
        XCTAssertEqual(log().count, 3)

        runs.arrive(.wake)
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
        try await pause(0.1)
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
        try await pause(0.1)

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
}
