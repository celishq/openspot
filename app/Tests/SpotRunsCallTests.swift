import XCTest
@testable import OpenspotCore

/// Proves how long a call runs, how a call stops, and how a big value reaches a script.
@MainActor
final class SpotRunsCallTests: SpotRunsCase {
    // MARK: Section 7

    func testAReadAtThePanelThatTakesTooLongMarksItsCardAndTellsNoOne() async throws {
        runs = SpotRuns(readLimit: 0.3)
        try script(header: "on=panel.open", "sleep 30")
        let sheet = try sheet()
        var failures: [String] = []
        sheet.onReport = { if case .failure(let text) = $0 { failures.append(text) } }

        sheet.read()

        try await wait("the time limit") { sheet.failure != nil }
        XCTAssertEqual(sheet.failure, "Script took too long, so Openspot stopped it.")
        XCTAssertEqual(failures, [])
    }

    func testAReadHasTenSecondsAndAnyOtherNameHasNoLimit() async throws {
        XCTAssertEqual(SpotRuns().readLimit, 10)
        runs = SpotRuns(readLimit: 1.5)
        try script(header: "on=sheet.open", """
        case "$1" in
          read) [ -f '\(path("slow"))' ] && sleep 30; touch '\(path("slow"))'; printf 'title=1\\n\\nrow=a\\ntitle=A\\n' ;;
          open) \(untilRelease); touch '\(path("done"))' ;;
        esac
        """)
        let sheet = try sheet()
        var failures: [String] = []
        sheet.onReport = { if case .failure(let text) = $0 { failures.append(text) } }
        sheet.read()
        try await wait("the row") { sheet.list.shown.count == 1 }
        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))
        try await wait("the work") { self.log().contains("open a") }

        sheet.read(need: .change)
        try await wait("the time limit") { !failures.isEmpty }
        XCTAssertEqual(failures, ["Script took too long, so Openspot stopped it."])
        XCTAssertEqual(sheet.list.shown.count, 1)
        XCTAssertEqual(sheet.reading.value?.title, "1")
        XCTAssertTrue(sheet.reading.isStale)

        XCTAssertFalse(sheet.calls.isEmpty)
        openGate()
        try await wait("the end of the work") { self.exists("done") }
    }

    func testAFailedTimerReadKeepsTheValueAndDimsWithNoToast() async throws {
        menuBar.insert("script")
        try script(header: "on=clock.5\noffers=card\noffers=menubar", """
        [ -f '\(path("second"))' ] && exit 1
        touch '\(path("second"))'
        printf 'text=m\\ntitle=3\\n'
        """)
        let sheet = try sheet()
        var failures: [String] = []
        sheet.onReport = { if case .failure(let text) = $0 { failures.append(text) } }
        try await wait("the value") { sheet.reading.value?.title == "3" && sheet.calls.isEmpty }
        XCTAssertFalse(sheet.reading.isStale)
        XCTAssertEqual(runs.menuBarMarks.first?.mark.isStale, false)

        time += 5
        runs.raise(.clock)

        try await wait("the dim") { sheet.reading.isStale }
        XCTAssertEqual(sheet.reading.value?.title, "3")
        XCTAssertEqual(runs.menuBarMarks.first?.mark.isStale, true)
        XCTAssertEqual(failures, [])
    }

    func testAFailedCallAlwaysTellsThePerson() async throws {
        try script(body: "echo gone >&2\nexit 2")
        let sheet = try sheet()
        var failures: [String] = []
        sheet.onReport = { if case .failure(let text) = $0 { failures.append(text) } }

        sheet.pressCard()

        try await wait("the failure") { failures == ["gone"] }
    }

    func testAFailedCallThatPrintsALinkTellsThePersonWithItsFix() async throws {
        try script(body: "printf 'link=x-apple.systempreferences:pane\\n'\necho 'Allow it.' >&2\nexit 1")
        let sheet = try sheet()
        var fixes: [String] = []
        sheet.onReport = { if case .failureWithFix(let text, let fix) = $0 { fixes.append("\(text) \(fix.absoluteString)") } }

        sheet.pressCard()

        try await wait("the failure") { fixes == ["Allow it. x-apple.systempreferences:pane"] }
    }

    func testWhatASheetPrintsDuringItsOpenMotionShowsWhenTheMotionEnds() async throws {
        runs.quit()
        runs = SpotRuns(opening: SheetOpening(motionLength: 30), stopPause: 0.2)
        try script(header: "on=sheet.open", "printf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        runs.opening.moving = "script"
        sheet.open {}
        try await allEnded()
        try await pause(0.2)

        XCTAssertEqual(sheet.list.shown.count, 0)
        runs.opening.moving = nil

        try await wait("the rows") { sheet.list.shown.count == 1 }
    }

    func testASheetOfRowsSaysItsKindWhileItsFirstAnswerWaitsForTheOpenMotion() async throws {
        runs.quit()
        runs = SpotRuns(opening: SheetOpening(motionLength: 30), stopPause: 0.2)
        try script(header: "on=sheet.open", "printf 'repeat=a\\n\\nrow=a\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        runs.opening.moving = "script"
        sheet.open {}
        XCTAssertEqual(sheet.kind, .waiting)

        try await wait("the kind") { sheet.kind == .rows }
        XCTAssertNil(sheet.panel)
        XCTAssertEqual(sheet.list.shown.count, 0)
        runs.opening.moving = nil
    }

    func testASheetOfPartsWithNoRowsSaysItsKindWhileItsFirstAnswerWaitsForTheOpenMotion() async throws {
        runs.quit()
        runs = SpotRuns(opening: SheetOpening(motionLength: 30), stopPause: 0.2)
        try script(header: "on=sheet.open", "printf 'text=a\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        runs.opening.moving = "script"
        sheet.open {}
        try await allEnded()
        try await pause(0.2)

        XCTAssertNil(sheet.panel)
        XCTAssertEqual(sheet.kind, .parts)
        runs.opening.moving = nil
        try await wait("the parts") { sheet.panel != nil }
        XCTAssertEqual(sheet.kind, .parts)
    }

    func testASheetForgetsTheKindOfAHeldAnswerThatItsStoppedReadDrops() async throws {
        runs.quit()
        runs = SpotRuns(opening: SheetOpening(motionLength: 30), stopPause: 0.2)
        try script(header: "on=sheet.open", "printf 'text=a\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        runs.opening.moving = "script"
        sheet.open {}
        try await wait("the kind") { sheet.kind == .parts }

        runs.panelClosed()
        runs.opening.moving = nil
        try await allEnded()
        try await pause(0.2)

        XCTAssertNil(sheet.panel)
        XCTAssertEqual(sheet.kind, .rows)
    }

    func testWhatASheetPrintsShowsAfterTheLengthOfItsOpenMotionThoughItsSpringSettlesLater() async throws {
        try script(header: "on=sheet.open", "printf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        runs.opening.moving = "script"

        sheet.open {}

        try await wait("the rows") { sheet.list.shown.count == 1 }
        XCTAssertNil(runs.opening.moving)
    }

    func testTheOpenMotionOfAnotherSheetHoldsNothingOfThisOne() async throws {
        try script(header: "on=sheet.open", "printf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        runs.opening.moving = "other"

        sheet.open {}

        try await wait("the rows") { sheet.list.shown.count == 1 }
    }

    func testAReadStopsWhenThePanelThatWantedItCloses() async throws {
        try script(header: "on=panel.open\noffers=search", "printf 'row=a\\ntitle=A\\n---\\n'\nsleep 5\ntouch '\(path("went-on"))'")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the first frame") { sheet.list.shown.count == 1 }

        runs.panelClosed()
        try await allEnded()

        XCTAssertFalse(exists("went-on"))
        XCTAssertEqual(sheet.calls.count, 0)
    }

    func testClosingASheetLeavesAReadThatThePanelWants() async throws {
        try script(header: "on=panel.open\noffers=search", "sleep 0.2\nprintf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}

        sheet.close()

        try await wait("the row") { sheet.list.shown.count == 1 }
    }

    func testAStreamThatNothingWantsStopsAfterItsFirstFrame() async throws {
        try script(header: "on=sheet.open", "printf 'row=a\\ntitle=A\\n---\\n'\nsleep 5\ntouch '\(path("went-on"))'")
        let sheet = try sheet()

        sheet.read()
        try await wait("the row") { sheet.list.shown.count == 1 }
        try await allEnded()

        XCTAssertFalse(exists("went-on"))
    }

    func testAProcessThatEndedIsLetGoWithNoLaterCall() async throws {
        try script(header: "on=sheet.open", "printf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()

        sheet.read()

        try await wait("the row") { sheet.list.shown.count == 1 && sheet.calls.isEmpty }
        try await wait("no process kept") { self.runs.processes.isEmpty }
    }

    func testAStoppedReadChangesNothing() async throws {
        try script(header: "on=sheet.open", """
        [ -f '\(path("second"))' ] && { sleep 5; exit 0; }
        touch '\(path("second"))'
        printf 'row=a\\ntitle=A\\n'
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 && sheet.calls.isEmpty }
        sheet.read(need: .change)
        XCTAssertFalse(sheet.calls.isEmpty)

        sheet.close()
        try await wait("the end of the read") { sheet.calls.isEmpty }
        try await pause(0.1)

        XCTAssertEqual(sheet.list.shown.count, 1)
        XCTAssertFalse(sheet.list.hasFailed)
    }

    private static let worker = """
    case "$1" in
      read) printf 'title=Sheet\\ngrid=go\\ngrid=bar\\n\\nbutton=go\\ntitle=Go\\n\\ntext=bar\\ntitle=idle\\n' ;;
      go)
        printf 'toast=Started\\n\\ntext=bar\\ntitle=half\\n---\\n'
        sleep 0.3
        touch '%@'
        printf 'toast=Done\\n\\ntext=bar\\ntitle=done\\n'
        ;;
    esac
    """

    func testAWorkCallGoesOnWithTheSheetAndThePanelClosedAndItsLastPictureStands() async throws {
        try script(header: "on=sheet.open", String(format: Self.worker, path("done")))
        let sheet = try sheet()
        var toasts: [String] = []
        sheet.onReport = { if case .toast(let text) = $0 { toasts.append(text) } }
        let frames = FrameLog(sheet)
        sheet.open {}
        try await wait("the part") { sheet.panel != nil && sheet.calls.isEmpty }

        sheet.press(try XCTUnwrap(sheet.panel?.parts.first))
        try await wait("the first frame") { sheet.panel?.parts.map(\.title) == ["half"] }
        let call = try XCTUnwrap(sheet.calls.first)
        XCTAssertTrue(call.doesWork)
        XCTAssertEqual(call.action.arguments, ["go"])
        sheet.close()
        runs.panelClosed()
        XCTAssertEqual(sheet.calls.count, 1)

        try await wait("the end of the work") { self.exists("done") && sheet.calls.isEmpty }
        XCTAssertEqual(toasts, ["Started", "Done"])
        XCTAssertEqual(frames.last, "toast=Done\n\ntext=bar\ntitle=done\n")
        XCTAssertEqual(sheet.panel?.parts.map(\.title) ?? ["done"], ["done"])
    }

    func testAFrameOfAPickWithNoOpenSheetIsTheWholePicture() async throws {
        try script(header: "on=panel.open", """
        case "$1" in
          read) printf 'detail=Idle\\n\\nrow=a\\ntitle=A\\n\\ntext=bar\\ntitle=idle\\n' ;;
          open) printf 'toast=Saved\\ntitle=Other\\nactive=true\\n\\ntext=bar\\ntitle=work\\n' ;;
        esac
        """)
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the state") { sheet.state.subtitle == "Idle" }
        sheet.open {}
        sheet.close()
        var toasts: [String] = []
        sheet.onReport = { if case .toast(let text) = $0 { toasts.append(text) } }

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))

        try await wait("the toast") { toasts == ["Saved"] }
        try await wait("the new state") { sheet.state.on == true }
        XCTAssertEqual(sheet.state.title, "Other")
        XCTAssertEqual(sheet.list.shown.map(\.run), [])
    }

    func testOpeningASheetWhileACallRunsShowsItsRead() async throws {
        try script(header: "on=sheet.open", """
        case "$1" in
          read) printf 'grid=go\\ngrid=note\\ngrid=bar\\n\\nbutton=go\\ntitle=Go\\n\\nfield=note\\nvalue=\\n\\ntext=bar\\ntitle=idle\\n' ;;
          go) printf 'title=Half\\nprogress=0.5\\n---\\n'; sleep 30 ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the part") { sheet.panel != nil }
        sheet.press(try XCTUnwrap(sheet.panel?.parts.first))
        try await wait("the progress") { sheet.calls.first?.fill == 0.5 }
        sheet.close()
        runs.panelClosed()
        XCTAssertNil(sheet.panel)

        sheet.open {}

        try await wait("the read") { sheet.panel?.parts.last?.title == "idle" }
        XCTAssertEqual(sheet.calls.filter(\.doesWork).first?.fill, 0.5)
    }

    func testANewValueStopsTheOlderCallOfThatPartAndNoOther() async throws {
        try script(header: "on=sheet.open", """
        case "$1" in
          read) printf 'switch=a\\nvalue=false\\n\\nswitch=b\\nvalue=false\\n\\ntext=out\\ntitle=none\\n' ;;
          a) [ "$2" = true ] && { sleep 30; touch '\(path("old-a"))'; exit 0; }; touch '\(path("new-a"))'; printf 'switch=a\\nvalue=false\\n\\nswitch=b\\nvalue=true\\n\\ntext=out\\ntitle=new\\n' ;;
          b) \(untilRelease); touch '\(path("b"))'; printf 'switch=a\\nvalue=false\\n\\nswitch=b\\nvalue=true\\n\\ntext=out\\ntitle=b\\n' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the parts") { sheet.panel != nil }
        let parts = try XCTUnwrap(sheet.panel?.parts)

        sheet.set(parts[1], to: "true")
        sheet.set(parts[0], to: "true")
        try await wait("the first call of a") { self.log().contains("a true") }
        sheet.set(parts[0], to: "false")

        try await wait("the new call of a") { sheet.panel?.parts[2].title == "new" }
        openGate()
        try await wait("the end of b") { self.exists("b") && sheet.calls.isEmpty }
        try await allEnded()
        XCTAssertTrue(exists("new-a"))
        XCTAssertFalse(exists("old-a"))
        XCTAssertEqual(sheet.panel?.parts[0].value, "false")
    }

    func testAnOlderCallOfAnotherPartLeavesAPartThatChangedSince() async throws {
        try script(header: "on=sheet.open", """
        case "$1" in
          read) printf 'switch=a\\nvalue=%s\\n\\nswitch=b\\nvalue=%s\\n' "$(cat '\(path("a"))' 2>/dev/null || echo false)" "$(cat '\(path("b"))' 2>/dev/null || echo false)" ;;
          a) sleep 0.2; echo "$2" > '\(path("a"))'; printf 'switch=a\\nvalue=true\\n\\nswitch=b\\nvalue=false\\n' ;;
          b) echo "$2" > '\(path("b"))'; printf 'switch=a\\nvalue=false\\n\\nswitch=b\\nvalue=true\\n' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the parts") { sheet.panel != nil }
        let parts = try XCTUnwrap(sheet.panel?.parts)

        sheet.set(parts[0], to: "true")
        sheet.set(parts[1], to: "true")
        try await wait("the read after the older call") { sheet.calls.isEmpty && self.log().count >= 4 }

        XCTAssertEqual(sheet.panel?.parts[1].value, "true")
    }

    func testASecondPressOfARunningPartStopsItAndChangesNothing() async throws {
        try script(header: "on=sheet.open", """
        case "$1" in
          read) printf 'grid=go\\n\\nbutton=go\\ntitle=Go\\n' ;;
          go) sleep 5; touch '\(path("went-on"))' ;;
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
        try await allEnded()

        XCTAssertFalse(exists("went-on"))
        XCTAssertEqual(log(), ["read", "go"])
    }

    func testASecondPressOfARunningActionStopsIt() async throws {
        try script(header: "on=sheet.open", """
        case "$1" in
          read) printf 'button=go\\ntitle=Go\\nscope=spot\\n\\nrow=a\\ntitle=A\\n' ;;
          go) sleep 5; touch '\(path("went-on"))' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the action") { sheet.spot.actions.count == 1 }
        let action = try XCTUnwrap(sheet.spot.actions.first)

        sheet.run(action, item: nil)
        try await wait("the call") { self.log() == ["read", "go"] }
        time += 1
        sheet.run(action, item: nil)
        try await allEnded()

        XCTAssertFalse(exists("went-on"))
        XCTAssertEqual(log(), ["read", "go"])
    }

    func testAStoppedToggleGoesBack() async throws {
        try script(header: "on=panel.open", "[ \"$1\" = read ] && { printf 'switch=power\\nvalue=false\\n'; exit 0; }\nsleep 5")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the kind") { sheet.spot.kind == .toggle }

        sheet.pressCard()
        XCTAssertEqual(sheet.state.on, true)
        time += 1
        sheet.pressCard()

        try await wait("the old state") { sheet.state.on == false }
    }

    // MARK: The calls

    private static let big = String(repeating: "line \\ one=two\n", count: 2_000_000 / 15)

    func testATwoMegabyteValueOfAPartIsLeftOutOfTheArgumentsAndStdinHoldsIt() async throws {
        try script(header: "on=sheet.open", """
        case "$1" in
          read) printf 'field=input\\nvalue=\\n' ;;
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

        let text = try await runs.answer(of: Spot(id: "script", name: "Script", url: url), .item(SpotItem(title: "A", run: Self.big)))

        XCTAssertTrue(text.hasPrefix("1\n"))
        XCTAssertEqual(TextBlock.blocks(in: String(text.dropFirst(2))).first?.value("value"), Self.big)
    }

    func testAValueOf64KilobytesStaysInTheArguments() async throws {
        let url = try script(body: "printf '%s' \"${#2}\"")
        let value = String(repeating: "x", count: 65_536)

        let text = try await runs.answer(of: Spot(id: "script", name: "Script", url: url), .set("a", to: value), input: "a=\(value)\n")

        XCTAssertEqual(text, "65536")
    }
}
