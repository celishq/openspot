import XCTest
@testable import OpenspotCore

@MainActor
final class SpotTimersTests: PanelCase {
    private var clock = FakeClock()

    private var timersFile: URL {
        folder.appendingPathComponent("config/timers.json")
    }

    override func setUp() async throws {
        try await super.setUp()
        try relaunch()
        try writeSpot("later")
        try writeSpot("other")
        await model.reload()
    }

    private func relaunch() throws {
        let files = model.files
        model.quit()
        model = SpotsModel(host: host, files: files, runs: SpotRuns(clock: clock.value, stopPause: stopPause, timers: timersFile))
        host.model = model
        takeCalls()
    }

    private func writeSpot(_ name: String) throws {
        try script(name, toml: "title = '\(name)'\nuses = ['timer']\n[commands.go]\ntitle = 'Go'", """
        in=$(cat)
        [ "$1" = due ] && printf '%s %s|%s\\n' "$1" "$2" "$(printf '%s' "$in" | tr '\\n' ' ')" >> '\(log(name).path)'
        exit 0
        """)
    }

    private func log(_ name: String) -> URL {
        folder.appendingPathComponent("\(name).log")
    }

    private func lines(_ name: String) -> [String] {
        ((try? String(contentsOf: log(name), encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    private func call(_ words: [String], as spot: String?) async throws -> CommandAnswer {
        let api = try XCTUnwrap(model.runs.api)
        let caller = try spot.map { SpotCaller(spot: try XCTUnwrap(model.sheets[$0]?.spot)) }
        let request = CommandRequest(arguments: words, folder: folder.path, caller: caller)
        let work = try XCTUnwrap(api.work(for: request, input: { "" }))
        return await work()
    }

    private func time(in seconds: TimeInterval) -> String {
        ISO8601DateFormatter().string(from: clock.time.addingTimeInterval(seconds))
    }

    private func add(in seconds: TimeInterval, _ value: String, as spot: String = "later") async throws -> String {
        let answer = try await call(["timer", "add", time(in: seconds), value], as: spot)
        XCTAssertEqual(answer.code, 0, answer.errors)
        return answer.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func testADueTimerCallsItsSpotWhileThePanelIsHidden() async throws {
        let id = try await add(in: 60, "https://example.com")

        clock.advance(by: 60)

        try await wait("the due call") { self.lines("later").count == 1 }
        let line = try XCTUnwrap(lines("later").first)
        XCTAssertTrue(line.hasPrefix("due \(id)|"), line)
        XCTAssertTrue(line.contains("event=timer.due"), line)
        XCTAssertTrue(line.contains("event.value=https://example.com"), line)
        XCTAssertTrue(line.contains("timer.late=0"), line)
    }

    func testATimerOutlivesARelaunchAndTellsHowLateItIs() async throws {
        let id = try await add(in: 60, "tab")
        model.quit()
        clock.advance(by: 3600)

        try relaunch()
        await model.reload()
        model.runs.launched()

        try await wait("the late call") { self.lines("later").count == 1 }
        let line = try XCTUnwrap(lines("later").first)
        XCTAssertTrue(line.hasPrefix("due \(id)|"), line)
        XCTAssertTrue(line.contains("timer.late=3540"), line)
    }

    func testARemovedTimerNeverFires() async throws {
        let gone = try await add(in: 30, "gone")
        let kept = try await add(in: 60, "kept")
        let removed = try await call(["timer", "remove", gone], as: "later")
        XCTAssertEqual(removed.code, 0, removed.errors)

        clock.advance(by: 60)

        try await wait("the kept call") { self.lines("later").contains { $0.hasPrefix("due \(kept)|") } }
        XCTAssertEqual(lines("later").count, 1)
    }

    func testATimerFiresOnce() async throws {
        let first = try await add(in: 10, "first")
        clock.advance(by: 10)
        try await wait("the first call") { self.lines("later").count == 1 }
        let second = try await add(in: 10, "second")

        clock.advance(by: 10)

        try await wait("the second call") { self.lines("later").count == 2 }
        XCTAssertEqual(lines("later").map { String($0.prefix { $0 != "|" }) }, ["due \(first)", "due \(second)"])
    }

    func testListShowsOnlyTheCallersTimers() async throws {
        let id = try await add(in: 60, "mine")
        _ = try await add(in: 90, "theirs", as: "other")

        let list = try await call(["timer", "list"], as: "later")

        XCTAssertEqual(list.code, 0, list.errors)
        let blocks = TextBlock.blocks(in: list.output)
        XCTAssertEqual(blocks.map { $0.value("item") }, [id])
        XCTAssertEqual(blocks.first?.value("title"), "mine")
        XCTAssertEqual(blocks.first?.value("at"), time(in: 60))
    }

    func testAnotherSpotCannotRemoveATimer() async throws {
        let id = try await add(in: 60, "mine")

        let removed = try await call(["timer", "remove", id], as: "other")
        clock.advance(by: 60)

        XCTAssertEqual(removed.code, 1)
        try await wait("the call") { self.lines("later").count == 1 }
    }

    func testASomedayTimerIsListedAndNeverComesDue() async throws {
        let answer = try await call(["timer", "add", "someday", "later"], as: "later")
        XCTAssertEqual(answer.code, 0, answer.errors)
        let id = answer.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let soon = try await add(in: 60, "soon")

        clock.advance(by: 3600 * 24 * 365)

        try await wait("the timed call") { self.lines("later").contains { $0.hasPrefix("due \(soon)|") } }
        XCTAssertEqual(lines("later").count, 1)
        let listed = TextBlock.blocks(in: try await call(["timer", "list"], as: "later").output)
        XCTAssertEqual(listed.map { $0.value("item") }, [id])
        XCTAssertEqual(listed.first?.value("at"), "someday")
        let removed = try await call(["timer", "remove", id], as: "later")
        XCTAssertEqual(removed.code, 0)
    }

    func testThePersonCannotAddATimer() async throws {
        let answer = try await call(["timer", "add", time(in: 60)], as: nil)

        XCTAssertEqual(answer.code, 1)
        XCTAssertTrue(answer.errors.contains("spot"), answer.errors)
    }

    func testATimeWithNoOffsetIsRefused() async throws {
        let answer = try await call(["timer", "add", "tomorrow"], as: "later")

        XCTAssertEqual(answer.code, 1)
        XCTAssertTrue(answer.errors.contains("2026-11-20T08:00:00+01:00"), answer.errors)
    }
}
