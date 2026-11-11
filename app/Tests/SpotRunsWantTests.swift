import Observation
import XCTest
@testable import OpenspotCore

/// Proves what wants a script, each moment, search, the main search and the sandbox.
@MainActor
final class SpotRunsWantTests: SpotRunsCase {
    // MARK: K5

    func testClosingThePanelClosesASheetOfPartsAndTheNextOpenReads() async throws {
        try script(header: "read=sheet", "printf 'field=a\\nvalue=one\\n'")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the part") { sheet.panel != nil }
        sheet.set(try XCTUnwrap(sheet.panel?.parts.first), to: "typed")

        runs.panelClosed()

        XCTAssertFalse(sheet.isOpen)
        XCTAssertNil(sheet.panel)
        sheet.open {}
        try await wait("the new read") { sheet.panel?.parts.first?.value == "one" }
        XCTAssertEqual(log(), ["read", "read"])
    }

    func testClosingThePanelLeavesASheetOfRowsOpen() async throws {
        try script(header: "read=sheet", "printf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        runs.panelClosed()

        XCTAssertTrue(sheet.isOpen)
        XCTAssertEqual(sheet.list.shown.count, 1)
    }

    // MARK: F7

    func testAWidgetCanPlaceAnyScriptWithARead() async throws {
        try script("onpanel", header: "read=panel\nshortcut=p", log: "onpanel", "printf 'text=m\\ntitle=P\\n'")
        try script("onsheet", header: "read=sheet\nshortcut=s", log: "onsheet", "printf 'text=m\\ntitle=S\\n'")
        try "[[widgets]]\ntitle = \"W\"\ngrid = [\"a a b b\"]\nplaces = { a = \"onpanel\", b = \"onsheet\" }\n".write(to: folder.appendingPathComponent("w.toml"), atomically: true, encoding: .utf8)
        _ = try scanned()
        XCTAssertEqual(log("onsheet"), [])

        runs.panelOpened()

        try await wait("the values") { self.runs.sheets["onpanel"]?.reading.value?.title == "P" && self.runs.sheets["onsheet"]?.reading.value?.title == "S" }
    }

    func testAWidgetThatAScanAddsWhileThePanelIsOpenStartsTheStayingScriptItPlaces() async throws {
        try script("stayer", header: "stay=true\nread=sheet", "while IFS= read -r line; do :; done")
        _ = try scanned()
        runs.panelOpened()
        try await pause(0.2)
        XCTAssertFalse(exists("pids"))

        try "[[widgets]]\ntitle = \"W\"\ngrid = [\"a a a a\"]\nplaces = { a = \"stayer\" }\n".write(to: folder.appendingPathComponent("w.toml"), atomically: true, encoding: .utf8)
        _ = try scanned()

        try await wait("the start of the placed script") { self.exists("pids") }
    }
    func testAWidgetCannotPlaceAScriptWithNoRead() throws {
        try script("once")
        try "[[widgets]]\ntitle = \"W\"\ngrid = [\"a\"]\nplaces = { a = \"once\" }\nsize = \"square\"\n".write(to: folder.appendingPathComponent("w.toml"), atomically: true, encoding: .utf8)

        let scan = try PluginFolder(url: folder).scan()

        XCTAssertEqual(scan.refused, [ScanResult.Refusal(file: "w", reason: "W names no metric called once")])
    }

    func testTheMenuBarShowsWhatTheSheetHolds() async throws {
        try script("pulls", header: "title=Pull requests\nread=120\nshortcut=g\ntray=true", "printf 'text=m\\ntitle=2\\n\\nrow=a\\ntitle=A\\n\\nrow=b\\ntitle=B\\n'")
        let sheet = try sheet("pulls")

        try await wait("the mark") { !self.runs.trayMarks.isEmpty }

        XCTAssertEqual(runs.trayMarks.first?.mark.summary, "Pull requests: 2")
        XCTAssertEqual(sheet.list.shown.count, 2)
    }

    func testTheMenuBarHearsOfAMarkThatComesAfterItFirstLooked() async throws {
        let changed = expectation(description: "a change of the marks")
        changed.assertForOverFulfill = false
        withObservationTracking { _ = runs.trayMarks } onChange: { changed.fulfill() }
        try script("agents", header: "read=5\ntray=true", "printf 'row=a\\n'")

        _ = try scanned()

        await fulfillment(of: [changed], timeout: 2)
    }

    // MARK: L3, moments

    func testEachMomentReadsOnlyTheScriptsThatListIt() async throws {
        try script("onsheet", header: "read=sheet", log: "onsheet", "printf 'row=s\\ntitle=S\\n'")
        try script("ontimer", header: "read=600", log: "ontimer", "printf 'text=t\\ntitle=T\\n'")
        try script("onpanel", header: "read=panel", log: "onpanel", "printf 'text=m\\ntitle=P\\n'")
        _ = try scanned()
        try await pause(0.1)
        XCTAssertEqual(log("onsheet") + log("ontimer") + log("onpanel"), [])

        runs.woke()
        try await pause(0.1)
        XCTAssertEqual(log("onsheet") + log("ontimer") + log("onpanel"), [])

        runs.panelOpened()
        try await wait("the panel read") { self.log("onpanel") == ["read"] }
        XCTAssertEqual(log("onsheet") + log("ontimer"), [])
    }

    func testAnOpenSheetOfRowsIsNotReadWithThePanelClosedAndIsReadWhenThePanelOpens() async throws {
        try script(header: "read=5\nshortcut=a", "printf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 && sheet.calls.isEmpty }
        XCTAssertEqual(log(), ["read"])
        time += 5
        runs.tick()
        try await wait("the read from the number") { self.log() == ["read", "read"] && sheet.calls.isEmpty }

        runs.panelClosed()
        XCTAssertTrue(sheet.isOpen)
        time += 5
        runs.tick()
        try await pause(0.15)
        XCTAssertEqual(log(), ["read", "read"])

        time += 5
        runs.panelOpened()
        try await wait("the read when the panel opens") { self.log() == ["read", "read", "read"] }
    }

    func testAStreamOfAnOpenSheetOfRowsStopsWhenThePanelClosesAndStartsWhenItOpens() async throws {
        try script(header: "read=sheet", "printf 'row=a\\ntitle=A\\n---\\n'\nsleep 5\ntouch '\(path("went-on"))'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        runs.panelClosed()
        try await allEnded()
        XCTAssertFalse(exists("went-on"))
        XCTAssertEqual(sheet.list.shown.count, 1)

        time += 5
        runs.panelOpened()
        try await wait("the new read") { self.log() == ["read", "read"] }
    }

    func testAScriptInTheMenuBarIsReadOnItsClockWithThePanelClosed() async throws {
        try script(header: "read=1\ntray=true", "printf 'text=t\\ntitle=1\\n'")
        _ = try scanned()
        try await wait("the first read") { self.log().count == 1 }

        time += 1

        try await wait("the read from the clock") { self.log().count == 2 }
    }

    func testTheClockLooksAtTheTimeOnlyWhenAReadIsDue() async throws {
        var looks = 0
        runs = SpotRuns(now: { [unowned self] in
            looks += 1
            return self.time
        }, stopPause: 0.2, tickPause: .milliseconds(50))
        try script(header: "read=5\ntray=true", "printf 'text=t\\ntitle=1\\n'")
        _ = try scanned()
        try await wait("the first read") { self.log().count == 1 && self.runs.sheets["script"]?.calls.isEmpty == true }
        let before = looks

        try await pause(0.5)

        XCTAssertLessThanOrEqual(looks - before, 1)
        XCTAssertEqual(log().count, 1)
    }

    func testAScriptWantedWhileTheClockWaitsForALaterReadIsReadOnItsOwnTime() async throws {
        try script("pulls", header: "read=120\ntray=true", log: "pulls", "printf 'text=t\\ntitle=1\\n'")
        try script(header: "read=1\nshortcut=a", "printf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()
        try await wait("the read of the menu bar spot") { self.log("pulls").count == 1 }
        runs.panelOpened()
        sheet.open {}
        try await wait("the first read of the sheet") { self.log().count == 1 && sheet.calls.isEmpty }

        time += 1

        try await wait("the read from the clock") { self.log().count == 2 }
    }
    func testAStayingScriptThatACallHoldsIsReadOnItsOwnTimeWhileTheClockWaitsForALaterRead() async throws {
        try script("pulls", header: "read=120\ntray=true", log: "pulls", "printf 'text=t\\ntitle=1\\n'")
        try script("stayer", header: "stay=true\nread=1", """
        while IFS= read -r line; do
          printf '%s\\n' "$line" >> '\(path("blocks"))'
          case "$line" in call=*) call=${line#call=}; args= ;; arg=*) args="$args ${line#arg=}" ;; esac
          [ -n "$line" ] || [ "$args" != ' read' ] || printf 'end=%s\\n\\ntext=t\\ntitle=1\\n---\\n' "$call"
        done
        """)
        _ = try scanned()
        try await wait("the read of the menu bar spot") { self.log("pulls").count == 1 }
        let stayer = try XCTUnwrap(runs.sheets["stayer"])

        stayer.pressKey("go")
        try await wait("the call and the first read") { self.blocks().contains("arg=go") && self.blocks().filter { $0 == "arg=read" }.count == 1 }
        time += 1

        try await wait("the read from the clock") { self.blocks().filter { $0 == "arg=read" }.count == 2 }
    }

    // MARK: C4, the main search, sandbox

    func testSearchTextReachesTheScriptAfterAPause() async throws {
        try script(header: "read=sheet", "printf 'search=script\\n\\nrow=a\\ntitle=%s\\n' \"${2:-none}\"")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the first answer") { sheet.list.shown.map(\.title) == ["none"] }

        for text in ["r", "re", "rep"] {
            sheet.search(text)
        }
        XCTAssertEqual(log(), ["read"])

        try await wait("the answer") { sheet.list.shown.map(\.title) == ["rep"] }
        XCTAssertEqual(log(), ["read", "read rep"])
    }

    func testANewKeyStopsTheOlderSearch() async throws {
        try script(header: "read=sheet", """
        [ "$2" = slow ] && { sleep 5; touch '\(path("went-on"))'; }
        printf 'search=script\\n\\nrow=a\\ntitle=%s\\n' "${2:-none}"
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the first answer") { sheet.list.shown.map(\.title) == ["none"] }

        sheet.search("slow")
        try await wait("the search") { self.log().count == 2 }
        sheet.search("slower")
        try await wait("the answer") { sheet.list.shown.map(\.title) == ["slower"] }
        try await allEnded()

        XCTAssertFalse(exists("went-on"))
    }

    func testTheMainSearchWithANumberNeedsAKey() throws {
        try script("a", header: "read=30\nglobal=true")
        try script("b", header: "read=panel,30\nglobal=true")
        try script("c", header: "read=30\nglobal=true\nshortcut=c")

        XCTAssertEqual(try PluginFolder(url: folder).scan().refused.map(\.file), ["a", "b"])
        XCTAssertEqual(
            try PluginFolder(url: folder).scan().refused.first?.reason,
            "A needs a shortcut to join the main search, because a number in its read and no shortcut gives it no spot"
        )
    }

    func testTheSandboxClicksAFileWithNoRead() async throws {
        let url = try script(body: "printf 'text=a\\ntitle=%s\\n' \"$#\"")
        let sheet = runs.sheet(for: SheetSandbox.command(file: url))

        sheet.open {}

        try await wait("the sheet") { sheet.panel?.parts.first?.title == "1" }
        XCTAssertEqual(log(), ["open"])
    }

    func testTheSandboxReadsAFileWithARead() async throws {
        let url = try script(header: "read=panel", "printf 'text=a\\ntitle=%s\\n' \"$1\"")
        let sheet = runs.sheet(for: SheetSandbox.command(file: url))

        sheet.open {}

        try await wait("the sheet") { sheet.panel?.parts.first?.title == "read" }
    }
}
