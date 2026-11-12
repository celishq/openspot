import XCTest
@testable import OpenspotCore

/// Proves how a JavaScript spot answers inside the app: in the turn of the text when it is fast, and in a later turn,
/// with the last rows kept, when it is slow (I3, I5).
@MainActor
final class SpotRunsInlineTests: SpotRunsCase {
    /// A host of the API that reaches nothing on the Mac.
    private final class Host: Mac {
        func eventStore() -> any EventStore { FakeEventStore() }
        func reminderStore() -> any ReminderStore { FakeReminderStore() }
        func showCalendar(at time: Date) throws {}
        func open(_ link: URL) -> Bool { false }
    }

    /// Writes a JavaScript spot with these header lines.
    private func inline(_ name: String = "script", header: String, _ body: String) throws {
        let lines = header.split(separator: "\n").map { "// \($0)\n" }.joined()
        try "\(lines)\(body)\n".write(to: folder.appendingPathComponent("\(name).js"), atomically: true, encoding: .utf8)
    }

    /// A spot that answers each text with one row of it, and works for 300 ms first on the text `slow`.
    private func answering() throws {
        try inline(header: "on=search.text ^[0-9]", """
        function main([id, row], env) {
          const text = id === "open" ? row : env.OPENSPOT_VALUE
          if (text === "12") { const end = Date.now() + 300; while (Date.now() < end) {} }
          return `row=${text}\\ntitle=Is ${text}\\ndetail=${env.OPENSPOT_REASON}\\n`
        }
        """)
    }

    func testAFastInlineSpotAnswersInTheTurnOfTheText() async throws {
        try answering()
        let sheet = try sheet()
        sheet.answer("1")
        try await wait("the loaded script") { sheet.answers.map(\.run) == ["1"] }

        sheet.answer("7")

        XCTAssertEqual(sheet.answers.map(\.run), ["7"])
        XCTAssertEqual(sheet.answers.first?.subtitle, "search.text")
        XCTAssertFalse(sheet.isAnswering)
    }

    func testASlowInlineSpotKeepsTheLastRowsUntilItsAnswerLandsInALaterTurn() async throws {
        try answering()
        let sheet = try sheet()
        sheet.answer("1")

        sheet.answer("12")

        XCTAssertEqual(sheet.answers.map(\.run), ["1"])
        XCTAssertTrue(sheet.isAnswering)
        try await wait("the slow answer") { sheet.answers.map(\.run) == ["12"] }
        XCTAssertFalse(sheet.isAnswering)
    }

    func testANewerTextDropsTheAnswerOfASlowOlderOne() async throws {
        try answering()
        let sheet = try sheet()

        sheet.answer("12")
        sheet.answer("123")

        try await wait("the newest answer") { sheet.answers.map(\.run) == ["123"] }
        try await pause(0.5)
        XCTAssertEqual(sheet.answers.map(\.run), ["123"])
    }

    func testOpenspotCallAsksTheAPIInTheApp() async throws {
        runs.api = CommandAPI(mac: Host())
        try inline(header: "on=search.text ^[0-9]", """
        function main([id, row], env) {
          const text = id === "open" ? row : env.OPENSPOT_VALUE
          const answer = openspot.call(["calc", "solve", text])
          return answer.stdout.replace(/detail=.*/, `detail=${answer.code}`)
        }
        """)
        let sheet = try sheet()

        sheet.answer("2+2")

        try await wait("the answer of the API") { sheet.answers.map(\.run) == ["4"] }
        XCTAssertEqual(sheet.answers.first?.subtitle, "0")
    }

    func testAPickRunsItsOpenFunctionWithTheRow() async throws {
        try inline(header: "on=search.text ^[0-9]", """
        function main([id, row], env) {
          const text = id === "open" ? row : env.OPENSPOT_VALUE
          if (id === "open") return `toast=Picked ${text}\\n`
          return `row=${text}\\ntitle=${text}\\n`
        }
        """)
        let sheet = try sheet()
        var toasts: [String] = []
        sheet.onReport = { if case .toast(let text) = $0 { toasts.append(text) } }

        sheet.pick(SpotItem(title: "5", run: "5"))

        try await wait("the toast") { toasts == ["Picked 5"] }
    }

    func testAThrownErrorIsTheFailureOfTheCall() async throws {
        try inline(header: "on=sheet.open", "function main() { throw new Error('No sky today') }")
        let (sheet, told) = try toldSheet()

        sheet.open {}

        try await wait("the failure") { told().contains { $0.contains("No sky today") } }
    }

    func testAnAnswerThatARescanDropsEndsSoAPickNeedNotWait() async throws {
        try answering()
        let sheet = try sheet()
        sheet.answer("12")
        sheet.answer("123")

        try answering()
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(60)], ofItemAtPath: path("script.js"))
        _ = try scanned()

        try await wait("the end of the dropped answer") { !sheet.isAnswering }
    }

    func testMainGetsTheArgumentsTheVariablesAndTheStdinOfACall() async throws {
        try inline(header: "title=Script", "function main(args, env, input) { return `text=t\\ntitle=${args.length}|${args[0]}|${args[1]}|${env.OPENSPOT_REASON}|${env.OPENSPOT_ID}|${input}` }")
        let script = InlineScript(spot: try XCTUnwrap(try scanned().scripts.first), api: nil)
        defer { script.end() }
        let call = InlineCall(arguments: ["read", "a b"], variables: ["OPENSPOT_REASON": "panel"], input: "note=x\\ny")

        script.send(call)

        guard case .frame(let text) = await call.outcome(limit: 10) else { return XCTFail("the call gave no frame") }
        XCTAssertEqual(TextBlock.blocks(in: text).first?.value("title"), "2|read|a b|panel|script|note=x\ny")
    }

    func testFrameWritesAValueWithANewLineAndAKeyLineAsOneValue() async throws {
        try inline(header: "title=Script", "function main() { return openspot.frame([{ row: 'a', title: 'one\\n\\nrow=x\\ntitle=x', hides: ['x', 'y'], none: null }, { row: 'b', value: true }]) }")
        let spot = try XCTUnwrap(try scanned().scripts.first)

        let text = try await runs.answer(of: spot, SpotAction(arguments: ["read"]), limit: 5)

        let items = SpotOutput(text: text).items
        XCTAssertEqual(items.map(\.run), ["a", "b"], text)
        XCTAssertEqual(items.first?.title, "one\n\nrow=x\ntitle=x")
        XCTAssertEqual(items.first?.hides, ["x", "y"])
        XCTAssertEqual(items.last?.isOn, true)
    }

    func testMainReadsItsStdinAsItsInput() async throws {
        try inline(header: "title=Script", "function main(args, env, input) { return `toast=Saved ${input}` }")
        let spot = try XCTUnwrap(try scanned().scripts.first)

        let text = try await runs.answer(of: spot, SpotAction(arguments: ["save"]), input: "a=1", limit: 5)

        XCTAssertEqual(SpotOutput(text: text).toast, "Saved a=1")
    }

    /// New runs with this time for a call, this idle time of a script and this log.
    private func runs(limit: TimeInterval = 10, idle: TimeInterval = 30, log: CallLog? = nil) {
        runs.quit()
        runs = SpotRuns(readLimit: limit, now: { [unowned self] in self.time }, stopPause: 0.2, tickPause: .milliseconds(50), inlineIdle: idle, log: log)
    }

    func testAnEndlessLoopFailsAsTooSlowAndTheSpotAnswersItsNextCall() async throws {
        runs(limit: 0.5)
        try inline(header: "on=sheet.open", """
        function main(args, env) {
          if (env.OPENSPOT_REASON === "sheet.open") while (true) {}
          return "row=a\\ntitle=A\\n"
        }
        """)
        let (sheet, told) = try toldSheet()
        sheet.open {}
        try await wait("the failure") { told().contains { $0.contains("took too long, so Openspot stopped it.") } }

        sheet.read(need: .change)

        try await wait("the next answer") { sheet.list.shown.map(\.run) == ["a"] }
    }

    func testTheScriptLoadsAtItsFirstCallAndLetsGoAfterItsIdleTime() async throws {
        runs(idle: 0.3)
        try answering()
        let sheet = try sheet()
        let link = try XCTUnwrap(sheet.link as? InlineLink)
        XCTAssertFalse(link.isLoaded)

        sheet.answer("1")

        try await wait("the answer") { sheet.answers.map(\.run) == ["1"] }
        XCTAssertTrue(link.isLoaded)
        try await wait("the idle end") { !link.isLoaded }
        sheet.answer("7")
        try await wait("the answer after the idle end") { sheet.answers.map(\.run) == ["7"] }
    }

    func testEachCallGoesInTheCallLogWithItsArgumentsStdinAndFailure() async throws {
        let log = CallLog(folder: folder.appendingPathComponent("logs"))
        runs(log: log)
        try inline(header: "on=sheet.open", "function main(args) { if (args[0] === 'save') throw new Error('No sky today'); return 'row=a\\n' }")
        let (sheet, told) = try toldSheet()
        sheet.open {}
        try await wait("the rows") { sheet.list.shown.count == 1 }

        sheet.run(CommandAction(id: "save", title: "Save"), item: nil)

        try await wait("the failure") { !told().isEmpty }
        try await wait("the record") { log.text(of: "script").contains("No sky today") }
        XCTAssertTrue(log.text(of: "script").contains(" · read · exit 0"), log.text(of: "script"))
        XCTAssertTrue(log.text(of: "script").contains(" · save · "), log.text(of: "script"))
    }

    func testTheCPUTimeOfItsThreadCountsInItsUsage() async throws {
        try inline(header: "on=sheet.open", "function main() { const end = Date.now() + 300; while (Date.now() < end) {} return 'row=a\\n' }")
        let sheet = try sheet()
        sheet.open {}

        try await wait("the rows") { sheet.list.shown.count == 1 }
        XCTAssertGreaterThan(runs.usage.counts["script"]?.cpu ?? 0, 0.1)
    }

    func testARunWithALimitStopsWaitingForAFunctionThatRunsTooLong() async throws {
        try inline(header: "on=sheet.open", "function main() { const end = Date.now() + 2000; while (Date.now() < end) {} }")
        let spot = try XCTUnwrap(try scanned().scripts.first)

        do {
            _ = try await runs.answer(of: spot, .read, limit: 0.2)
            XCTFail("the run returned")
        } catch {
            XCTAssertEqual(error as? SpotError, .timedOut)
        }
    }
}
