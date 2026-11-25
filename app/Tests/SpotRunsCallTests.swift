import XCTest
@testable import OpenspotCore

@MainActor
final class SpotRunsCallTests: SpotRunsCase {
    func testAReadAtThePanelThatTakesTooLongMarksItsCardAndTellsNoOne() async throws {
        runs = SpotRuns(showLimit: 0.3)
        try script(toml: "[on]\n\"panel.open\" = true", "sleep 30")
        let sheet = try sheet()
        var failures: [String] = []
        sheet.onReport = { if case .toast(let note) = $0, note.kind == .failure, note.fix == nil { failures.append(note.words) } }

        sheet.show()

        try await wait("the time limit") { sheet.failure != nil }
        XCTAssertEqual(sheet.failure, "Script took too long, so Openspot stopped it.")
        XCTAssertEqual(failures, [])
    }

    func testAReadHasTenSecondsAndAnyOtherNameHasNoLimit() async throws {
        XCTAssertEqual(SpotRuns().showLimit, 10)
        runs = SpotRuns(showLimit: 1.5)
        try script(toml: "", """
        case "$1" in
          show) [ -f '\(path("slow"))' ] && sleep 30; touch '\(path("slow"))'; printf 'frame=\\ntitle=1\\n\\nitem=a\\ntitle=A\\n' ;;
          press) sed -n 's/^input\\.item=//p' > '\(path("item"))'; \(untilRelease); touch '\(path("done"))' ;;
        esac
        """)
        let sheet = try sheet()
        var failures: [String] = []
        sheet.onReport = { if case .toast(let note) = $0, note.kind == .failure, note.fix == nil { failures.append(note.words) } }
        sheet.show()
        try await wait("the row") { sheet.list.shown.count == 1 }
        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))
        try await wait("the work on the item") { self.log().contains("press") && (try? String(contentsOfFile: self.path("item"), encoding: .utf8)) == "a\n" }

        sheet.show(need: .change)
        try await wait("the time limit") { !failures.isEmpty }
        XCTAssertEqual(failures, ["Script took too long, so Openspot stopped it."])
        XCTAssertEqual(sheet.list.shown.count, 1)
        XCTAssertEqual(sheet.reading.value?.title, "A")
        XCTAssertTrue(sheet.reading.isStale)

        XCTAssertFalse(sheet.calls.isEmpty)
        openGate()
        try await wait("the end of the work") { self.placed(at: path("done")) }
    }

    func testAFailedTimerReadKeepsTheValueAndDimsWithNoToast() async throws {
        menuBar.insert("script")
        try script(toml: "[on]\nevery = 5", """
        [ -f '\(path("second"))' ] && exit 1
        touch '\(path("second"))'
        printf 'frame=\\nclass=gap-part\\n\\ntext=m\\nclass=bar:flex\\ntitle=3\\n'
        """)
        let sheet = try sheet()
        var failures: [String] = []
        sheet.onReport = { if case .toast(let note) = $0, note.kind == .failure, note.fix == nil { failures.append(note.words) } }
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

    func testASpotWithNoValueShowsItsIconInTheMenuBar() throws {
        menuBar.insert("pen")
        _ = try script("pen", toml: "title = 'Pen'\nicon = 'pencil.tip'\n[actions.draw]\ntitle = 'Draw on screen'")
        let pen = try sheet("pen")

        XCTAssertTrue(pen.spot.canShowInMenuBar)
        let mark = try XCTUnwrap(runs.menuBarMarks.first { $0.id == "pen" }?.mark)
        XCTAssertEqual(mark.symbol, "pencil.tip")
        XCTAssertEqual(mark.content, .icon)
        XCTAssertEqual(mark.summary, "Pen")
    }

    func testAFailedCallAlwaysTellsThePerson() async throws {
        try script(toml: TestSpot.command, "echo gone >&2\nexit 2")
        let sheet = try sheet()
        var failures: [String] = []
        sheet.onReport = { if case .toast(let note) = $0, note.kind == .failure, note.fix == nil { failures.append(note.words) } }

        sheet.pressCard()

        try await wait("the failure") { failures == ["gone"] }
    }

    func testAFailedCallThatPrintsALinkTellsThePersonWithItsFix() async throws {
        try script(toml: TestSpot.command, "printf 'link=x-apple.systempreferences:pane\\n'\necho 'Allow it.' >&2\nexit 1")
        let sheet = try sheet()
        var fixes: [String] = []
        sheet.onReport = { if case .toast(let note) = $0, case .url(let fix) = note.fix { fixes.append("\(note.words) \(fix.absoluteString)") } }

        sheet.pressCard()

        try await wait("the failure") { fixes == ["Allow it. x-apple.systempreferences:pane"] }
    }

    func testWhatASheetPrintsDuringItsOpenMotionShowsWhenTheMotionEnds() async throws {
        runs.quit()
        runs = SpotRuns(opening: SheetOpening(motionLength: 30), stopPause: 0.2)
        try script(toml: "", "printf 'item=a\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        runs.opening.moving = "script"
        sheet.open {}
        try await wait("the frame at the hold") { self.runs.opening.waitingFrames == 1 }

        XCTAssertEqual(sheet.list.shown.count, 0)
        runs.opening.moving = nil

        try await wait("the rows") { sheet.list.shown.count == 1 }
    }

    func testASheetOfRowsSaysItsKindWhileItsFirstAnswerWaitsForTheOpenMotion() async throws {
        runs.quit()
        runs = SpotRuns(opening: SheetOpening(motionLength: 30), stopPause: 0.2)
        try script(toml: "", "printf 'frame=\\nclass=gap-part\\n\\nitems=list\\n\\ntext=a\\nparent=list\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        runs.opening.moving = "script"
        sheet.open {}
        XCTAssertTrue(sheet.isWaiting)

        try await wait("the kind") { !sheet.isWaiting }
        XCTAssertNil(sheet.panel)
        XCTAssertEqual(sheet.list.shown.count, 0)
        runs.opening.moving = nil
    }

    func testASheetOfPartsWithNoRowsSaysItsKindWhileItsFirstAnswerWaitsForTheOpenMotion() async throws {
        runs.quit()
        runs = SpotRuns(opening: SheetOpening(motionLength: 30), stopPause: 0.2)
        try script(toml: "", "printf 'frame=\\nclass=gap-part\\n\\ntext=a\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        runs.opening.moving = "script"
        sheet.open {}
        try await wait("the frame at the hold") { self.runs.opening.waitingFrames == 1 }

        XCTAssertNil(sheet.panel)
        XCTAssertFalse(sheet.isWaiting)
        XCTAssertFalse(sheet.showsField)
        runs.opening.moving = nil
        try await wait("the parts") { sheet.panel != nil }
        XCTAssertFalse(sheet.showsField)
    }

    func testASheetForgetsTheKindOfAHeldAnswerThatItsStoppedReadDrops() async throws {
        runs.quit()
        runs = SpotRuns(opening: SheetOpening(motionLength: 30), stopPause: 0.2)
        try script(toml: "", "printf 'frame=\\nclass=gap-part\\n\\ntext=a\\ntitle=A\\n'")
        let sheet = try sheet()
        let ends = ends()
        runs.panelOpened()
        runs.opening.moving = "script"
        sheet.open {}
        try await wait("the kind") { !sheet.isWaiting && !sheet.showsField }

        runs.panelClosed()
        runs.opening.moving = nil
        try await wait("the end of the read") { ends() == 1 }

        XCTAssertNil(sheet.panel)
        XCTAssertFalse(sheet.isWaiting)
        XCTAssertTrue(sheet.showsField)
    }

    func testWhatASheetPrintsShowsAfterTheLengthOfItsOpenMotionThoughItsSpringSettlesLater() async throws {
        try script(toml: "", "printf 'item=a\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        runs.opening.moving = "script"

        sheet.open {}

        try await wait("the rows") { sheet.list.shown.count == 1 }
        XCTAssertNil(runs.opening.moving)
    }

    func testTheOpenMotionOfAnotherSheetHoldsNothingOfThisOne() async throws {
        try script(toml: "", "printf 'item=a\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        runs.opening.moving = "other"

        sheet.open {}

        try await wait("the rows") { sheet.list.shown.count == 1 }
    }

    func testAReadStopsWhenThePanelThatWantedItCloses() async throws {
        try script(toml: "[on]\n\"panel.open\" = true\nsearch = true", "printf 'item=a\\ntitle=A\\n---\\n'\nsleep 5\ntouch '\(path("went-on"))'")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the first frame") { sheet.list.shown.count == 1 }

        runs.panelClosed()
        try await allEnded()

        XCTAssertFalse(placed(at: path("went-on")))
        XCTAssertEqual(sheet.calls.count, 0)
    }

    func testClosingASheetLeavesAReadThatThePanelWants() async throws {
        try script(toml: "[on]\n\"panel.open\" = true\nsearch = true", "sleep 0.2\nprintf 'item=a\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}

        sheet.close()

        try await wait("the row") { sheet.list.shown.count == 1 }
    }

    func testAStreamThatNothingWantsStopsAfterItsFirstFrame() async throws {
        try script(toml: "", "printf 'item=a\\ntitle=A\\n---\\n'\nsleep 5\ntouch '\(path("went-on"))'")
        let sheet = try sheet()

        sheet.show()
        try await wait("the row") { sheet.list.shown.count == 1 }
        try await allEnded()

        XCTAssertFalse(placed(at: path("went-on")))
    }

    func testAProcessThatEndedIsLetGoWithNoLaterCall() async throws {
        try script(toml: "", "printf 'item=a\\ntitle=A\\n'")
        let sheet = try sheet()

        sheet.show()

        try await wait("the row") { sheet.list.shown.count == 1 && sheet.calls.isEmpty }
        try await wait("no process kept") { self.runs.processes.isEmpty }
    }

    func testAStoppedReadChangesNothing() async throws {
        try script(toml: "", """
        [ -f '\(path("second"))' ] && { sleep 5; exit 0; }
        touch '\(path("second"))'
        printf 'item=a\\ntitle=A\\n'
        """)
        let sheet = try sheet()
        let ends = ends()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 && sheet.calls.isEmpty }
        sheet.show(need: .change)
        XCTAssertFalse(sheet.calls.isEmpty)

        sheet.close()
        try await wait("the end of the read") { sheet.calls.isEmpty && ends() == 2 }

        XCTAssertEqual(sheet.list.shown.count, 1)
        XCTAssertFalse(sheet.list.hasFailed)
    }

    private static let worker = """
    case "$1" in
      show) printf 'frame=\\ntitle=Sheet\\nclass=gap-part\\n\\nbutton=go\\ntitle=Go\\nclose=false\\n\\ntext=bar\\ntitle=idle\\n' ;;
      go)
        \(TestSpot.toast) Started
        printf 'frame=\\nclass=gap-part\\n\\ntext=bar\\ntitle=half\\n---\\n'
        sleep 0.3
        touch '%@'
        \(TestSpot.toast) Done
        printf 'text=bar\\ntitle=done\\n'
        ;;
    esac
    """

    func testAWorkCallGoesOnWithTheSheetAndThePanelClosedAndItsLastPictureStands() async throws {
        takeCalls()
        try script(toml: "", String(format: Self.worker, path("done")))
        let sheet = try sheet()
        var toasts: [String] = []
        sheet.onReport = { if case .toast(let note) = $0 { toasts.append(note.words) } }
        let frames = FrameLog(sheet)
        sheet.open {}
        try await wait("the part") { sheet.panel != nil && sheet.calls.isEmpty }

        sheet.press(try XCTUnwrap(sheet.panel?.parts.first))
        try await wait("the first frame") { sheet.panel?.parts.map(\.title) == ["half"] }
        let call = try XCTUnwrap(sheet.calls.first)
        XCTAssertTrue(call.isAct)
        XCTAssertEqual(call.handler, "go")
        sheet.close()
        runs.panelClosed()
        XCTAssertEqual(sheet.calls.count, 1)

        try await wait("the end of the work") { self.placed(at: path("done")) && sheet.calls.isEmpty }
        XCTAssertEqual(toasts, ["Started", "Done"])
        XCTAssertEqual(frames.last, "frame=\nclass=gap-part\n\ntext=bar\ntitle=done\n")
        XCTAssertEqual(sheet.panel?.parts.map(\.title) ?? ["done"], ["done"])
    }

    func testAFrameOfAPickWithNoOpenSheetIsTheWholePicture() async throws {
        try script(toml: "[on]\n\"panel.open\" = true", """
        case "$1" in
          show) printf 'frame=\\nclass=gap-part\\ndetail=Idle\\n\\nitems=list\\n\\nitem=a\\nparent=list\\ntitle=A\\n\\ntext=bar\\ntitle=idle\\n' ;;
          press) printf 'frame=\\nclass=gap-part\\ntitle=Other\\nactive=true\\n\\ntext=bar\\ntitle=work\\n' ;;
        esac
        """)
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the state") { sheet.state.subtitle == "Idle" }
        sheet.open {}
        sheet.close()

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))

        try await wait("the new state") { sheet.state.on == true }
        XCTAssertEqual(sheet.state.title, "Other")
        XCTAssertEqual(sheet.list.shown.map(\.run), [])
    }

    func testOpeningASheetWhileACallRunsShowsItsRead() async throws {
        try script(toml: "", """
        case "$1" in
          show) printf 'frame=\\nclass=gap-part\\n\\nbutton=go\\ntitle=Go\\n\\nfield=note\\nvalue=\\n\\ntext=bar\\ntitle=idle\\n' ;;
          go) printf 'frame=\\ntitle=Half\\nprogress=0.5\\n---\\n'; sleep 30 ;;
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
        XCTAssertEqual(sheet.calls.filter(\.isAct).first?.fill, 0.5)
    }

    func testANewValueStopsTheOlderCallOfThatPartAndNoOther() async throws {
        try script(toml: "", """
        v=$(sed -n 's/^input\\.value=//p')
        case "$1" in
          show) printf 'frame=\\nclass=gap-part\\n\\nswitch=a\\nvalue=false\\n\\nswitch=b\\nvalue=false\\n\\ntext=out\\ntitle=none\\n' ;;
          a) [ "$v" = true ] && { touch '\(path("a-true"))'; sleep 30; touch '\(path("old-a"))'; exit 0; }; touch '\(path("new-a"))'; printf 'frame=\\nclass=gap-part\\n\\nswitch=a\\nvalue=false\\n\\nswitch=b\\nvalue=true\\n\\ntext=out\\ntitle=new\\n' ;;
          b) \(untilRelease); touch '\(path("b"))'; printf 'frame=\\nclass=gap-part\\n\\nswitch=a\\nvalue=false\\n\\nswitch=b\\nvalue=true\\n\\ntext=out\\ntitle=b\\n' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the parts") { sheet.panel != nil }
        let parts = try XCTUnwrap(sheet.panel?.parts)

        sheet.set(parts[1], to: "true")
        sheet.set(parts[0], to: "true")
        try await wait("the first call of a with true") { self.placed(at: path("a-true")) }
        sheet.set(parts[0], to: "false")

        try await wait("the new call of a") { sheet.panel?.parts[2].title == "new" }
        openGate()
        try await wait("the end of b") { self.placed(at: path("b")) && sheet.calls.isEmpty }
        try await allEnded()
        XCTAssertTrue(placed(at: path("new-a")))
        XCTAssertFalse(placed(at: path("old-a")))
        XCTAssertEqual(sheet.panel?.parts[0].value, "false")
    }

    func testAnOlderCallOfAnotherPartLeavesAPartThatChangedSince() async throws {
        try script(toml: "", """
        v=$(sed -n 's/^input\\.value=//p')
        case "$1" in
          show) printf 'frame=\\nclass=gap-part\\n\\nswitch=a\\nvalue=%s\\n\\nswitch=b\\nvalue=%s\\n' "$(cat '\(path("a"))' 2>/dev/null || echo false)" "$(cat '\(path("b"))' 2>/dev/null || echo false)" ;;
          a) sleep 0.2; echo "$v" > '\(path("a"))'; printf 'frame=\\nclass=gap-part\\n\\nswitch=a\\nvalue=true\\n\\nswitch=b\\nvalue=false\\n' ;;
          b) echo "$v" > '\(path("b"))'; printf 'frame=\\nclass=gap-part\\n\\nswitch=a\\nvalue=false\\n\\nswitch=b\\nvalue=true\\n' ;;
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
        try script(toml: "", """
        case "$1" in
          show) printf 'frame=\\nclass=gap-part\\n\\nbutton=go\\ntitle=Go\\n' ;;
          go) sleep 5; touch '\(path("went-on"))' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the part") { sheet.panel != nil }
        let part = try XCTUnwrap(sheet.panel?.parts.first)

        sheet.press(part)
        try await wait("the call") { self.log() == ["show", "go"] }
        time += 1
        sheet.press(part)
        XCTAssertTrue(sheet.calls.isEmpty)
        try await allEnded()

        XCTAssertFalse(placed(at: path("went-on")))
        XCTAssertEqual(log(), ["show", "go"])
    }

    func testASecondPressOfARunningActionStopsIt() async throws {
        try script(toml: "", """
        case "$1" in
          show) printf 'button=go\\ntitle=Go\\nscope=spot\\n\\ntext=a\\ntitle=A\\n' ;;
          go) sleep 5; touch '\(path("went-on"))' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the action") { sheet.spot.frameActions.count == 1 }
        let action = try XCTUnwrap(sheet.spot.frameActions.first)

        sheet.run(action, item: nil)
        try await wait("the call") { self.log() == ["show", "go"] }
        time += 1
        sheet.run(action, item: nil)
        try await allEnded()

        XCTAssertFalse(placed(at: path("went-on")))
        XCTAssertEqual(log(), ["show", "go"])
    }

    func testAStoppedToggleGoesBack() async throws {
        try script(toml: "[on]\n\"panel.open\" = true", "[ \"$1\" = show ] && { printf 'switch=power\\nclass=card:flex\\nvalue=false\\n'; exit 0; }\nsleep 5")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the kind") { sheet.spot.kind == .toggle }

        sheet.pressCard()
        XCTAssertEqual(sheet.state.on, true)
        time += 1
        sheet.pressCard()

        try await wait("the old state") { sheet.state.on == false }
    }

    private static let big = String(repeating: "line \\ one=two\n", count: 2_000_000 / 15)

    func testATwoMegabyteValueOfAPartIsLeftOutOfTheArgumentsAndStdinHoldsIt() async throws {
        try script(toml: "", """
        case "$1" in
          show) printf 'frame=\\nclass=gap-part\\n\\nfield=input\\nvalue=\\n' ;;
          input) printf '%s' "$#" > '\(path("count"))'; cat > '\(path("got"))'; touch '\(path("done"))' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the part") { sheet.panel != nil }

        sheet.set(try XCTUnwrap(sheet.panel?.parts.first), to: Self.big)

        try await wait("the call") { self.placed(at: path("done")) }
        XCTAssertEqual(try String(contentsOfFile: path("count"), encoding: .utf8), "1")
        let got = try String(contentsOfFile: path("got"), encoding: .utf8)
        XCTAssertEqual(TextBlock.blocks(in: got).first?.value("input.input"), Self.big)
    }

    private func ends() -> () -> Int {
        var count = 0
        runs.onCall = { _ in count += 1 }
        return { count }
    }
}
