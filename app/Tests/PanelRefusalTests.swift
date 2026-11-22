import XCTest
@testable import OpenspotCore

@MainActor
final class PanelRefusalTests: PanelCase {
    private var clock = FakeClock()

    override func setUp() async throws {
        try await super.setUp()
        let files = model.files
        model.quit()
        model = SpotsModel(host: host, files: files, runs: SpotRuns(clock: clock.value, stopPause: stopPause))
        host.model = model
        let started = folder.appendingPathComponent("started").path
        let go = folder.appendingPathComponent("go").path
        try script("tabs", toml: "title = 'Tabs'", """
        [ "$1" = press ] || { printf 'text=current\\ntitle=Snooze Current Tab\\nclose=false\\n'; exit 0; }
        touch '\(started)'
        [ "$(sed -n 's/^input\\.item=//p')" = slow ] && while [ ! -f '\(go)' ]; do sleep 0.01; done
        echo 'Ghostty is not a browser' >&2
        exit 1
        """)
        await model.reload()
        model.isShown = true
        model.panelWillShow()
    }

    func testAPressThatFailsAtOnceShakesWhatWasPressed() async throws {
        let entry = try XCTUnwrap(model.entry("tabs"))

        model.pick(SpotItem(title: "Snooze Current Tab", run: "current", staysOnPick: true), of: entry)

        try await wait("the mark") { self.model.failure(of: "current", in: "tabs") != nil }
        try await wait("the toast") { self.host.notes == ["Ghostty is not a browser"] }
        try await wait("the shake") { self.model.refusals(of: "current", in: "tabs") == 1 }
        XCTAssertEqual(model.refusals(of: nil, in: "tabs"), 0)
    }

    func testAPressThatFailsLateOnlyMarksWhatWasPressed() async throws {
        let entry = try XCTUnwrap(model.entry("tabs"))

        model.pick(SpotItem(title: "Later", run: "slow", staysOnPick: true), of: entry)
        try await wait("the run") { FileManager.default.fileExists(atPath: self.folder.appendingPathComponent("started").path) }
        clock.advance(by: 1)
        FileManager.default.createFile(atPath: folder.appendingPathComponent("go").path, contents: nil)

        try await wait("the mark") { self.model.failure(of: "slow", in: "tabs") != nil }
        XCTAssertEqual(model.refusals(of: "slow", in: "tabs"), 0)
    }
}
