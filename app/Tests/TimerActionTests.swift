import XCTest
@testable import OpenspotCore

@MainActor
final class TimerActionTests: PanelCase {
    private var clock = FakeClock()

    private var timersFile: URL {
        folder.appendingPathComponent("config/timers.json")
    }

    override func setUp() async throws {
        try await super.setUp()
        try relaunch()
        try script("snooze", toml: "uses = ['timer']\n[actions.wake]\ninputs.url = { type = 'url', required = true }\ninputs.size = { type = 'choice', options = ['s', 'm'], default = 'm' }", """
        printf '%s|%s\\n' "$*" "$(grep '^input\\.' | tr '\\n' ' ')" >> '\(folder.appendingPathComponent("calls").path)'
        """)
        await model.reload()
    }

    private func relaunch() throws {
        let files = model.files
        model.quit()
        model = SpotsModel(host: host, files: files, runs: SpotRuns(clock: clock.value, stopPause: stopPause, timers: timersFile))
        host.model = model
        takeCalls()
    }

    private var calls: [String] {
        ((try? String(contentsOf: folder.appendingPathComponent("calls"), encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    private func call(_ words: [String]) async throws -> CommandAnswer {
        let api = try XCTUnwrap(model.runs.api)
        let caller = SpotCaller(spot: try XCTUnwrap(model.sheets["snooze"]?.spot))
        let work = try XCTUnwrap(api.work(for: CommandRequest(arguments: words, folder: folder.path, caller: caller), input: { "" }))
        return await work()
    }

    private func time(in seconds: TimeInterval) -> String {
        ISO8601DateFormatter().string(from: clock.time.addingTimeInterval(seconds))
    }

    func testATimerWithAWrongInputFailsWhenItIsAdded() async throws {
        let cases: [([String], String)] = [
            (["wake"], "url"),
            (["wake", "url=not a url"], "url"),
            (["wake", "url=https://a.com", "size=xl"], "size"),
            (["wake", "url=https://a.com", "colour=red"], "colour"),
            (["wake", "https://a.com"], "https://a.com"),
            (["sleep", "url=https://a.com"], "sleep")
        ]
        for (words, named) in cases {
            let answer = try await call(["timer", "add", time(in: 60)] + words)

            XCTAssertEqual(answer.code, 2, words.joined(separator: " "))
            XCTAssertTrue(answer.errors.contains(named), answer.errors)
        }
        let listed = try await call(["timer", "list"])
        XCTAssertEqual(listed.output, "")
    }

    func testADueTimerCallsItsActionWithItsInputsAfterARelaunch() async throws {
        let added = try await call(["timer", "add", time(in: 60), "wake", "url=https://a.com"])
        XCTAssertEqual(added.code, 0, added.errors)
        model.quit()
        clock.advance(by: 120)

        try relaunch()
        await model.reload()
        model.runs.launched()

        try await wait("the call of the action") { self.calls == ["wake|input.url=https://a.com input.size=m "] }
    }

    func testTheListOfATimerOfAnActionHoldsItsInputs() async throws {
        let added = try await call(["timer", "add", time(in: 60), "wake", "url=https://a.com"])
        XCTAssertEqual(added.code, 0, added.errors)

        let listed = try await call(["timer", "list"])

        let block = try XCTUnwrap(TextBlock.blocks(in: listed.output).first)
        XCTAssertEqual(block.value("title"), "wake")
        XCTAssertEqual(block.value("input.url"), "https://a.com")
    }
}
