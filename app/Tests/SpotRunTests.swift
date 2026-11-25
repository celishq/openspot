import Observation
import XCTest
@testable import OpenspotCore

@MainActor
final class SpotRunTests: XCTestCase {
    private var folder: URL!
    private var runs: [SpotRuns] = []
    private let clock = FakeClock()

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-sheet-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        runs.forEach { $0.quit() }
        runs = []
        try? FileManager.default.removeItem(at: folder)
    }

    private func make(name: String = "script", searches: Bool = false, _ body: String, mode: SpotMode = .once, triggers: Manifest.Triggers? = nil) throws -> SpotRun {
        let url = folder.spotFile(name)
        let typed = searches ? "[ \"$1\" = sheet.text ] && in=$(cat); t=$(printf '%s\\n' \"$in\" | sed -n 's/^input\\.value=//p'); f=$(printf '%s\\n' \"$in\" | sed -n 's/^input\\.alt=//p' | head -1)\n" : ""
        try "#!/bin/sh\n\(typed)\(body)\n".writeScript(to: url, toml: mode.stays ? "stay = true" : "")
        let made = SpotRuns(clock: clock.value)
        runs.append(made)
        return made.sheet(for: Spot(id: name, name: name, url: url, kind: .list, triggers: triggers ?? (mode.stays ? Manifest.Triggers() : Manifest.Triggers(events: [searches ? EventName.sheetText : EventName.sheetOpen])), mode: mode))
    }

    private func passTextPause() async throws {
        let pause = Double(SpotRun.textPause.components.seconds) + Double(SpotRun.textPause.components.attoseconds) / 1e18
        try await pass(pause, on: clock)
    }

    private func path(_ name: String) -> String {
        folder.appendingPathComponent(name).path
    }

    private var untilRelease: String {
        "n=0; while [ ! -f '\(path("release"))' ] && [ $n -lt 1500 ]; do sleep 0.02; n=$((n + 1)); done"
    }

    private func openGate() {
        FileManager.default.createFile(atPath: path("release"), contents: Data())
    }

    private func holding(_ body: String, pause: TimeInterval) throws -> SpotRun {
        let url = folder.appendingPathComponent("held.sh")
        try "#!/bin/sh\n\(body)\n".writeScript(to: url)
        let made = SpotRuns(answerPause: pause, clock: clock.value)
        runs.append(made)
        return made.sheet(for: Spot(id: "held", name: "held", url: url, kind: .list, triggers: .sheet))
    }

    func testASheetThatWaitsOpensWithItsFirstAnswer() async throws {
        let sheet = try holding("printf 'frame=\\nclass=gap-part\\n\\ntext=a\\ntitle=A\\n'", pause: 30)
        var partsAtOpen: Bool?

        sheet.open(waits: true) { partsAtOpen = sheet.panel != nil }

        XCTAssertNil(partsAtOpen)
        try await wait("the open") { partsAtOpen != nil }
        XCTAssertEqual(partsAtOpen, true)
    }

    func testASheetThatWaitsOpensWithoutAnAnswerThatIsLate() async throws {
        let sheet = try holding("sleep 5", pause: 0.02)
        var isOpened = false

        sheet.open(waits: true) { isOpened = true }
        try await wait("the answer pause") { self.clock.isWaiting(for: 0.02) }
        XCTAssertFalse(isOpened)
        clock.advance(by: 0.02)

        try await wait("the open") { isOpened }
        XCTAssertNil(sheet.panel)
        sheet.close()
    }

    func testAnArrowPressNudgesTheScrollAndLeavesThePartsAsTheyWere() async throws {
        let sheet = try holding("printf 'frame=\\nclass=gap-part\\n\\ntext=a\\ntitle=A\\n'", pause: 0.02)
        sheet.open(waits: true) {}
        try await wait("the parts") { sheet.panel != nil }
        let parts = sheet.panel

        sheet.scrollPanel(by: 1)
        sheet.scrollPanel(by: -1)

        XCTAssertEqual(sheet.nudge, SheetParts.Nudge(step: -1, serial: 2))
        XCTAssertEqual(sheet.panel, parts)
        sheet.close()
    }

    func testASwitchThatTheCardPlacesFillsNoCardWhileItIsOn() async throws {
        let sheet = try make("printf 'switch=power\\nclass=card:flex\\nvalue=true\\n'", triggers: .panel)
        sheet.show()
        try await wait("the switch on") { sheet.state.on == true }

        XCTAssertFalse(sheet.isOn)
    }

    func testAnAnswerThatKeepsTheCardOnTellsNoReaderOfWhetherItIsOn() async throws {
        let sheet = try make("n=$(cat '\(path("n"))' 2>/dev/null); echo $((n + 1)) > '\(path("n"))'; printf 'frame=\\ndetail=Read %s\\nactive=true\\n\\nitem=a\\ntitle=A\\n' \"$n\"", triggers: .panel)
        sheet.show()
        try await wait("the card on") { sheet.isOn }
        let detail = sheet.state.subtitle
        nonisolated(unsafe) var changed = false
        withObservationTracking { _ = sheet.isOn } onChange: { changed = true }

        sheet.show(need: .change)
        try await wait("the next answer") { sheet.state.subtitle != detail }

        XCTAssertFalse(changed)
    }

    func testARepeatedFrameTellsNoReader() async throws {
        let sheet = try make("printf 'frame=\\ndetail=Same\\n\\nitem=a\\ntitle=A\\n'", triggers: .panel)
        nonisolated(unsafe) var frames = 0
        let report = sheet.onReport
        sheet.onReport = {
            if case .frame = $0 { frames += 1 }
            report($0)
        }
        sheet.show()
        try await wait("the first answer") { frames == 1 }
        nonisolated(unsafe) var told: [String] = []
        withObservationTracking { _ = sheet.spot } onChange: { told.append("spot") }
        withObservationTracking { _ = sheet.reading } onChange: { told.append("reading") }
        withObservationTracking { _ = sheet.state } onChange: { told.append("state") }
        withObservationTracking { _ = sheet.list } onChange: { told.append("list") }
        withObservationTracking { _ = sheet.failure } onChange: { told.append("failure") }

        let parses = FrameParses()

        try await FrameParses.$meter.withValue(parses) {
            sheet.show(need: .change)
            try await wait("the second answer") { !sheet.isShowing && sheet.calls.isEmpty }
        }

        XCTAssertEqual(told, [])
        XCTAssertEqual(parses.count, 0)
        XCTAssertEqual(frames, 1)
    }

    func testAFrameOver256KBIsKeptNowhereSoItsRepeatIsParsedAgain() async throws {
        let sheet = try make("printf 'frame=\\ndetail=Long\\n\\nitem=a\\ntitle=A\\nnote=%s\\n' \"$(head -c 270000 /dev/zero | tr '\\0' n)\"", triggers: .panel)
        sheet.show()
        try await wait("the first answer") { sheet.list.all.count == 1 && !sheet.isShowing }
        let parses = FrameParses()

        try await FrameParses.$meter.withValue(parses) {
            sheet.show(need: .change)
            try await wait("the second answer") { !sheet.isShowing && sheet.calls.isEmpty }
        }

        XCTAssertNil(sheet.shownFrame)
        XCTAssertEqual(parses.count, 1)
    }

    func testAChangedFrameAfterARepeatedOneIsApplied() async throws {
        try "1".write(toFile: path("n"), atomically: true, encoding: .utf8)
        let sheet = try make("printf 'item=a\ntitle=%s\n' \"$(cat '\(path("n"))')\"", triggers: .panel)
        sheet.show()
        try await wait("the first answer") { sheet.list.all.map(\.title) == ["1"] && !sheet.isShowing }

        sheet.show(need: .change)
        try await wait("the same frame") { !sheet.isShowing && sheet.calls.isEmpty }
        try "2".write(toFile: path("n"), atomically: true, encoding: .utf8)
        sheet.show(need: .change)

        try await wait("the new row") { sheet.list.all.map(\.title) == ["2"] }
    }

    func testASearchedListWithALongDetailGrowsItsHeaderAndItsSheetByTheSecondLine() async throws {
        let kept = SheetHeader.shared
        SheetHeader.shared = SheetHeader(width: { $0.count > 10 ? .infinity : 0 }, secondLine: 9)
        defer { SheetHeader.shared = kept }
        let url = folder.spotFile("script")
        try "#!/bin/sh\nprintf 'item=a\\ntitle=A\\n'\n".writeScript(to: url)
        let made = SpotRuns(clock: clock.value)
        runs.append(made)
        let sheet = made.sheet(for: Spot(id: "script", name: "script", url: url, kind: .list, subtitle: "A detail longer than its header", triggers: .sheet))
        sheet.open {}
        try await wait("the row") { sheet.list.all.count == 1 && !sheet.isShowing }

        XCTAssertEqual(sheet.shownState.subtitle, "A detail longer than its header")
        XCTAssertTrue(sheet.showsField)
        XCTAssertTrue(sheet.takesKeys)
        XCTAssertEqual(sheet.panel?.holdsParts, false)
        XCTAssertNil(sheet.partsRect)
        XCTAssertEqual(sheet.top, SheetTop(header: 9, hasField: true))
        XCTAssertEqual(sheet.sheetRect.height, SpotTokens.sheetRect(rows: 1).height + 9)
    }

    func testANewPanelTakesTheTopOfTheRunWhenTheRunsTopStaysTheSame() async throws {
        let kept = SheetHeader.shared
        SheetHeader.shared = SheetHeader(width: { $0.count > 10 ? .infinity : 0 }, secondLine: 9)
        defer { SheetHeader.shared = kept }
        try "1".write(toFile: path("n"), atomically: true, encoding: .utf8)
        let url = folder.spotFile("script")
        try """
        #!/bin/sh
        if [ "$(cat '\(path("n"))')" = 1 ]; then printf 'frame=\\nclass=gap-part\\n\\nfield=find\\ntype=search\\n\\nnumber=a\\nvalue=1\\n\\nitems=list\\n\\nitem=b\\nparent=list\\ntitle=B\\n'
        else printf 'frame=\\nclass=gap-part\\n\\nnumber=a\\nvalue=2\\n'; fi
        """.writeScript(to: url)
        let made = SpotRuns(clock: clock.value)
        runs.append(made)
        let sheet = made.sheet(for: Spot(id: "script", name: "script", url: url, kind: .list, subtitle: "A detail longer than its header", triggers: .sheet))
        sheet.open {}
        try await wait("the parts and rows") { sheet.panel?.showsRows == true && !sheet.isShowing }
        XCTAssertEqual(sheet.top, SheetTop(header: 9, hasField: false))

        sheet.panel = SheetParts(output: Frame(text: "frame=\nclass=gap-part\n\nfield=find\ntype=search\n\nnumber=a\nvalue=2\n\nitems=list\n\nitem=b\nparent=list\ntitle=B\n"))

        XCTAssertEqual(sheet.top, SheetTop(header: 9, hasField: false))
        XCTAssertEqual(sheet.panel?.top, sheet.top)
    }

    func testANewValueOfAPartTellsNoReaderOfTheRectOrWhetherTheSheetTakesKeys() async throws {
        let sheet = try make("printf 'frame=\\nclass=gap-part\\n\\nfield=a\\ntitle=Name\\nvalue=%s\\n\\ntext=b\\ntitle=B\\n' \"$2\"")
        sheet.open {}
        try await wait("the parts") { sheet.panel != nil }
        let part = try XCTUnwrap(sheet.panel?.parts.first)
        XCTAssertEqual(sheet.partsRect, sheet.panel.map { SpotTokens.panelRect($0) })
        XCTAssertFalse(sheet.takesKeys)
        nonisolated(unsafe) var changed = false
        withObservationTracking {
            _ = sheet.partsRect
            _ = sheet.takesKeys
        } onChange: {
            changed = true
        }

        sheet.set(part, to: "new")

        XCTAssertEqual(sheet.panel?.parts.first?.value, "new")
        XCTAssertFalse(changed)
        sheet.close()
    }

    func testACloseWithNoSelectionTellsNoReaderOfTheParts() async throws {
        let sheet = try holding("printf 'frame=\\nclass=gap-part\\n\\ntext=a\\ntitle=A\\n\\ntext=b\\ntitle=B\\n'", pause: 0.02)
        sheet.open(waits: true) {}
        try await wait("the parts") { sheet.panel != nil }
        nonisolated(unsafe) var changed = false
        withObservationTracking { _ = sheet.panel } onChange: { changed = true }

        sheet.close()

        XCTAssertFalse(changed)
    }

    func testACloseClearsTheSelectionOfTheParts() async throws {
        let sheet = try holding("printf 'frame=\\nclass=gap-part\\n\\nfield=k\\ntype=hotkey\\nvalue=ctrl+space\\n\\nswitch=w\\nvalue=true\\n'", pause: 0.02)
        sheet.open(waits: true) {}
        try await wait("the parts") { sheet.panel != nil }
        let first = sheet.panel?.selectedPart?.id
        _ = sheet.movePartLine(by: 1)
        XCTAssertNotEqual(sheet.panel?.selectedPart?.id, first)

        sheet.close()

        XCTAssertEqual(sheet.panel?.selectedPart?.id, first)
    }

    func testAMoveOfThePartSelectionTellsOnlyTheReadersOfTheSelectedPart() async throws {
        let sheet = try holding("printf 'frame=\\nclass=gap-part\\n\\nfield=k\\ntype=hotkey\\nvalue=ctrl+space\\n\\nswitch=w\\nvalue=true\\n'", pause: 0.02)
        sheet.open(waits: true) {}
        try await wait("the parts") { sheet.panel != nil }
        let first = sheet.selectedPart?.id
        nonisolated(unsafe) var partsChanged = false
        nonisolated(unsafe) var selectionChanged = false
        withObservationTracking { _ = sheet.panel } onChange: { partsChanged = true }
        withObservationTracking { _ = sheet.selectedPart } onChange: { selectionChanged = true }

        XCTAssertTrue(sheet.movePartLine(by: 1))

        XCTAssertFalse(partsChanged)
        XCTAssertTrue(selectionChanged)
        XCTAssertNotEqual(sheet.selectedPart?.id, first)
        XCTAssertEqual(sheet.selectedPart?.id, sheet.panel?.selectedPart?.id)
        sheet.close()
    }

    func testOnlyTheFirstPartsOfASheetArriveThroughTheArrival() async throws {
        let sheet = try holding("printf 'frame=\\nclass=gap-part\\n\\ntext=a\\ntitle=A\\n---\\n'\n\(untilRelease)\nprintf 'frame=\\nclass=gap-part\\n\\ntext=a\\ntitle=B\\n---\\n'", pause: 0.02)
        var arrivals = 0
        runs.last?.partsArrival = { _, bring in
            arrivals += 1
            bring()
        }

        runs.last?.panelOpened()
        sheet.open(waits: true) {}
        try await wait("the first parts") { sheet.panel?.parts.first?.title == "A" }
        openGate()

        try await wait("the later parts") { sheet.panel?.parts.first?.title == "B" }
        XCTAssertEqual(arrivals, 1)
        sheet.close()
    }

    func testTheFirstRowsOfASheetArriveWithItsParts() async throws {
        let sheet = try holding("printf 'frame=\\nclass=gap-part\\n\\nchoice=tone\\ntitle=Tone\\nvalue=a\\n\\noption=a\\ntitle=A\\n\\nitems=list\\n\\nitem=x\\nparent=list\\ntitle=X\\n\\n'", pause: 0.02)
        var rowsBeforeParts: Int?
        runs.last?.partsArrival = { _, bring in
            rowsBeforeParts = sheet.list.shown.count
            bring()
        }

        sheet.open(waits: true) {}

        try await wait("the parts") { sheet.panel != nil }
        XCTAssertEqual(rowsBeforeParts, 0)
        XCTAssertEqual(sheet.list.shown.count, 1)
        sheet.close()
    }

    func testASheetSaysItAwaitsItsFirstAnswerUntilItComes() async throws {
        let sheet = try holding("\(untilRelease)\nprintf 'frame=\\nclass=gap-part\\n\\ntext=a\\ntitle=A\\n'", pause: 0.02)

        sheet.open(waits: true) {}

        XCTAssertTrue(sheet.isWaiting)
        openGate()
        try await wait("the parts") { sheet.panel != nil }
        XCTAssertFalse(sheet.isWaiting)
    }

    func testASheetWithAnAnswerOpensAtOnceThoughItMayWait() async throws {
        let sheet = try holding("printf 'item=a\\ntitle=A\\n'", pause: 30)
        sheet.show()
        try await wait("the row") { sheet.list.shown.count == 1 }
        var isOpened = false

        sheet.open(waits: true) { isOpened = true }

        XCTAssertTrue(isOpened)
    }

    func testAClosedSheetDoesNotOpenWhenItsAnswerComes() async throws {
        let sheet = try holding("printf 'item=a\\ntitle=A\\n'", pause: 30)
        let ends = try XCTUnwrap(runs.last).endedCalls()
        var isOpened = false

        sheet.open(waits: true) { isOpened = true }
        sheet.close()
        try await wait("the end of the read") { ends() == 1 }

        XCTAssertFalse(isOpened)
    }

    func testARunThatEndsWithNoOutputEmptiesTheList() async throws {
        let sheet = try make("[ -f '\(path("second"))' ] && exit 0\ntouch '\(path("second"))'\nprintf 'item=a\\ntitle=A\\n'")

        sheet.show()
        try await wait("the row") { sheet.list.shown.count == 1 }
        sheet.show(need: .change)
        try await wait("no rows") { sheet.list.shown.isEmpty }
    }

    func testAReadThatOthersJoinLeavesTheRows() async throws {
        let sheet = try make("""
        [ -f '\(path("second"))' ] || { touch '\(path("second"))'; printf 'item=a\\ntitle=A\\n'; exit 0; }
        \(untilRelease)
        printf 'item=a\\ntitle=A\\n'
        """)
        sheet.show()
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.show(need: .change)
        sheet.show(need: .change)
        XCTAssertFalse(sheet.calls.isEmpty)
        openGate()
        var lowest = 1
        try await wait("the end of the joined read") {
            lowest = min(lowest, sheet.list.shown.count)
            return sheet.calls.isEmpty
        }

        XCTAssertEqual(lowest, 1)
        XCTAssertEqual(sheet.list.shown.count, 1)
    }

    func testClosingOneSheetLeavesTheReadOfAnother() async throws {
        let first = try make(name: "first", "printf 'frame=\\nclass=gap-part\\n\\ntext=a\\ntitle=A\\n---\\n'\nsleep 30")
        let second = try make(name: "second", "\(untilRelease)\nprintf 'item=b\\ntitle=B\\n'")

        first.open {}
        try await wait("the first frame") { first.panel != nil }
        second.show()
        first.close()
        openGate()

        try await wait("the row") { second.list.shown.count == 1 }
    }

    func testClosingStopsAScriptThatKeepsPrinting() async throws {
        let sheet = try make("""
        echo $$ > '\(path("pid"))'
        printf 'frame=\\nclass=gap-part\\ntitle=Sheet\\n\\ntext=a\\ntitle=0\\n---\\n'
        sleep 5
        touch '\(path("went-on"))'
        printf 'frame=\\nclass=gap-part\\n\\ntext=a\\ntitle=1\\n---\\n'
        """)

        sheet.open {}
        try await wait("the first frame") { sheet.panel != nil }
        sheet.close()
        let pid = try XCTUnwrap(Int32(try String(contentsOfFile: path("pid"), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)))
        try await wait("the end of the script") { kill(pid, 0) != 0 }

        XCTAssertFalse(placed(at: path("went-on")))
        XCTAssertEqual(sheet.panel?.parts.first?.title, "0")
    }

    func testAnOpenSheetTakesLaterFrames() async throws {
        let sheet = try make("printf 'frame=\\nclass=gap-part\\n\\ntext=a\\ntitle=0\\n---\\n'\n\(untilRelease)\nprintf 'frame=\\nclass=gap-part\\n\\ntext=a\\ntitle=1\\n---\\n'")

        runs.last?.panelOpened()
        sheet.open {}
        try await wait("the first frame") { sheet.panel?.parts.first?.title == "0" }
        openGate()

        try await wait("the later frame") { sheet.panel?.parts.first?.title == "1" }
    }

    private static let counter = """
    count=0
    trap 'touch "%@"' EXIT
    while IFS= read -r line; do
      case "$line" in
        call=*) call=${line#call=} ;;
        arg=a) count=$((count + 1)) ;;
        '') printf 'frame=\\nclass=gap-part\\nend=%%s\\n\\nbutton=a\\ntitle=%%s\\n---\\n' "$call" "$count" ;;
      esac
    done
    """

    func testAStayingSheetOpensWithItsFirstFrame() async throws {
        let sheet = try make("\(untilRelease)\n" + String(format: Self.counter, path("ended")), mode: .stay)
        var isReady = false

        runs.last?.panelOpened()
        sheet.open { isReady = true }
        XCTAssertFalse(isReady)
        openGate()

        try await wait("the first frame") { isReady }
        XCTAssertEqual(sheet.panel?.parts.first?.title, "0")
    }

    func testAStayingScriptDoesNotStartBeforeItsSheetOpens() async throws {
        let sheet = try make("touch '\(path("started"))'", mode: .stay, triggers: .panel)

        sheet.show()

        XCTAssertEqual(runs.last?.processes.isEmpty, true)
    }

    func testClosingEndsAStayingScriptAndTheNextOpenStartsAfresh() async throws {
        let sheet = try make(String(format: Self.counter, path("ended")), mode: .stay)
        runs.last?.panelOpened()
        sheet.open {}
        try await wait("the first frame") { sheet.panel != nil }
        let part = try XCTUnwrap(sheet.panel?.parts.first)
        sheet.press(part)
        try await wait("the count") { sheet.panel?.parts.first?.title == "1" }

        sheet.close()
        try await wait("the end of the script") { placed(at: path("ended")) }

        var isReady = false
        sheet.open { isReady = true }
        try await wait("the new run") { isReady }
        XCTAssertEqual(sheet.panel?.parts.first?.title, "0")
        sheet.close()
    }

    func testAPressJustBeforeClosingStillReachesAStayingScript() async throws {
        let sheet = try make("""
        while IFS= read -r line; do
          case "$line" in
            call=*) call=${line#call=} ;;
            arg=copy) \(untilRelease); touch '\(path("copied"))' ;;
            '') printf 'frame=\\nclass=gap-part\\nend=%s\\n\\nbutton=copy\\ntitle=Copy\\n---\\n' "$call" ;;
          esac
        done
        """, mode: .stay)
        runs.last?.panelOpened()
        sheet.open {}
        try await wait("the first frame") { sheet.panel != nil }

        sheet.press(try XCTUnwrap(sheet.panel?.parts.first))
        sheet.close()
        openGate()

        try await wait("the copy") { placed(at: path("copied")) }
    }

    func testAStayingScriptGetsTheValuesOfTheSheetAsTheStdinOfItsCall() async throws {
        let sheet = try make("""
        . "$OPENSPOT_SH"
        main() { printf 'frame=\\nclass=gap-part\\n\\nfield=input\\nvalue=x\\n\\ntext=seen\\ntitle=%s\\n' "$(value input.input)"; }
        openspot_serve main "$@"
        """, mode: .stay)
        runs.last?.panelOpened()
        sheet.open {}
        try await wait("the first frame") { sheet.panel != nil }

        sheet.press(try XCTUnwrap(sheet.panel?.parts.first))

        try await wait("the value") { sheet.panel?.parts.last?.title == "x" }
        sheet.close()
    }

    func testATextShowsItsRowsBeforeTheSearchReturns() async throws {
        let sheet = try make("printf 'item=a\\ntitle=Apple\\n\\nitem=b\\ntitle=Banana\\n'")
        sheet.open {}
        try await wait("the rows") { sheet.list.shown.count == 2 }
        let landed = sheet.list.landedSearches
        let ranks = SearchRanks()
        nonisolated(unsafe) var told = false
        withObservationTracking { _ = sheet.list } onChange: { told = true }

        SearchRanks.$meter.withValue(ranks) { sheet.search("ban") }

        XCTAssertTrue(told)
        XCTAssertEqual(sheet.list.query, "ban")
        XCTAssertEqual(sheet.list.shown.map(\.run), ["b"])
        XCTAssertEqual(sheet.list.landedSearches, landed + 1)
        XCTAssertEqual(ranks.count, 1)
    }

    func testATextSelectsTheFirstOfItsRows() async throws {
        let sheet = try make("printf 'item=a\\ntitle=Apple\\n\\nitem=b\\ntitle=Banana\\n'")
        sheet.open {}
        try await wait("the rows") { sheet.list.shown.count == 2 }
        sheet.list.move(by: 1)

        sheet.search("a")

        XCTAssertEqual(sheet.selection, 0)
    }

    func testAScriptThatSearchesGetsReadWithTheText() async throws {
        let sheet = try make(searches: true, "printf 'item=a\\ntitle=%s:%s\\n' \"$1\" \"$t\"")
        sheet.open {}
        try await wait("the first answer") { sheet.list.shown.map(\.title) == ["show:"] }

        sheet.search("rep")
        try await passTextPause()

        try await wait("the answer to the text") { sheet.list.shown.map(\.title) == ["sheet.text:rep"] }
    }

    func testAReadWithNoTextGivesAScriptThatSearchesANewValue() async throws {
        let sheet = try make(searches: true, """
        echo x >> '\(path("reads"))'
        printf 'frame=\\nclass=gap-part\\n\\nnumber=next\\nvalue=%s\\ntitle=Next\\n\\nitems=list\\n\\nitem=a\\nparent=list\\ntitle=A\\n' "$(wc -l < '\(path("reads"))' | tr -d ' ')"
        """)
        sheet.show(need: .change)
        try await wait("the first value") { !sheet.isShowing && sheet.reading.value?.title == "1" }

        sheet.show(need: .change)

        try await wait("the second value") { sheet.reading.value?.title == "2" }
    }

    func testAReadWithTextLeftInTheSearchGivesAScriptThatSearchesANewValueAndTheRowsOfTheText() async throws {
        let sheet = try make(searches: true, """
        echo "read $t" >> '\(path("reads"))'
        printf 'frame=\\nclass=gap-part\\n\\nnumber=next\\nvalue=%s\\ntitle=Next\\n\\nitems=list\\n\\nitem=a\\nparent=list\\ntitle=A%s\\n' "$(wc -l < '\(path("reads"))' | tr -d ' ')" "$t"
        """)
        let reads = { ((try? String(contentsOfFile: self.path("reads"), encoding: .utf8)) ?? "").split(separator: "\n").map(String.init) }
        sheet.open {}
        try await wait("the first value") { !sheet.isShowing && sheet.reading.value?.title == "1" }
        sheet.search("x")
        try await passTextPause()
        try await wait("the rows of the text") { sheet.list.shown.map(\.title) == ["Ax"] && !sheet.isShowing }
        sheet.close()

        sheet.show(need: .clock, event: .clock)

        try await wait("a new value") { sheet.reading.value?.title == "3" && !sheet.isShowing }
        XCTAssertEqual(sheet.list.shown.map(\.title), ["Ax"])
        XCTAssertEqual(reads(), ["read ", "read x", "read x"])
    }

    func testAScriptThatSearchesGetsEachFormOfTheText() async throws {
        let sheet = try make(searches: true, "printf 'item=a\\ntitle=%s:%s\\n' \"$t\" \"$f\"")
        sheet.open {}
        try await wait("the first answer") { sheet.list.shown.map(\.title) == [":"] }

        sheet.search("сафари")
        try await passTextPause()

        try await wait("the answer to the text") { sheet.list.shown.map(\.title) == ["сафари:safari"] }
    }

    func testTextTypedBeforeTheFirstAnswerGoesToAScriptThatSearches() async throws {
        let sheet = try make(searches: true, """
        printf 'item=a\\ntitle=%s\\n' "${t:-none}"
        """)

        sheet.open {}
        sheet.search("rep")

        try await wait("the answer to the text") { sheet.list.shown.map(\.title) == ["rep"] }
    }

    func testAKeptSearchGoesToAScriptThatSearchesOnOpen() async throws {
        let sheet = try make(searches: true, "printf 'item=a\\ntitle=%s\\n' \"${t:-none}\"")
        sheet.open {}
        try await wait("the first answer") { sheet.list.shown.map(\.title) == ["none"] }
        sheet.search("rep")
        try await passTextPause()
        try await wait("the answer to the text") { sheet.list.shown.map(\.title) == ["rep"] }
        sheet.close()

        sheet.open {}

        XCTAssertEqual(sheet.list.query, "rep")
        XCTAssertEqual(sheet.list.shown.map(\.title), ["rep"])
    }

    func testAKeptSearchIsAskedAgainOnOpen() async throws {
        let sheet = try make("printf 'item=n\\ntitle=Notes\\n\\nitem=m\\ntitle=Mail\\n'")
        sheet.open {}
        try await wait("the rows") { sheet.list.shown.count == 2 }
        sheet.search("no")
        sheet.close()

        sheet.open {}

        XCTAssertEqual(sheet.list.query, "no")
        try await wait("the match") { sheet.list.shown.map(\.title) == ["Notes"] }
    }

    func testAMoveOfTheSelectionLeavesTheShapeAndTheWaitAlone() async throws {
        let sheet = try holding("printf 'item=a\\ntitle=A\\n\\nitem=b\\ntitle=B\\n'", pause: 30)
        sheet.show()
        try await wait("the rows") { sheet.list.shown.count == 2 }
        XCTAssertEqual(sheet.shape, SpotRun.Shape(rows: 2, perLine: 1))
        nonisolated(unsafe) var changed = false
        withObservationTracking {
            _ = sheet.shape
            _ = sheet.isWaiting
        } onChange: {
            changed = true
        }

        sheet.list.move(by: 1)

        XCTAssertFalse(changed)
    }

    func testAMoveOfTheSelectionTellsOnlyTheReadersOfTheSelection() async throws {
        let sheet = try holding("printf 'item=a\\ntitle=A\\n\\nitem=b\\ntitle=B\\n'", pause: 30)
        sheet.show()
        try await wait("the rows") { sheet.list.shown.count == 2 }
        nonisolated(unsafe) var listChanged = false
        nonisolated(unsafe) var selectionChanged = false
        withObservationTracking { _ = sheet.list } onChange: { listChanged = true }
        withObservationTracking { _ = sheet.selection } onChange: { selectionChanged = true }

        sheet.list.move(by: 1)

        XCTAssertFalse(listChanged)
        XCTAssertTrue(selectionChanged)
        XCTAssertEqual(sheet.selection, 1)
    }

    func testASearchTellsTheReadersOfTheList() async throws {
        let sheet = try holding("printf 'item=a\\ntitle=A\\n\\nitem=b\\ntitle=B\\n'", pause: 30)
        sheet.show()
        try await wait("the rows") { sheet.list.shown.count == 2 }
        nonisolated(unsafe) var listChanged = false
        withObservationTracking { _ = sheet.list } onChange: { listChanged = true }

        sheet.search("b")

        try await wait("the readers of the found rows told") { listChanged }
    }

    func testAMoveOfTheSelectionTellsTheReadersOfTheSelectedRow() async throws {
        let sheet = try holding("printf 'item=a\\ntitle=A\\n\\nitem=b\\ntitle=B\\n'", pause: 30)
        sheet.show()
        try await wait("the rows") { sheet.list.shown.count == 2 }
        nonisolated(unsafe) var changed = false
        withObservationTracking { _ = sheet.selectedItem } onChange: { changed = true }

        sheet.list.move(by: 1)

        XCTAssertTrue(changed)
        XCTAssertEqual(sheet.selectedItem?.title, "B")
    }

    func testAnEqualListTellsNoReader() async throws {
        let sheet = try holding("printf 'item=a\\ntitle=A\\n\\nitem=b\\ntitle=B\\n'", pause: 30)
        sheet.show()
        try await wait("the rows") { sheet.list.shown.count == 2 }
        nonisolated(unsafe) var changed = false
        withObservationTracking { _ = sheet.list; _ = sheet.selection } onChange: { changed = true }

        sheet.list.selectFirst()

        XCTAssertFalse(changed)
    }

    func testAMoveOfTheSelectionAndALoadReportNothing() async throws {
        let sheet = try holding("printf 'item=a\\ntitle=A\\n\\nitem=b\\ntitle=B\\n'", pause: 30)
        sheet.show()
        try await wait("the rows") { sheet.list.shown.count == 2 }
        var changes = 0
        sheet.onReport = { if case .listChange = $0 { changes += 1 } }

        sheet.list.move(by: 1)
        sheet.list.beginLoading()
        sheet.list.stopLoading()

        XCTAssertEqual(changes, 0)
    }

    func testTheSameValueAgainTellsNoReaderOfTheReading() async throws {
        let sheet = try make("printf 'item=heat\\ntitle=41°\\n'")
        sheet.show(need: .change)
        try await wait("the value") { !sheet.isShowing && sheet.reading.value?.title == "41°" }
        nonisolated(unsafe) var changed = false
        withObservationTracking { _ = sheet.reading } onChange: { changed = true }

        sheet.show(need: .change)
        try await wait("the second answer") { !sheet.isShowing }

        XCTAssertFalse(changed)
    }

    func testAnAnswerWithNewRowsReportsOneListChange() async throws {
        let sheet = try holding("printf 'item=a\\ntitle=A\\n\\nitem=b\\ntitle=B\\n'", pause: 30)
        var changes = 0
        sheet.onReport = { if case .listChange = $0 { changes += 1 } }

        sheet.show()
        try await wait("the rows") { sheet.list.shown.count == 2 }

        XCTAssertEqual(changes, 1)
    }


    func testAGridKeepsTheDetailOfItsRootInItsHeader() async throws {
        let kept = SheetHeader.shared
        SheetHeader.shared = SheetHeader(width: { $0.count > 10 ? .infinity : 0 }, secondLine: 9)
        defer { SheetHeader.shared = kept }
        let url = folder.spotFile("script")
        try "#!/bin/sh\nprintf 'frame=\\nclass=gap-part\\n\\nitems=list\\nclass=grid grid-cols-3\\n\\nfield=find\\ntype=search\\n\\nitem=a\\nparent=list\\ntitle=A\\n'\n".writeScript(to: url)
        let made = SpotRuns(clock: clock.value)
        runs.append(made)
        let sheet = made.sheet(for: Spot(id: "script", name: "script", url: url, kind: .list, subtitle: "A detail longer than its header", triggers: .sheet))
        sheet.open {}
        try await wait("the row") { sheet.list.all.count == 1 && !sheet.isShowing }

        XCTAssertEqual(sheet.shownState.subtitle, "A detail longer than its header")
        XCTAssertEqual(sheet.top.header, 9)
    }
}
