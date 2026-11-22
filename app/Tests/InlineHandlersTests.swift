import XCTest
@testable import OpenspotCore

@MainActor
final class InlineHandlersTests: SpotRunsCase {
    override func setUp() async throws {
        try await super.setUp()
        takeCalls()
    }

    private func inline(_ name: String, toml: String, _ body: String) throws {
        let url = folder.spotFile(name, extension: "js")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "\(body)\n".write(to: url, atomically: true, encoding: .utf8)
        try toml.write(to: url.deletingLastPathComponent().appendingPathComponent(Manifest.fileName), atomically: true, encoding: .utf8)
    }

    private func spot(_ id: String) throws -> Spot {
        try XCTUnwrap(try scanned().scripts.first { $0.id == id })
    }

    func testAHandlerNamedForAnActionGetsItsTypedInputsAndItsSettingsAndAnswersWithItsOutputs() async throws {
        try inline("counter", toml: "[settings]\nstep = { type = 'number', default = '2' }\n[actions.add]\ninputs.n = 'number'\ninputs.tags = '[text]'\noutputs.sum = 'number'\noutputs.kind = 'text'", """
        export default {
          async add({ n, tags }, env) {
            return { sum: n + env.settings.step, kind: `${typeof n} ${tags.length}` }
          },
        }
        """)

        let text = try await runs.answer(of: try spot("counter"), SpotAction(arguments: ["add"]), input: "input.n=4\ninput.tags=a\nsetting.step=2\n", limit: 60)

        XCTAssertEqual(Frame(text: text).outputs, [.init(key: "sum", value: "6"), .init(key: "kind", value: "number 1")], text)
    }

    func testHandlersRunABoundActionEmitAnEventAndHearItInAnotherSpot() async throws {
        try script("picker", toml: "[actions.pick]\noutputs.until = 'date'", log: "picker-log", """
        case "$1" in pick) echo out.until=2026-11-23 ;; esac
        """)
        try script("logger", toml: "[actions.write]\ninputs.line = 'text'", log: "logger-log", """
        case "$1" in write) sed -n 's/^input.line=//p' >> '\(path("heard"))' ;; esac
        """)
        try inline("snoozer", toml: "[actions.snooze]\ninputs.url = 'url'\noutputs.until = 'date'\n[events.snoozed]\nurl = 'url'\nuntil = 'date'\n[bindings]\npicker = { spot = 'picker' }", """
        export default {
          async snooze({ url }, env) {
            const { until } = await env.picker.pick()
            await env.emit("snoozed", { url, until })
            return { until }
          },
        }
        """)
        try inline("listener", toml: "[bindings]\nsnoozer = { spot = 'snoozer' }\nlogger = { spot = 'logger' }\n[on]\n\"snoozer.snoozed\" = true", """
        export default {
          async "snoozer.snoozed"({ url, until }, env) {
            await env.logger.write({ line: `${url} ${until}` })
          },
        }
        """)

        let text = try await runs.answer(of: try spot("snoozer"), SpotAction(arguments: ["snooze"]), input: "input.url=https://example.com/a\n", limit: 60)

        XCTAssertEqual(Frame(text: text).outputs, [.init(key: "until", value: "2026-11-23")], text)
        try await wait("the event handler of the listener") { self.log("heard") == ["https://example.com/a 2026-11-23"] }
    }

    func testEnvHoldsEachCommandThatNeedsNoUseAndNoCommandOfAnUndeclaredUse() async throws {
        try inline("summer", toml: "[actions.sum]\noutputs.sum = 'text'\noutputs.kinds = 'text'", """
        export default {
          async sum(input, env) {
            const solved = await env.calc.solve("2+3")
            return { sum: solved.split("\\n")[0], kinds: `${typeof env.toast} ${typeof env.clipboard}` }
          },
        }
        """)

        let text = try await runs.answer(of: try spot("summer"), SpotAction(arguments: ["sum"]), limit: 60)

        XCTAssertEqual(Frame(text: text).outputs, [.init(key: "sum", value: "item=5"), .init(key: "kinds", value: "function undefined")], text)
    }

    func testAThrowInAHandlerFailsTheCallWithItsMessage() async throws {
        try inline("failing", toml: "[actions.go]", "export default { async go() { await null; throw new Error('No sky today') } }")

        do {
            _ = try await runs.answer(of: try spot("failing"), SpotAction(arguments: ["go"]), limit: 60)
            XCTFail("the call did not fail")
        } catch {
            XCTAssertEqual(SpotRuns.reason(error), "No sky today")
        }
    }

    func testABoundActionThatFailsRejectsWithItsMessage() async throws {
        try script("picker", toml: "[actions.pick]\noutputs.until = 'date'", log: "picker-log", "echo 'error=No time left'")
        try inline("asker", toml: "[actions.ask]\noutputs.said = 'text'\n[bindings]\npicker = { spot = 'picker' }", """
        export default {
          async ask(input, env) {
            try { await env.picker.pick() } catch (error) { return { said: error.message } }
            return { said: "no failure" }
          },
        }
        """)

        let text = try await runs.answer(of: try spot("asker"), SpotAction(arguments: ["ask"]), limit: 60)

        XCTAssertEqual(Frame(text: text).outputs, [.init(key: "said", value: "No time left")], text)
    }

    private func shortLimit() {
        runs.quit()
        runs = SpotRuns(environment: ProcessInfo.processInfo.environment, showLimit: 0.2, clock: clock.value, stopPause: 0.2)
        takeCalls()
    }

    private func outcome(of id: String, _ handler: String) async throws -> (outcome: InlineCall.Outcome, seconds: TimeInterval) {
        let script = runs.script(of: try spot(id))
        defer { script.end() }
        let call = InlineCall(arguments: [handler])
        let started = Date()
        script.send(call)
        let outcome = await call.outcome()
        return (outcome, Date().timeIntervalSince(started))
    }

    func testAHandlerThatRunsPastItsLimitAfterAnAwaitIsStopped() async throws {
        shortLimit()
        try inline("spinner", toml: "[actions.spin]", """
        export default {
          async spin() { await null; const end = Date.now() + 2000; while (Date.now() < end) {} return "text=a\\n" },
        }
        """)

        let (outcome, seconds) = try await outcome(of: "spinner", "spin")

        guard case .failed(let error) = outcome else { return XCTFail("the loop was not stopped") }
        XCTAssertEqual(error as? SpotError, .timedOut)
        XCTAssertLessThan(seconds, 1.5)
    }

    func testTheTimeAHandlerRunsAddsUpAcrossItsAwaits() async throws {
        shortLimit()
        try script("ticker", toml: "[actions.tick]", log: "ticker-log", "")
        try inline("spinner", toml: "[actions.spin]\n[bindings]\nticker = { spot = 'ticker' }", """
        export default {
          async spin(input, env) {
            for (let i = 0; i < 8; i++) {
              const end = Date.now() + 100
              while (Date.now() < end) {}
              await env.ticker.tick()
            }
            return "text=a\\n"
          },
        }
        """)

        let (outcome, _) = try await outcome(of: "spinner", "spin")

        guard case .failed(let error) = outcome else { return XCTFail("the handler ran past its limit") }
        XCTAssertEqual(error as? SpotError, .timedOut)
        XCTAssertLessThan(log("ticker-log").count, 8)
    }
}
