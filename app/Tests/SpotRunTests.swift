import Observation
import XCTest
@testable import OpenspotCore

@MainActor
final class SpotRunTests: XCTestCase {
    private var folder: URL!
    private var runs: [SpotRuns] = []

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-sheet-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        runs.forEach { $0.quit() }
        runs = []
        try? FileManager.default.removeItem(at: folder)
    }

    private func make(name: String = "script", _ body: String, stays: Bool = false, read: SpotRead? = nil) throws -> SpotRun {
        let url = folder.appendingPathComponent("\(name).sh")
        try "#!/bin/sh\n\(body)\n".writeScript(to: url)
        let made = SpotRuns()
        runs.append(made)
        return made.sheet(for: Spot(id: name, name: name, url: url, kind: .list, read: read ?? (stays ? nil : .sheet), stays: stays))
    }

    private func path(_ name: String) -> String {
        folder.appendingPathComponent(name).path
    }

    private func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: path(name))
    }

    private func wait(_ what: String, until condition: () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited for \(what)")
    }

    private func holding(_ body: String, pause: TimeInterval) throws -> SpotRun {
        let url = folder.appendingPathComponent("held.sh")
        try "#!/bin/sh\n\(body)\n".writeScript(to: url)
        let made = SpotRuns(firstAnswerPause: pause)
        runs.append(made)
        return made.sheet(for: Spot(id: "held", name: "held", url: url, kind: .list, read: .sheet))
    }

    func testASheetThatWaitsOpensWithItsFirstAnswer() async throws {
        let sheet = try holding("printf 'text=a\\ntitle=A\\n'", pause: 30)
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

        try await wait("the open") { isOpened }
        XCTAssertNil(sheet.panel)
        sheet.close()
    }

    func testAnArrowPressNudgesTheScrollAndLeavesThePartsAsTheyWere() async throws {
        let sheet = try holding("printf 'text=a\\ntitle=A\\n'", pause: 0.02)
        sheet.open(waits: true) {}
        try await wait("the parts") { sheet.panel != nil }
        let parts = sheet.panel

        sheet.scrollPanel(by: 1)
        sheet.scrollPanel(by: -1)

        XCTAssertEqual(sheet.nudge, SheetParts.Nudge(step: -1, serial: 2))
        XCTAssertEqual(sheet.panel, parts)
        sheet.close()
    }

    func testOnlyTheFirstPartsOfASheetArriveThroughTheArrival() async throws {
        let sheet = try holding("printf 'text=a\\ntitle=A\\n---\\n'\nsleep 0.1\nprintf 'text=a\\ntitle=B\\n---\\n'", pause: 0.02)
        var arrivals = 0
        runs.last?.partsArrival = { _, bring in
            arrivals += 1
            bring()
        }

        sheet.open(waits: true) {}

        try await wait("the later parts") { sheet.panel?.parts.first?.title == "B" }
        XCTAssertEqual(arrivals, 1)
        sheet.close()
    }

    func testASheetSaysItAwaitsItsFirstAnswerUntilItComes() async throws {
        let sheet = try holding("sleep 0.2\nprintf 'text=a\\ntitle=A\\n'", pause: 0.02)

        sheet.open(waits: true) {}

        XCTAssertTrue(sheet.awaitsFirstAnswer)
        try await wait("the parts") { sheet.panel != nil }
        XCTAssertFalse(sheet.awaitsFirstAnswer)
    }

    func testASheetWithAnAnswerOpensAtOnceThoughItMayWait() async throws {
        let sheet = try holding("printf 'row=a\\ntitle=A\\n'", pause: 30)
        sheet.read()
        try await wait("the row") { sheet.list.shown.count == 1 }
        var isOpened = false

        sheet.open(waits: true) { isOpened = true }

        XCTAssertTrue(isOpened)
    }

    func testAClosedSheetDoesNotOpenWhenItsAnswerComes() async throws {
        let sheet = try holding("printf 'row=a\\ntitle=A\\n'", pause: 0.02)
        var isOpened = false

        sheet.open(waits: true) { isOpened = true }
        sheet.close()
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertFalse(isOpened)
    }

    func testARunThatEndsWithNoOutputEmptiesTheList() async throws {
        let sheet = try make("[ -f '\(path("second"))' ] && exit 0\ntouch '\(path("second"))'\nprintf 'row=a\\ntitle=A\\n'")

        sheet.read()
        try await wait("the row") { sheet.list.shown.count == 1 }
        sheet.read(need: .change)
        try await wait("no rows") { sheet.list.shown.isEmpty }
    }

    func testAReadThatOthersJoinLeavesTheRows() async throws {
        let sheet = try make("""
        [ -f '\(path("second"))' ] || { touch '\(path("second"))'; printf 'row=a\\ntitle=A\\n'; exit 0; }
        sleep 0.2
        printf 'row=a\\ntitle=A\\n'
        """)
        sheet.read()
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.read(need: .change)
        sheet.read(need: .change)
        var lowest = 1
        for _ in 0..<80 {
            lowest = min(lowest, sheet.list.shown.count)
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(lowest, 1)
        XCTAssertEqual(sheet.list.shown.count, 1)
    }

    func testClosingStopsAReadThatNothingElseWants() async throws {
        let sheet = try make("sleep 0.2\nprintf 'row=a\\ntitle=A\\n'")

        sheet.open {}
        sheet.close()
        try await Task.sleep(for: .milliseconds(250))

        XCTAssertEqual(sheet.list.shown.count, 0)
        XCTAssertFalse(sheet.list.isLoading)
    }

    func testClosingOneSheetLeavesTheReadOfAnother() async throws {
        let first = try make(name: "first", "printf 'text=a\\ntitle=A\\n---\\n'\nsleep 30")
        let second = try make(name: "second", "sleep 0.2\nprintf 'row=b\\ntitle=B\\n'")

        first.open {}
        try await wait("the first frame") { first.panel != nil }
        second.read()
        first.close()

        try await wait("the row") { second.list.shown.count == 1 }
    }

    func testClosingStopsAScriptThatKeepsPrinting() async throws {
        let sheet = try make("""
        echo $$ > '\(path("pid"))'
        printf 'title=Sheet\\n\\ntext=a\\ntitle=0\\n---\\n'
        sleep 5
        touch '\(path("went-on"))'
        printf 'text=a\\ntitle=1\\n---\\n'
        """)

        sheet.open {}
        try await wait("the first frame") { sheet.panel != nil }
        sheet.close()
        let pid = try XCTUnwrap(Int32(try String(contentsOfFile: path("pid"), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)))
        try await wait("the end of the script") { kill(pid, 0) != 0 }

        XCTAssertFalse(exists("went-on"))
        XCTAssertEqual(sheet.panel?.parts.first?.title, "0")
    }

    func testAnOpenSheetTakesLaterFrames() async throws {
        let sheet = try make("printf 'text=a\\ntitle=0\\n---\\n'\nsleep 0.1\nprintf 'text=a\\ntitle=1\\n---\\n'")

        sheet.open {}

        try await wait("the later frame") { sheet.panel?.parts.first?.title == "1" }
    }

    func testAnOlderAnswerDoesNotReplaceANewerChange() async throws {
        let sheet = try make("""
        case "$1" in
          a) [ "$2" = old ] && sleep 0.2; printf 'field=a\\ntitle=%s\\ntext=x\\n' "$2" ;;
          *) printf 'field=a\\ntitle=start\\ntext=x\\n' ;;
        esac
        """)
        sheet.open {}
        try await wait("the sheet") { sheet.panel != nil }
        let part = try XCTUnwrap(sheet.panel?.parts.first)

        sheet.set(part, to: "old")
        sheet.set(part, to: "new")

        try await wait("the newest answer") { sheet.panel?.parts.first?.title == "new" }
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(sheet.panel?.parts.first?.title, "new")
        XCTAssertEqual(sheet.panel?.parts.first?.value, "new")
    }

    func testAToastIsReported() async throws {
        let sheet = try make("printf 'text=a\\ntitle=A\\n---\\n'\nprintf 'toast=Later\\n\\ntext=a\\ntitle=B\\n---\\n'")
        var toasts: [String] = []
        sheet.onReport = { if case .toast(let text) = $0 { toasts.append(text) } }

        sheet.open {}

        try await wait("the toast") { toasts == ["Later"] }
    }

    private static let counter = """
    count=0
    trap 'touch "%@"' EXIT
    while IFS= read -r line; do
      case "$line" in
        call=*) call=${line#call=} ;;
        arg=a) count=$((count + 1)) ;;
        '') printf 'grid=a\\nend=%%s\\n\\nbutton=a\\ntitle=%%s\\n---\\n' "$call" "$count" ;;
      esac
    done
    """

    func testAStayingSheetOpensWithItsFirstFrame() async throws {
        let sheet = try make("sleep 0.2\n" + String(format: Self.counter, path("ended")), stays: true)
        var isReady = false

        sheet.open { isReady = true }
        XCTAssertFalse(isReady)

        try await wait("the first frame") { isReady }
        XCTAssertEqual(sheet.panel?.parts.first?.title, "0")
    }

    func testAStayingScriptDoesNotStartBeforeItsSheetOpens() async throws {
        let sheet = try make("touch '\(path("started"))'", stays: true, read: .panel)

        sheet.read()
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertFalse(exists("started"))
    }

    func testClosingEndsAStayingScriptAndTheNextOpenStartsAfresh() async throws {
        let sheet = try make(String(format: Self.counter, path("ended")), stays: true)
        sheet.open {}
        try await wait("the first frame") { sheet.panel != nil }
        let part = try XCTUnwrap(sheet.panel?.parts.first)
        sheet.press(part)
        try await wait("the count") { sheet.panel?.parts.first?.title == "1" }

        sheet.close()
        try await wait("the end of the script") { exists("ended") }

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
            arg=copy) sleep 0.2; touch '\(path("copied"))' ;;
            '') printf 'grid=copy\\nend=%s\\n\\nbutton=copy\\ntitle=Copy\\n---\\n' "$call" ;;
          esac
        done
        """, stays: true)
        sheet.open {}
        try await wait("the first frame") { sheet.panel != nil }

        sheet.press(try XCTUnwrap(sheet.panel?.parts.first))
        sheet.close()

        try await wait("the copy") { exists("copied") }
    }

    func testAStayingScriptGetsEachValueOfTheSheetInItsBlock() async throws {
        let sheet = try make("""
        while IFS= read -r line; do
          case "$line" in
            call=*) call=${line#call=} ;;
            input=*) seen=${line#input=} ;;
            '') printf 'end=%s\\n\\nfield=input\\ntext=x\\n\\ntext=seen\\ntitle=%s\\n---\\n' "$call" "$seen" ;;
          esac
        done
        """, stays: true)
        sheet.open {}
        try await wait("the first frame") { sheet.panel != nil }

        sheet.press(try XCTUnwrap(sheet.panel?.parts.first))

        try await wait("the value") { sheet.panel?.parts.last?.title == "x" }
        sheet.close()
    }

    func testAScriptThatSearchesGetsReadWithTheText() async throws {
        let sheet = try make("printf 'search=script\\n\\nrow=a\\ntitle=%s:%s\\n' \"$1\" \"$2\"")
        sheet.open {}
        try await wait("the first answer") { sheet.list.shown.map(\.title) == ["read:"] }

        sheet.search("rep")

        try await wait("the answer to the text") { sheet.list.shown.map(\.title) == ["read:rep"] }
    }

    func testAScriptThatSearchesGetsEachFormOfTheText() async throws {
        let sheet = try make("printf 'search=script\\n\\nrow=a\\ntitle=%s:%s\\n' \"$2\" \"$3\"")
        sheet.open {}
        try await wait("the first answer") { sheet.list.shown.map(\.title) == [":"] }

        sheet.search("сафари")

        try await wait("the answer to the text") { sheet.list.shown.map(\.title) == ["сафари:safari"] }
    }

    func testTextTypedBeforeTheFirstAnswerGoesToAScriptThatSearches() async throws {
        let sheet = try make("""
        [ -n "$2" ] || sleep 0.2
        printf 'search=script\\n\\nrow=a\\ntitle=%s\\n' "${2:-none}"
        """)

        sheet.open {}
        sheet.search("rep")

        try await wait("the answer to the text") { sheet.list.shown.map(\.title) == ["rep"] }
    }

    func testAKeptSearchGoesToAScriptThatSearchesOnOpen() async throws {
        let sheet = try make("printf 'search=script\\n\\nrow=a\\ntitle=%s\\n' \"${2:-none}\"")
        sheet.open {}
        try await wait("the first answer") { sheet.list.shown.map(\.title) == ["none"] }
        sheet.search("rep")
        try await wait("the answer to the text") { sheet.list.shown.map(\.title) == ["rep"] }
        sheet.close()

        sheet.open {}
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(sheet.list.query, "rep")
        XCTAssertEqual(sheet.list.shown.map(\.title), ["rep"])
    }

    func testAStoppedSearchChangesNothing() async throws {
        let sheet = try make("""
        [ "$2" = slow ] && sleep 0.2 && exit 0
        printf 'search=script\\n\\nrow=a\\ntitle=A\\n'
        """)
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.search("slow")
        sheet.close()
        try await Task.sleep(for: .milliseconds(250))

        XCTAssertEqual(sheet.list.shown.count, 1)
    }

    func testAKeptSearchIsAskedAgainOnOpen() async throws {
        let sheet = try make("printf 'row=n\\ntitle=Notes\\n\\nrow=m\\ntitle=Mail\\n'")
        sheet.open {}
        try await wait("the rows") { sheet.list.shown.count == 2 }
        sheet.search("no")
        sheet.close()

        sheet.open {}

        XCTAssertEqual(sheet.list.query, "no")
        try await wait("the match") { sheet.list.shown.map(\.title) == ["Notes"] }
    }

    func testAMoveOfTheSelectionLeavesTheShapeAndTheWaitAlone() async throws {
        let sheet = try holding("printf 'row=a\\ntitle=A\\n\\nrow=b\\ntitle=B\\n'", pause: 30)
        sheet.read()
        try await wait("the rows") { sheet.list.shown.count == 2 }
        XCTAssertEqual(sheet.shape, SpotRun.Shape(rows: 2, perLine: 1))
        nonisolated(unsafe) var changed = false
        withObservationTracking {
            _ = sheet.shape
            _ = sheet.awaitsFirstAnswer
        } onChange: {
            changed = true
        }

        sheet.list.move(by: 1)

        XCTAssertFalse(changed)
    }

    func testAMoveOfTheSelectionTellsOnlyTheReadersOfTheSelection() async throws {
        let sheet = try holding("printf 'row=a\\ntitle=A\\n\\nrow=b\\ntitle=B\\n'", pause: 30)
        sheet.read()
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
        let sheet = try holding("printf 'row=a\\ntitle=A\\n\\nrow=b\\ntitle=B\\n'", pause: 30)
        sheet.read()
        try await wait("the rows") { sheet.list.shown.count == 2 }
        nonisolated(unsafe) var listChanged = false
        withObservationTracking { _ = sheet.list } onChange: { listChanged = true }

        sheet.search("b")

        XCTAssertTrue(listChanged)
    }

    func testAMoveOfTheSelectionTellsTheReadersOfTheSelectedRow() async throws {
        let sheet = try holding("printf 'row=a\\ntitle=A\\n\\nrow=b\\ntitle=B\\n'", pause: 30)
        sheet.read()
        try await wait("the rows") { sheet.list.shown.count == 2 }
        nonisolated(unsafe) var changed = false
        withObservationTracking { _ = sheet.selectedItem } onChange: { changed = true }

        sheet.list.move(by: 1)

        XCTAssertTrue(changed)
        XCTAssertEqual(sheet.selectedItem?.title, "B")
    }

    func testAnEqualListTellsNoReader() async throws {
        let sheet = try holding("printf 'row=a\\ntitle=A\\n\\nrow=b\\ntitle=B\\n'", pause: 30)
        sheet.read()
        try await wait("the rows") { sheet.list.shown.count == 2 }
        nonisolated(unsafe) var changed = false
        withObservationTracking { _ = sheet.list; _ = sheet.selection } onChange: { changed = true }

        sheet.list.selectFirst()

        XCTAssertFalse(changed)
    }

    func testAMoveOfTheSelectionAndALoadReportNothing() async throws {
        let sheet = try holding("printf 'row=a\\ntitle=A\\n\\nrow=b\\ntitle=B\\n'", pause: 30)
        sheet.read()
        try await wait("the rows") { sheet.list.shown.count == 2 }
        var changes = 0
        sheet.onReport = { if case .listChange = $0 { changes += 1 } }

        sheet.list.move(by: 1)
        sheet.list.beginLoading()
        sheet.list.stopLoading()

        XCTAssertEqual(changes, 0)
    }

    func testTheSameValueAgainTellsNoReaderOfTheReading() async throws {
        let sheet = try make("printf 'text=heat\\ntitle=41°\\n'")
        sheet.read(need: .change)
        try await wait("the value") { !sheet.isReading && sheet.reading.value?.title == "41°" }
        nonisolated(unsafe) var changed = false
        withObservationTracking { _ = sheet.reading } onChange: { changed = true }

        sheet.read(need: .change)
        try await wait("the second answer") { !sheet.isReading }

        XCTAssertFalse(changed)
    }

    func testAnAnswerWithNewRowsReportsOneListChange() async throws {
        let sheet = try holding("printf 'row=a\\ntitle=A\\n\\nrow=b\\ntitle=B\\n'", pause: 30)
        var changes = 0
        sheet.onReport = { if case .listChange = $0 { changes += 1 } }

        sheet.read()
        try await wait("the rows") { sheet.list.shown.count == 2 }

        XCTAssertEqual(changes, 1)
    }
}
