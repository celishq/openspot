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

        let text = try await runs.answer(of: try spot("counter"), "add", input: "input.n=4\ninput.tags=a\nsetting.step=2\n", limit: 60)

        XCTAssertEqual(Frame(text: text).outputs, [.init(key: "sum", value: "6"), .init(key: "kind", value: "number 1")], text)
    }

    func testAHandlerGetsAnEscapedInputAsItsText() async throws {
        try inline("notes", toml: "[actions.save]\ninputs.note = 'text'", """
        export default {
          async save({ note }) {
            return [{ item: "t", title: note }]
          },
        }
        """)

        let text = try await runs.answer(of: try spot("notes"), "save", input: "input.note=a\\\\b\n", limit: 60)

        XCTAssertEqual(Frame(text: text).items.first?.title, "a\\b", text)
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

        let text = try await runs.answer(of: try spot("snoozer"), "snooze", input: "input.url=https://example.com/a\n", limit: 60)

        XCTAssertEqual(Frame(text: text).outputs, [.init(key: "until", value: "2026-11-23")], text)
        try await wait("the event handler of the listener") { self.log("heard") == ["https://example.com/a 2026-11-23"] }
    }

    func testEnvWritesAnOptionWhereTheUsageOfItsCommandNamesIt() async throws {
        try inline("setter", toml: "uses = ['spots']\n[actions.go]\noutputs.said = 'text'", """
        export default {
          async go(input, env) {
            await env.setting.set("tone", "loud", { spot: "other" })
            return { said: await env.setting.get("tone", { spot: "other" }) }
          },
        }
        """)

        let text = try await runs.answer(of: try spot("setter"), "go", limit: 60)

        XCTAssertEqual(Frame(text: text).outputs, [.init(key: "said", value: "loud")], text)
    }

    func testACommandThatFailsOutsideTheAppRejectsWithWhatItPrintedOnStderr() async throws {
        let tools = folder.appendingPathComponent("tools")
        try "#!/bin/sh\necho 'Openspot is not running.' >&2\nexit 2\n".writeScript(to: tools.appendingPathComponent("openspot"))
        try inline("toaster", toml: "[actions.go]\noutputs.said = 'text'", """
        export default {
          async go(input, env) {
            try { await env.toast("Hi") } catch (error) { return { said: error.message } }
          },
        }
        """)
        let bare = SpotRuns(environment: TestEnvironment.values.merging(["PATH": "\(tools.path):/usr/bin:/bin"]) { _, new in new })
        defer { bare.quit() }

        let text = try await bare.answer(of: try spot("toaster"), "go", limit: 60)

        XCTAssertEqual(Frame(text: text).outputs, [.init(key: "said", value: "Openspot is not running.")], text)
    }

    func testEnvToastPassesItsOptionsBeforeItsWords() async throws {
        let tools = folder.appendingPathComponent("tools")
        try "#!/bin/sh\nprintf '%s|' \"$@\" >&2\nexit 2\n".writeScript(to: tools.appendingPathComponent("openspot"))
        try inline("toaster", toml: "[actions.go]\noutputs.said = 'text'", """
        export default {
          async go(input, env) {
            try { await env.toast("Uploading", { id: "up", action: "go" }) } catch (error) { return { said: error.message } }
          },
        }
        """)
        let bare = SpotRuns(environment: TestEnvironment.values.merging(["PATH": "\(tools.path):/usr/bin:/bin"]) { _, new in new })
        defer { bare.quit() }

        let text = try await bare.answer(of: try spot("toaster"), "go", limit: 60)

        XCTAssertEqual(Frame(text: text).outputs, [.init(key: "said", value: "toast|--id|up|--action|go|Uploading|")], text)
    }

    func testEnvHoldsEachCommandThatNeedsNoUseAndNoCommandOfAnUndeclaredUse() async throws {
        try inline("summer", toml: "[actions.sum]\noutputs.sum = 'text'\noutputs.kinds = 'text'", """
        export default {
          async sum(input, env) {
            const solved = await env.version()
            return { sum: solved, kinds: `${typeof env.toast} ${typeof env.clipboard}` }
          },
        }
        """)

        let text = try await runs.answer(of: try spot("summer"), "sum", limit: 60)

        XCTAssertEqual(Frame(text: text).outputs, [.init(key: "sum", value: (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")), .init(key: "kinds", value: "function undefined")], text)
    }

    func testTheMainSearchAndAPressCallTheHandlersOfAnInlineSpot() async throws {
        try inline("finder", toml: "[on]\nsearch = \".\"\n\"sheet.open\" = true", """
        export default {
          search({ text }) { return `item=${text}\\ntitle=Found ${text}\\n` },
          show() { return "item=a\\ntitle=A\\n" },
          async press({ item }) { await null; throw new Error(`pressed ${item}`) },
        }
        """)
        _ = try scanned()
        let sheet = try XCTUnwrap(runs.sheets["finder"])

        runs.raise(.query("2+2"))
        try await wait("the answer") { sheet.answers.map(\.run) == ["2+2"] }
        sheet.pick(SpotItem(title: "A", run: "a"))

        try await wait("the press") { sheet.failure.map { "\($0)" }?.contains("pressed a") == true }
    }

    func testAThrowInAHandlerFailsTheCallWithItsMessage() async throws {
        try inline("failing", toml: "[actions.go]", "export default { async go() { await null; throw new Error('No sky today') } }")

        do {
            _ = try await runs.answer(of: try spot("failing"), "go", limit: 60)
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

        let text = try await runs.answer(of: try spot("asker"), "ask", limit: 60)

        XCTAssertEqual(Frame(text: text).outputs, [.init(key: "said", value: "No time left")], text)
    }

    private func shortLimit() {
        runs.quit()
        runs = SpotRuns(environment: ProcessInfo.processInfo.environment, showLimit: 0.2, clock: clock.value, stopPause: 0.2)
        takeCalls()
    }

    private func outcome(of id: String, _ handler: String) async throws -> InlineCall.Outcome {
        let script = runs.script(of: try spot(id))
        defer { script.end() }
        let call = InlineCall(arguments: [handler])
        script.send(call)
        return await call.outcome()
    }

    func testAHandlerThatRunsPastItsLimitAfterAnAwaitIsStopped() async throws {
        shortLimit()
        try inline("spinner", toml: "[actions.spin]", """
        export default {
          async spin() { await null; while (true) {} },
        }
        """)

        let outcome = try await outcome(of: "spinner", "spin")

        guard case .failed(let error) = outcome else { return XCTFail("the loop was not stopped") }
        XCTAssertEqual(error as? SpotError, .timedOut)
    }

    func testTheTimeAHandlerRunsAddsUpAcrossItsAwaits() async throws {
        let thread = FakeClock(threadStep: 0.03)
        runs.quit()
        runs = SpotRuns(environment: ProcessInfo.processInfo.environment, showLimit: 0.2, clock: thread.value, stopPause: 0.2)
        takeCalls()
        try script("ticker", toml: "[actions.tick]", log: "ticker-log", "")
        try inline("spinner", toml: "[actions.spin]\n[bindings]\nticker = { spot = 'ticker' }", """
        export default {
          async spin(input, env) {
            for (let i = 0; i < 12; i++) { await env.ticker.tick() }
            return "text=a\\n"
          },
        }
        """)

        let outcome = try await outcome(of: "spinner", "spin")

        guard case .failed(let error) = outcome else { return XCTFail("the handler ran past its limit") }
        XCTAssertEqual(error as? SpotError, .timedOut)
        XCTAssertLessThan(log("ticker-log").count, 12)
    }

    func testAHandlerThatAwaitsAPromiseThatNothingSettlesFailsAtTheIdleTimeAndLetsGoOfTheThread() async throws {
        runs.quit()
        runs = SpotRuns(environment: ProcessInfo.processInfo.environment, clock: clock.value, stopPause: 0.2, inlineIdle: 0.3)
        takeCalls()
        try inline("waiter", toml: "[actions.hang]", "export default {\n  async hang() { await new Promise(() => {}) },\n}")
        let script = runs.script(of: try spot("waiter"))
        defer { script.end() }
        let call = InlineCall(arguments: ["hang"])

        script.send(call)
        let outcome = await call.outcome(limit: 10)

        guard case .failed(let error) = outcome else { return XCTFail("the call did not end") }
        XCTAssertEqual(SpotsModel.reason(error), "hang of Waiter waits for a promise that nothing settles, so Openspot ended it.")
        try await wait("the thread let go") { !script.isRunning }
    }

    @MainActor func testAWaitInEnvCountsAgainstTheClockLimitOfACallThatOpenspotTimesAsAWhole() async throws {
        try script("picker", toml: "[actions.slow]\noutputs.v = 'text'", log: "picker-log", "[ \"$1\" = slow ] && sleep 1 && echo out.v=late")
        try inline("asker", toml: "[bindings]\npicker = { spot = 'picker' }", "export default {\n  async show(input, env) { const got = await env.picker.slow(); return `text=a\\ntitle=${got.v}\\n` },\n}")
        let asker = try spot("asker")

        let first = Task { try await self.runs.answer(of: asker, ScriptEntry.show.name, limit: 0.3) }
        try await pass(0.3, on: clock)
        do {
            let shown = try await first.value
            XCTFail("the show outlasted its limit: \(shown)")
        } catch {
            XCTAssertEqual(error as? SpotError, .timedOut)
        }
        let shown = try await runs.answer(of: asker, ScriptEntry.show.name, limit: 10)

        XCTAssertEqual(TextBlock.blocks(in: shown).first?.value("title"), "late")
    }
}
