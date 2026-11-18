import Observation
import XCTest
@testable import OpenspotCore

@MainActor
final class SpotRunsWantTests: SpotRunsCase {
    func testClosingThePanelClosesASheetOfPartsAndTheNextOpenReads() async throws {
        try script(toml: "on = ['sheet.open']", "printf 'field=a\\nvalue=one\\n'")
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
        try script(toml: "on = ['sheet.open']", "printf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        runs.panelClosed()

        XCTAssertTrue(sheet.isOpen)
        XCTAssertEqual(sheet.list.shown.count, 1)
    }

    func testAWidgetCanPlaceAnyScriptWithARead() async throws {
        try script("onpanel", toml: "on = ['panel.open']", log: "onpanel", "printf 'text=m\\ntitle=P\\n'")
        try script("onsheet", toml: "on = ['sheet.open']", log: "onsheet", "printf 'text=m\\ntitle=S\\n'")
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("w"), toml: "title = 'W'\n'grid.strip' = ['onpanel onpanel onsheet onsheet']")
        _ = try scanned()
        XCTAssertEqual(log("onsheet"), [])

        runs.panelOpened()

        try await wait("the values") { self.runs.sheets["onpanel"]?.reading.value?.title == "P" && self.runs.sheets["onsheet"]?.reading.value?.title == "S" }
    }

    func testAWidgetThatAScanAddsWhileThePanelIsOpenStartsTheStayingScriptItPlaces() async throws {
        try script("stayer", toml: "mode = 'stay'\non = ['sheet.open']\noffers = ['card', 'menubar']", "while IFS= read -r line; do :; done")
        _ = try scanned()
        runs.panelOpened()
        try await pause(0.2)
        XCTAssertFalse(exists("pids"))

        try "#!/bin/sh\n".writeScript(to: folder.spotFile("w"), toml: "title = 'W'\n'grid.strip' = ['stayer stayer stayer stayer']")
        _ = try scanned()

        try await wait("the start of the placed script") { self.exists("pids") }
    }
    func testAWidgetCannotPlaceAScriptWithNoRead() throws {
        try script("once")
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("w"), toml: "title = 'W'\n'grid.square' = ['once']")

        let scan = try SpotsFolder(url: folder).scan()

        XCTAssertEqual(scan.refused, [ScanResult.Refusal(file: "w", reason: "W names once, which has no on= line, so it never prints a value. Give once an event, such as on=clock.60.")])
    }

    func testTheMenuBarShowsWhatTheSheetHolds() async throws {
        menuBar.insert("pulls")
        try script("pulls", toml: "title = 'Pull requests'\non = ['clock.120']\noffers = ['card', 'menubar']", "printf 'text=m\\ntitle=2\\n\\nrow=a\\ntitle=A\\n\\nrow=b\\ntitle=B\\n'")
        let sheet = try sheet("pulls")

        try await wait("the mark") { !self.runs.menuBarMarks.isEmpty }

        XCTAssertEqual(runs.menuBarMarks.first?.mark.summary, "Pull requests: 2")
        XCTAssertEqual(sheet.list.shown.count, 2)
    }

    func testASpotShowsInTheMenuBarWhenThePersonPutsItThereWithItsValueOrElseItsIcon() async throws {
        try script("cups", toml: "title = 'Cups'\non = ['clock.5']\noffers = ['card', 'menubar']", log: "cups", "printf 'text=t\\ntitle=3\\n'")
        try script("notes", toml: "title = 'Notes'\nicon = 'note.text'\non = ['panel.open']", log: "notes", "printf 'text=t\\ntitle=4\\n'")
        _ = try scanned()
        XCTAssertTrue(runs.menuBarMarks.isEmpty)

        menuBar = ["cups", "notes"]
        _ = try scanned()

        try await wait("both marks") { self.runs.menuBarMarks.count == 2 }
        XCTAssertEqual(runs.menuBarMarks.map(\.id), ["cups", "notes"])
        XCTAssertEqual(runs.menuBarMarks.map(\.mark.summary), ["Cups: 3", "Notes"])
        XCTAssertEqual(runs.menuBarMarks.last?.mark, MenuBarMark(icon: "note.text", name: "Notes"))
    }

    func testTheMenuBarHearsOfAMarkThatComesAfterItFirstLooked() async throws {
        let changed = expectation(description: "a change of the marks")
        changed.assertForOverFulfill = false
        withObservationTracking { _ = runs.menuBarMarks } onChange: { changed.fulfill() }
        menuBar.insert("agents")
        try script("agents", toml: "on = ['clock.5']\noffers = ['card', 'menubar']", "printf 'row=a\\n'")

        _ = try scanned()

        await fulfillment(of: [changed], timeout: 60)
    }

    func testEachMomentReadsOnlyTheScriptsThatListIt() async throws {
        try script("onsheet", toml: "on = ['sheet.open']", log: "onsheet", "printf 'row=s\\ntitle=S\\n'")
        try script("ontimer", toml: "on = ['clock.600']\noffers = ['card', 'menubar']", log: "ontimer", "printf 'text=t\\ntitle=T\\n'")
        try script("onpanel", toml: "on = ['panel.open']", log: "onpanel", "printf 'text=m\\ntitle=P\\n'")
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
        try script(toml: "on = ['clock.5']\noffers = ['card', 'menubar']", "printf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 && sheet.calls.isEmpty }
        XCTAssertEqual(log(), ["read"])
        time += 5
        runs.raise(.clock)
        try await wait("the read from the number") { self.log() == ["read", "read"] && sheet.calls.isEmpty }

        runs.panelClosed()
        XCTAssertTrue(sheet.isOpen)
        time += 5
        runs.raise(.clock)
        try await pause(0.15)
        XCTAssertEqual(log(), ["read", "read"])

        time += 5
        runs.panelOpened()
        try await wait("the read when the panel opens") { self.log() == ["read", "read", "read"] }
    }

    func testAStreamOfAnOpenSheetOfRowsStopsWhenThePanelClosesAndStartsWhenItOpens() async throws {
        try script(toml: "on = ['sheet.open']", "printf 'row=a\\ntitle=A\\n---\\n'\nsleep 5\ntouch '\(path("went-on"))'")
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
        menuBar.insert("script")
        try script(toml: "on = ['clock.1']\noffers = ['card', 'menubar']", "printf 'text=t\\ntitle=1\\n'")
        _ = try scanned()
        try await wait("the first read") { self.log().count == 1 && !self.runs.isReading }

        time += 1

        try await wait("the read from the clock") { self.log().count == 2 }
    }

    func testTheClockLooksAtTheTimeOnlyWhenAReadIsDue() async throws {
        var looks = 0
        runs = SpotRuns(clock: RunClock(now: { [unowned self] in
            looks += 1
            return self.time
        }, sleep: clock.value.sleep), stopPause: 0.2)
        menuBar.insert("script")
        try script(toml: "on = ['clock.5']\noffers = ['card', 'menubar']", "printf 'text=t\\ntitle=1\\n'")
        _ = try scanned()
        try await wait("the first read") { self.log().count == 1 && self.runs.sheets["script"]?.calls.isEmpty == true }
        let before = looks

        try await pause(0.5)

        XCTAssertLessThanOrEqual(looks - before, 1)
        XCTAssertEqual(log().count, 1)
    }

    func testAScriptWantedWhileTheClockWaitsForALaterReadIsReadOnItsOwnTime() async throws {
        menuBar.insert("pulls")
        try script("pulls", toml: "on = ['clock.120']\noffers = ['card', 'menubar']", log: "pulls", "printf 'text=t\\ntitle=1\\n'")
        try script(toml: "on = ['clock.1']\noffers = ['card', 'menubar']", "printf 'row=a\\ntitle=A\\n'")
        let sheet = try sheet()
        try await wait("the read of the menu bar spot") { self.log("pulls").count == 1 }
        runs.panelOpened()
        sheet.open {}
        try await wait("the first read of the sheet") { self.log().count == 1 && sheet.calls.isEmpty }

        time += 1

        try await wait("the read from the clock") { self.log().count == 2 }
    }
    func testAStayingScriptThatACallHoldsIsReadOnItsOwnTimeWhileTheClockWaitsForALaterRead() async throws {
        menuBar.insert("pulls")
        try script("pulls", toml: "on = ['clock.120']\noffers = ['card', 'menubar']", log: "pulls", "printf 'text=t\\ntitle=1\\n'")
        try script("stayer", toml: "mode = 'stay'\non = ['clock.1']\noffers = ['card', 'menubar']", """
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
        try await wait("the call and the first read") { self.blocks().contains("arg=go") && self.blocks().filter { $0 == "arg=read" }.count == 1 && !self.runs.isReading }
        time += 1

        try await wait("the read from the clock") { self.blocks().filter { $0 == "arg=read" }.count == 2 }
    }

    func testSearchTextReachesTheScriptAfterAPause() async throws {
        try script(toml: "on = ['sheet.open', 'sheet.text']", "printf 'row=a\\ntitle=%s\\n' \"${OPENSPOT_VALUE:-none}\"")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the first answer") { sheet.list.shown.map(\.title) == ["none"] }

        for text in ["r", "re", "rep"] {
            sheet.search(text)
        }
        XCTAssertEqual(log(), ["read"])

        try await wait("the answer") { sheet.list.shown.map(\.title) == ["rep"] }
        XCTAssertEqual(log(), ["read", "read"])
    }

    func testANewKeyStopsTheOlderSearch() async throws {
        try script(toml: "on = ['sheet.open', 'sheet.text']", """
        [ "$OPENSPOT_VALUE" = slow ] && { sleep 5; touch '\(path("went-on"))'; }
        printf 'row=a\\ntitle=%s\\n' "${OPENSPOT_VALUE:-none}"
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

    func testATimedSpotJoinsTheMainSearchWithNoKeyAndStartsOffTheGrid() throws {
        try script("a", toml: "on = ['clock.30']\noffers = ['search']")
        try script("b", toml: "on = ['panel.open', 'clock.30']\noffers = ['search']")

        let scan = try SpotsFolder(url: folder).scan()

        XCTAssertEqual(scan.refused, [])
        XCTAssertEqual(scan.spots.map(\.isGlobal), [true, true])
        XCTAssertEqual(scan.spots.map(\.headerState.isOnGrid), [false, false])
    }

    func testThePlaygroundClicksAFileWithNoRead() async throws {
        let url = try script(body: "printf 'text=a\\ntitle=%s\\n' \"$#\"")
        let sheet = runs.sheet(for: Playground.command(file: url))

        sheet.open {}

        try await wait("the sheet") { sheet.panel?.parts.first?.title == "1" }
        XCTAssertEqual(log(), ["open"])
    }

    func testThePlaygroundReadsAFileWithARead() async throws {
        let url = try script(toml: "on = ['panel.open']", "printf 'text=a\\ntitle=%s\\n' \"$1\"")
        let sheet = runs.sheet(for: Playground.command(file: url))

        sheet.open {}

        try await wait("the sheet") { sheet.panel?.parts.first?.title == "read" }
    }
}
