import Observation
import XCTest
@testable import OpenspotCore

@MainActor
final class SpotRunsWantTests: SpotRunsCase {
    private func reads() -> Int {
        blocks().filter { $0.hasPrefix("arg=show") || $0 == "arg=every" }.count
    }

    func testClosingThePanelClosesASheetOfPartsAndTheNextOpenReads() async throws {
        try script(toml: "", "printf 'frame=\\nclass=gap-part\\n\\nfield=a\\nvalue=one\\n'")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the part") { sheet.panel != nil }
        sheet.set(try XCTUnwrap(sheet.panel?.parts.first), to: "typed")

        runs.panelClosed()

        XCTAssertFalse(sheet.isOpen)
        XCTAssertNil(sheet.panel)
        sheet.open {}
        try await wait("the new read") { sheet.panel?.parts.first?.value == "one" }
        XCTAssertEqual(log(), ["show", "show"])
    }

    func testClosingThePanelLeavesASheetOfRowsOpen() async throws {
        try script(toml: "", "printf 'item=a\\ntitle=A\\n'")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        runs.panelClosed()

        XCTAssertTrue(sheet.isOpen)
        XCTAssertEqual(sheet.list.shown.count, 1)
    }

    func testTheMenuBarDrawsTheBarLayoutOfTheFrame() async throws {
        menuBar.insert("pulls")
        try script("pulls", toml: "title = 'Pull requests'\n[on]\nevery = 120", "printf 'frame=\\nclass=gap-part\\n\\ntext=m\\nclass=bar:flex\\ntitle=2\\n\\nitems=list\\n\\nitem=a\\nparent=list\\ntitle=A\\n\\nitem=b\\nparent=list\\ntitle=B\\n'")
        let sheet = try sheet("pulls")

        try await wait("the mark") { self.runs.menuBarMarks.first?.mark.content == .text("2") }

        XCTAssertEqual(runs.menuBarMarks.first?.mark.summary, "Pull requests: 2")
        XCTAssertEqual(sheet.list.shown.count, 2)
    }

    func testASpotShowsInTheMenuBarWhenThePersonPutsItThereWithItsBarLayoutOrElseItsIcon() async throws {
        try script("cups", toml: "title = 'Cups'\n[on]\nevery = 5", log: "cups", "printf 'frame=\\nclass=gap-part\\n\\ntext=t\\nclass=bar:flex\\ntitle=3\\n'")
        try script("notes", toml: "title = 'Notes'\nicon = 'note.text'\n[on]\nevery = 5", log: "notes", "printf 'text=t\\ntitle=4\\n'")
        _ = try scanned()
        XCTAssertTrue(runs.menuBarMarks.isEmpty)

        menuBar = ["cups", "notes"]
        _ = try scanned()

        try await wait("both marks") { self.runs.menuBarMarks.count == 2 && self.runs.menuBarMarks.first?.mark.summary == "Cups: 3" && self.log("notes").count == 1 }
        XCTAssertEqual(runs.menuBarMarks.map(\.id), ["cups", "notes"])
        XCTAssertEqual(runs.menuBarMarks.last?.mark, MenuBarMark(icon: "note.text", name: "Notes"))
    }

    func testTheMenuBarHearsOfAMarkThatComesAfterItFirstLooked() async throws {
        let changed = expectation(description: "a change of the marks")
        changed.assertForOverFulfill = false
        withObservationTracking { _ = runs.menuBarMarks } onChange: { changed.fulfill() }
        menuBar.insert("agents")
        try script("agents", toml: "[on]\nevery = 5", "printf 'frame=\\nclass=gap-part\\n\\ntext=a\\nclass=bar:flex\\n\\nitems=list\\n\\ntext=b\\nparent=list\\n'")

        _ = try scanned()

        await fulfillment(of: [changed], timeout: 60)
    }

    func testEachMomentReadsOnlyTheScriptsThatListIt() async throws {
        try script("onsheet", toml: "", log: "onsheet", "printf 'text=s\\ntitle=S\\n'")
        try script("ontimer", toml: "[on]\nevery = 600", log: "ontimer", "printf 'text=t\\ntitle=T\\n'")
        try script("onpanel", toml: "[on]\n\"panel.open\" = true", log: "onpanel", "printf 'text=m\\ntitle=P\\n'")
        _ = try scanned()
        try await pause(0.1)
        XCTAssertEqual(log("onsheet") + log("ontimer") + log("onpanel"), [])

        runs.woke()
        try await pause(0.1)
        XCTAssertEqual(log("onsheet") + log("ontimer") + log("onpanel"), [])

        runs.panelOpened()
        try await wait("the panel read") { self.log("onpanel") == ["show"] }
        XCTAssertEqual(log("onsheet") + log("ontimer"), [])
    }

    func testAnOpenSheetOfRowsIsNotReadWithThePanelClosedAndIsReadWhenThePanelOpens() async throws {
        try script(toml: "[on]\nevery = 5", "printf 'item=a\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 && sheet.calls.isEmpty }
        XCTAssertEqual(log(), ["show"])
        time += 5
        runs.raise(.clock)
        try await wait("the read from the number") { self.log() == ["show", "every"] && sheet.calls.isEmpty }

        runs.panelClosed()
        XCTAssertTrue(sheet.isOpen)
        time += 5
        runs.raise(.clock)
        try await pause(0.15)
        XCTAssertEqual(log(), ["show", "every"])

        time += 5
        runs.panelOpened()
        try await wait("the read when the panel opens") { self.log() == ["show", "every", "show"] }
    }

    func testAStreamOfAnOpenSheetOfRowsStopsWhenThePanelClosesAndStartsWhenItOpens() async throws {
        try script(toml: "", "printf 'item=a\\ntitle=A\\n---\\n'\nsleep 5\ntouch '\(path("went-on"))'")
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
        try await wait("the new read") { self.log() == ["show", "show"] }
    }

    func testTheSheetOfASpotThatUsesTheTimelineStopsWhenThePanelCloses() async throws {
        try script(toml: "uses = ['timeline']\n\n[on]\n\"clipboard.change\" = true", "printf 'item=a\\ntitle=A\\n---\\n'\nsleep 5\ntouch '\(path("went-on"))'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        runs.panelClosed()
        try await allEnded()

        XCTAssertFalse(exists("went-on"))
    }

    func testAnEventThatWaitsOnTheSheetOfASpotThatUsesTheTimelineRunsOnceThePanelClosesItsShow() async throws {
        try script(toml: "uses = ['timeline']\n\n[on]\n\"clipboard.change\" = true", "[ \"$1\" = clipboard.change ] && touch '\(path("heard"))' && exit 0\nprintf 'item=a\\ntitle=A\\n---\\n'\nsleep 5")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the show") { self.runs.isShowing }
        runs.raise(.named("clipboard.change", value: nil))

        runs.panelClosed()

        try await wait("the event's run") { self.exists("heard") }
    }

    func testTheShowOfASpotInTheMenuBarStopsWhenTheSpotIsRemoved() async throws {
        menuBar.insert("script")
        let url = try script(toml: "[on]\nevery = 60", "printf 'text=t\\ntitle=1\\n---\\n'\nsleep 5\ntouch '\(path("went-on"))'")
        _ = try scanned()
        try await wait("the show") { self.log().count == 1 && self.runs.isShowing }

        try FileManager.default.removeItem(at: url.deletingLastPathComponent())
        _ = try scanned()
        try await allEnded()

        XCTAssertFalse(exists("went-on"))
    }

    func testAScriptInTheMenuBarIsReadOnItsClockWithThePanelClosed() async throws {
        menuBar.insert("script")
        try script(toml: "[on]\nevery = 1", "printf 'text=t\\ntitle=1\\n'")
        _ = try scanned()
        try await wait("the first read") { self.log().count == 1 && !self.runs.isShowing }

        time += 1

        try await wait("the read from the clock") { self.log().count == 2 }
    }

    func testTheClockLooksAtTheTimeOnlyWhenAReadIsDue() async throws {
        nonisolated(unsafe) var looks = 0
        runs = SpotRuns(clock: RunClock(now: { [clock] in
            looks += 1
            return clock.time
        }, sleep: clock.value.sleep), stopPause: 0.2)
        menuBar.insert("script")
        try script(toml: "[on]\nevery = 5", "printf 'text=t\\ntitle=1\\n'")
        _ = try scanned()
        try await wait("the first read") { self.log().count == 1 && self.runs.sheets["script"]?.calls.isEmpty == true }
        let before = looks

        try await pause(0.5)

        XCTAssertLessThanOrEqual(looks - before, 1)
        XCTAssertEqual(log().count, 1)
    }

    func testAScriptWantedWhileTheClockWaitsForALaterReadIsReadOnItsOwnTime() async throws {
        menuBar.insert("pulls")
        try script("pulls", toml: "[on]\nevery = 120", log: "pulls", "printf 'text=t\\ntitle=1\\n'")
        try script(toml: "[on]\nevery = 1", "printf 'text=a\\ntitle=A\\n'")
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
        try script("pulls", toml: "[on]\nevery = 120", log: "pulls", "printf 'text=t\\ntitle=1\\n'")
        try script("stayer", toml: "stay = true\n[on]\nevery = 1", """
        while IFS= read -r line; do
          printf '%s\\n' "$line" >> '\(path("blocks"))'
          case "$line" in call=*) call=${line#call=}; args= ;; arg=*) args="$args ${line#arg=}" ;; esac
          [ -n "$line" ] || [ "$args" = ' go' ] || printf 'end=%s\\n\\ntext=t\\ntitle=1\\n---\\n' "$call"
        done
        """)
        _ = try scanned()
        try await wait("the read of the menu bar spot") { self.log("pulls").count == 1 }
        let stayer = try XCTUnwrap(runs.sheets["stayer"])

        stayer.pressKey("go")
        try await wait("the call and the first read") { self.blocks().contains("arg=go") && self.reads() == 1 && !self.runs.isShowing }
        time += 1

        try await wait("the read from the clock") { self.reads() == 2 }
    }

    func testSearchTextReachesTheScriptAfterAPause() async throws {
        try script(toml: "[on]\n\"sheet.open\" = true\n\"sheet.text\" = true", "\(TestSpot.event)\nprintf 'item=a\\ntitle=%s\\n' \"${val:-none}\"")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the first answer") { sheet.list.shown.map(\.title) == ["none"] }

        for text in ["r", "re", "rep"] {
            sheet.search(text)
        }
        XCTAssertEqual(log(), ["show"])

        try await wait("the answer") { sheet.list.shown.map(\.title) == ["rep"] }
        XCTAssertEqual(log(), ["show", "sheet.text"])
    }

    func testANewKeyStopsTheOlderSearch() async throws {
        try script(toml: "[on]\n\"sheet.open\" = true\n\"sheet.text\" = true", """
        \(TestSpot.event)
        [ "$val" = slow ] && { sleep 5; touch '\(path("went-on"))'; }
        printf 'item=a\\ntitle=%s\\n' "${val:-none}"
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
        try script("a", toml: "[on]\nevery = 30\nsearch = true")
        try script("b", toml: "[on]\n\"panel.open\" = true\nevery = 30\nsearch = true")

        let scan = try SpotsFolder(url: folder).scan()

        XCTAssertEqual(scan.refused, [])
        XCTAssertEqual(scan.spots.map(\.triggers.lists), [true, true])
        XCTAssertEqual(scan.spots.map(\.headerState.isOnGrid), [false, false])
    }

    func testThePlaygroundAsksAFileWithNoReadWhatToShow() async throws {
        let url = try script(body: "printf 'frame=\\nclass=gap-part\\n\\ntext=a\\ntitle=%s\\n' \"$#\"")
        let sheet = runs.sheet(for: Playground.command(file: url))

        sheet.open {}

        try await wait("the sheet") { sheet.panel?.parts.first?.title == "1" }
        XCTAssertEqual(log(), ["show"])
    }

    func testThePlaygroundReadsAFileWithARead() async throws {
        let url = try script(toml: "[on]\n\"panel.open\" = true", "printf 'frame=\\nclass=gap-part\\n\\ntext=a\\ntitle=%s\\n' \"$1\"")
        let sheet = runs.sheet(for: Playground.command(file: url))

        sheet.open {}

        try await wait("the sheet") { sheet.panel?.parts.first?.title == "show" }
    }
}
