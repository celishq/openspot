import Observation
import XCTest
@testable import OpenspotCore

/// Proves what wants a script, each moment, search, the main search and the sandbox.
@MainActor
final class SpotRunsWantTests: SpotRunsCase {
    // MARK: K5

    func testClosingThePanelClosesASheetOfPartsAndTheNextOpenReads() async throws {
        try script(header: "read=sheet", "printf 'field=a\\ntext=one\\n'")
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
        try script(header: "read=sheet", "printf 'row=A\\nrun=a\\n'")
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        runs.panelClosed()

        XCTAssertTrue(sheet.isOpen)
        XCTAssertEqual(sheet.list.shown.count, 1)
    }

    // MARK: F7

    func testAWidgetCanPlaceAnyScriptWithARead() async throws {
        try script("onpanel", header: "read=panel\nkey=p", log: "onpanel", "printf 'text=m\\ntitle=P\\n'")
        try script("onsheet", header: "read=sheet\nkey=s", log: "onsheet", "printf 'text=m\\ntitle=S\\n'")
        try "[[widgets]]\nname = \"W\"\nlayout = \"pair\"\nplaces = [\"onpanel\", \"onsheet\"]\n".write(to: folder.appendingPathComponent("w.toml"), atomically: true, encoding: .utf8)
        _ = try scanned()
        XCTAssertEqual(log("onsheet"), [])

        runs.panelOpened()

        try await wait("the values") { self.runs.readings["onpanel"]?.value?.title == "P" && self.runs.readings["onsheet"]?.value?.title == "S" }
    }

    func testAWidgetCannotPlaceAScriptWithNoRead() throws {
        try script("once")
        try "[[widgets]]\nname = \"W\"\nlayout = \"single\"\nplaces = [\"once\"]\n".write(to: folder.appendingPathComponent("w.toml"), atomically: true, encoding: .utf8)

        let scan = try PluginFolder(url: folder).scan()

        XCTAssertEqual(scan.refused, [ScanResult.Refusal(file: "w", reason: "W names no metric called once")])
    }

    func testTheMenuBarShowsWhatTheSheetHolds() async throws {
        try script("pulls", header: "name=Pull requests\nread=120\nkey=g\ntray=true", "printf 'text=m\\ntitle=2\\n\\nrow=A\\nrun=a\\n\\nrow=B\\nrun=b\\n'")
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
        try script("onlaunch", header: "read=launch", log: "onlaunch", "printf 'title=L\\n'")
        try script("onwake", header: "read=wake", log: "onwake", "printf 'title=W\\n'")
        try script("onpanel", header: "read=panel", log: "onpanel", "printf 'text=m\\ntitle=P\\n'")
        _ = try scanned()
        try await pause(0.1)
        XCTAssertEqual(log("onlaunch") + log("onwake") + log("onpanel"), [])

        runs.arrive(.launch)
        try await wait("the launch read") { self.log("onlaunch") == ["read"] }
        XCTAssertEqual(log("onwake"), [])

        runs.arrive(.wake)
        try await wait("the wake read") { self.log("onwake") == ["read"] }
        XCTAssertEqual(log("onlaunch"), ["read"])
        XCTAssertEqual(log("onpanel"), [])

        runs.arrive(.panel)
        try await wait("the panel read") { self.log("onpanel") == ["read"] }
        XCTAssertEqual(log("onlaunch"), ["read"])
        XCTAssertEqual(log("onwake"), ["read"])
    }

    func testAnOpenSheetOfRowsIsNotReadWithThePanelClosedAndIsReadWhenThePanelOpens() async throws {
        try script(header: "read=5\nkey=a", "printf 'row=A\\nrun=a\\n'")
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
        try script(header: "read=sheet", "printf 'row=A\\nrun=a\\n---\\n'\nsleep 5\ntouch '\(path("went-on"))'")
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

    func testAScriptWithLaunchAndANumberIsReadWithThePanelClosed() async throws {
        try script(header: "read=launch,1\nkey=a", "printf 'title=1\\n'")
        _ = try scanned()
        try await wait("the first read") { self.log().count == 1 }

        time += 1

        try await wait("the read from the clock") { self.log().count == 2 }
    }

    // MARK: C4, the main search, sandbox

    func testSearchTextReachesTheScriptAfterAPause() async throws {
        try script(header: "read=sheet", "printf 'search=script\\n\\nrow=%s\\nrun=a\\n' \"${2:-none}\"")
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
        printf 'search=script\\n\\nrow=%s\\nrun=a\\n' "${2:-none}"
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
        try script("c", header: "read=30\nglobal=true\nkey=c")

        XCTAssertEqual(try PluginFolder(url: folder).scan().refused.map(\.file), ["a", "b"])
        XCTAssertEqual(
            try PluginFolder(url: folder).scan().refused.first?.reason,
            "A needs a key to join the main search, because a number in its read and no key gives it no spot"
        )
    }

    func testTheSandboxClicksAFileWithNoRead() async throws {
        let url = try script(body: "printf 'text=a\\ntitle=%s\\n' \"$#\"")
        let sheet = runs.sheet(for: SheetSandbox.command(file: url))

        sheet.open {}

        try await wait("the sheet") { sheet.panel?.parts.first?.title == "0" }
        XCTAssertEqual(log(), [""])
    }

    func testTheSandboxReadsAFileWithARead() async throws {
        let url = try script(header: "read=panel", "printf 'text=a\\ntitle=%s\\n' \"$1\"")
        let sheet = runs.sheet(for: SheetSandbox.command(file: url))

        sheet.open {}

        try await wait("the sheet") { sheet.panel?.parts.first?.title == "read" }
    }
}
