import XCTest
@testable import OpenspotCore

/// Proves how long a call runs, how a call stops, and how a big value reaches a script.
@MainActor
final class SpotRunsCallTests: SpotRunsCase {
    // MARK: Section 7

    func testAReadHasTenSecondsAndAnyOtherNameHasNoLimit() async throws {
        XCTAssertEqual(SpotRuns().readLimit, 10)
        runs = SpotRuns(readLimit: 0.5)
        try script(header: "read=sheet", """
        case "$1" in
          read) [ -f '\(path("slow"))' ] && sleep 30; touch '\(path("slow"))'; printf 'title=1\\n\\nrow=A\\nrun=a\\n' ;;
          open) sleep 0.3; touch '\(path("done"))' ;;
        esac
        """)
        let sheet = try sheet()
        var failures: [String] = []
        sheet.onReport = { if case .failure(let text) = $0 { failures.append(text) } }
        sheet.read()
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.read(need: .change)
        try await wait("the time limit") { !failures.isEmpty }
        XCTAssertEqual(failures, ["Script failed. It took too long."])
        XCTAssertEqual(sheet.list.shown.count, 1)
        XCTAssertEqual(sheet.reading.value?.title, "1")
        XCTAssertTrue(sheet.reading.isStale)

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))
        try await wait("the end of the work") { self.exists("done") }
    }

    func testAFailedTimerReadKeepsTheValueAndDimsWithNoToast() async throws {
        try script(header: "read=5\ntray=true", """
        [ -f '\(path("second"))' ] && exit 1
        touch '\(path("second"))'
        printf 'title=3\\n'
        """)
        let sheet = try sheet()
        var failures: [String] = []
        sheet.onReport = { if case .failure(let text) = $0 { failures.append(text) } }
        try await wait("the value") { sheet.reading.value?.title == "3" && sheet.calls.isEmpty }
        XCTAssertFalse(sheet.reading.isStale)
        XCTAssertEqual(runs.trayMarks.first?.mark.isStale, false)

        time += 5
        runs.tick()

        try await wait("the dim") { sheet.reading.isStale }
        XCTAssertEqual(sheet.reading.value?.title, "3")
        XCTAssertEqual(runs.trayMarks.first?.mark.isStale, true)
        XCTAssertEqual(failures, [])
    }

    func testAFailedCallAlwaysTellsThePerson() async throws {
        try script(body: "echo gone >&2\nexit 2")
        let sheet = try sheet()
        var failures: [String] = []
        sheet.onReport = { if case .failure(let text) = $0 { failures.append(text) } }

        sheet.pressCard()

        try await wait("the failure") { failures == ["Script failed. gone"] }
    }

    func testAReadStopsWhenThePanelThatWantedItCloses() async throws {
        try script(header: "read=panel\nrank=1", "printf 'row=A\\nrun=a\\n---\\n'\nsleep 5\ntouch '\(path("went-on"))'")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the first frame") { sheet.list.shown.count == 1 }

        runs.panelClosed()
        try await allEnded()

        XCTAssertFalse(exists("went-on"))
        XCTAssertEqual(sheet.calls.count, 0)
    }

    func testClosingASheetLeavesAReadThatThePanelWants() async throws {
        try script(header: "read=panel\nrank=1", "sleep 0.2\nprintf 'row=A\\nrun=a\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}

        sheet.close()

        try await wait("the row") { sheet.list.shown.count == 1 }
    }

    func testAStreamThatNothingWantsStopsAfterItsFirstFrame() async throws {
        try script(header: "read=sheet", "printf 'row=A\\nrun=a\\n---\\n'\nsleep 5\ntouch '\(path("went-on"))'")
        let sheet = try sheet()

        sheet.read()
        try await wait("the row") { sheet.list.shown.count == 1 }
        try await allEnded()

        XCTAssertFalse(exists("went-on"))
    }

    func testAStoppedReadChangesNothing() async throws {
        try script(header: "read=sheet", """
        [ -f '\(path("second"))' ] && { sleep 5; exit 0; }
        touch '\(path("second"))'
        printf 'row=A\\nrun=a\\n'
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 && sheet.calls.isEmpty }
        sheet.read(need: .change)
        XCTAssertTrue(sheet.list.isLoading)

        sheet.close()
        try await wait("the end of the read") { !sheet.list.isLoading }
        try await pause(0.1)

        XCTAssertEqual(sheet.list.shown.count, 1)
        XCTAssertFalse(sheet.list.hasFailed)
    }

    private static let worker = """
    case "$1" in
      read) printf 'layout=none\\n\\npart=go\\ntitle=Go\\npress=true\\n\\npart=bar\\ntitle=idle\\n' ;;
      go)
        printf 'toast=Started\\non=true\\n\\npart=bar\\ntitle=half\\n---\\n'
        sleep 0.3
        touch '%@'
        printf 'toast=Done\\n\\npart=bar\\ntitle=done\\n'
        ;;
    esac
    """

    func testAWorkCallGoesOnWithTheSheetAndThePanelClosedAndKeepsItsLastFrame() async throws {
        try script(header: "read=sheet", String(format: Self.worker, path("done")))
        let sheet = try sheet()
        var toasts: [String] = []
        sheet.onReport = { if case .toast(let text) = $0 { toasts.append(text) } }
        sheet.open {}
        try await wait("the part") { sheet.panel != nil && sheet.calls.isEmpty }

        sheet.press(try XCTUnwrap(sheet.panel?.parts.first))
        try await wait("the first frame") { sheet.calls.first?.lastFrame != nil }
        let call = try XCTUnwrap(sheet.calls.first)
        XCTAssertTrue(call.doesWork)
        XCTAssertEqual(call.action.arguments, ["go"])
        XCTAssertEqual(call.output?.parts.first?.title, "half")
        sheet.close()
        runs.panelClosed()
        XCTAssertEqual(sheet.calls.count, 1)

        try await wait("the end of the work") { self.exists("done") && sheet.calls.isEmpty }
        XCTAssertEqual(toasts, ["Started", "Done"])
        XCTAssertEqual(sheet.lastFrame, "toast=Done\n\npart=bar\ntitle=done\n")
        XCTAssertNil(sheet.panel)
    }

    func testAFrameWithNoOpenSheetShowsOnlyItsToastAndItsState() async throws {
        try script(header: "read=panel", """
        case "$1" in
          read) printf 'on=false\\n\\nrow=A\\nrun=a\\n\\npart=bar\\ntitle=idle\\n' ;;
          open) printf 'toast=Saved\\non=true\\ntitle=Other\\n\\npart=bar\\ntitle=work\\n' ;;
        esac
        """)
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the state") { sheet.state.on == false }
        var toasts: [String] = []
        sheet.onReport = { if case .toast(let text) = $0 { toasts.append(text) } }

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))

        try await wait("the toast") { toasts == ["Saved"] }
        XCTAssertEqual(sheet.state.on, true)
        XCTAssertEqual(sheet.state.title, "Script")
        XCTAssertEqual(sheet.panel?.parts.first?.title, "idle")
    }

    func testOpeningASheetAddsTheLastFrameOfEachRunningCall() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'part=go\\ntitle=Go\\npress=true\\n\\npart=bar\\ntitle=idle\\n' ;;
          go) printf 'part=bar\\ntitle=half\\n---\\n'; sleep 30 ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the part") { sheet.panel != nil }
        sheet.press(try XCTUnwrap(sheet.panel?.parts.first))
        try await wait("the frame") { sheet.panel?.parts.last?.title == "half" }
        sheet.close()
        runs.panelClosed()
        XCTAssertNil(sheet.panel)

        sheet.open {}

        try await wait("the running frame") { sheet.panel?.parts.last?.title == "half" }
        XCTAssertEqual(sheet.calls.filter(\.doesWork).count, 1)
    }

    func testANewValueStopsTheOlderCallOfThatPartAndNoOther() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'part=a\\non=false\\n\\npart=b\\non=false\\n\\npart=out\\ntitle=none\\n' ;;
          a) [ "$2" = true ] && { sleep 0.25; touch '\(path("old-a"))'; exit 0; }; touch '\(path("new-a"))'; printf 'part=out\\ntitle=new\\n' ;;
          b) sleep 0.25; touch '\(path("b"))'; printf 'part=out\\ntitle=b\\n' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the parts") { sheet.panel != nil }
        let parts = try XCTUnwrap(sheet.panel?.parts)

        sheet.set(parts[1], to: "true")
        sheet.set(parts[0], to: "true")
        try await pause(0.1)
        sheet.set(parts[0], to: "false")

        try await wait("the other part") { self.exists("b") }
        try await pause(0.1)
        XCTAssertTrue(exists("new-a"))
        XCTAssertFalse(exists("old-a"))
        XCTAssertEqual(sheet.panel?.parts[0].value, "false")
        XCTAssertEqual(sheet.panel?.parts[2].title, "b")
    }

    func testAnOlderCallOfAnotherPartLeavesAPartThatChangedSince() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'part=a\\non=false\\n\\npart=b\\non=false\\n' ;;
          a) sleep 0.2; printf 'part=a\\non=true\\n\\npart=b\\non=false\\n' ;;
          b) printf 'part=b\\non=true\\n' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the parts") { sheet.panel != nil }
        let parts = try XCTUnwrap(sheet.panel?.parts)

        sheet.set(parts[0], to: "true")
        sheet.set(parts[1], to: "true")
        try await wait("the end of both") { sheet.calls.isEmpty && self.log().count >= 3 }

        XCTAssertEqual(sheet.panel?.parts[1].value, "true")
    }

    func testASecondPressOfARunningPartStopsItAndChangesNothing() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'part=go\\ntitle=Go\\npress=true\\n' ;;
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
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'action=go\\ntitle=Go\\nscope=command\\n\\nrow=A\\nrun=a\\n' ;;
          go) sleep 5; touch '\(path("went-on"))' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the action") { sheet.command.actions.count == 1 }
        let action = try XCTUnwrap(sheet.command.actions.first)

        sheet.run(action, item: nil)
        try await wait("the call") { self.log() == ["read", "go"] }
        time += 1
        sheet.run(action, item: nil)
        try await allEnded()

        XCTAssertFalse(exists("went-on"))
        XCTAssertEqual(log(), ["read", "go"])
    }

    func testASecondPressOfARunningCardStopsIt() async throws {
        try script(body: "sleep 5\ntouch '\(path("went-on"))'")
        let sheet = try sheet()

        sheet.pressCard()
        XCTAssertTrue(sheet.isCardRunning)
        try await wait("the call") { self.log() == [""] }
        time += 1
        sheet.pressCard()
        XCTAssertFalse(sheet.isCardRunning)
        try await allEnded()

        XCTAssertFalse(exists("went-on"))
    }

    func testAStoppedToggleGoesBack() async throws {
        try script(header: "read=panel", "[ \"$1\" = read ] && { printf 'on=false\\n'; exit 0; }\nsleep 5")
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the kind") { sheet.command.kind == .toggle }

        sheet.pressCard()
        XCTAssertEqual(sheet.state.on, true)
        time += 1
        sheet.pressCard()

        try await wait("the old state") { sheet.state.on == false }
    }

    // MARK: C6

    private static let big = String(repeating: "line \\ one=two\n", count: 2_000_000 / 15)

    func testATwoMegabyteValueOfAPartIsLeftOutOfTheArgumentsAndStdinHoldsIt() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'part=input\\ntext=\\n' ;;
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

        let text = try await runs.answer(of: PluginCommand(id: "script", name: "Script", url: url), .item(SpotItem(title: "A", run: Self.big)))

        XCTAssertTrue(text.hasPrefix("1\n"))
        XCTAssertEqual(TextBlock.blocks(in: String(text.dropFirst(2))).first?.value("value"), Self.big)
    }

    func testAValueOf64KilobytesStaysInTheArguments() async throws {
        let url = try script(body: "printf '%s' \"${#2}\"")
        let value = String(repeating: "x", count: 65_536)

        let text = try await runs.answer(of: PluginCommand(id: "script", name: "Script", url: url), .set("a", to: value), input: "a=\(value)\n")

        XCTAssertEqual(text, "65536")
    }
}
