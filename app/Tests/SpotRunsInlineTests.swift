import XCTest
@testable import OpenspotCore

@MainActor
final class SpotRunsInlineTests: SpotRunsCase {
    private func inline(_ name: String = "script", toml: String, _ body: String) throws {
        let url = folder.spotFile(name, extension: "js")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "\(body)\n".write(to: url, atomically: true, encoding: .utf8)
        try toml.write(to: url.deletingLastPathComponent().appendingPathComponent(Manifest.fileName), atomically: true, encoding: .utf8)
    }

    private func answering() throws {
        try inline(toml: "[on]\nsearch = '^[0-9]'", """
        export default {
          search({ text }) {
            if (text === "12") { const end = Date.now() + 300; while (Date.now() < end) {} }
            return `item=${text}\\ntitle=Is ${text}\\ndetail=search\\n`
          },
          press({ item }) { return `item=${item}\\ntitle=Is ${item}\\ndetail=press\\n` },
        }
        """)
    }

    func testAFastInlineSpotAnswersInTheTurnOfTheText() async throws {
        runs(frameWait: .seconds(10))
        try answering()
        let sheet = try sheet()
        sheet.answer("1")
        try await wait("the loaded script") { sheet.answers.map(\.run) == ["1"] }

        sheet.answer("7")

        XCTAssertEqual(sheet.answers.map(\.run), ["7"])
        XCTAssertEqual(sheet.answers.first?.subtitle, "search")
        XCTAssertFalse(sheet.isAnswering)
    }

    private func slowAnswering(_ names: [String]) throws -> [SpotRun] {
        let body = """
        export default {
          search({ text }) {
            if (text === "12") { const end = Date.now() + 300; while (Date.now() < end) {} }
            return `item=${text}\\ntitle=Is ${text}\\n`
          },
        }
        """
        for name in names { try inline(name, toml: "[on]\nsearch = '^[0-9]'", body) }
        _ = try scanned()
        return names.compactMap { runs.sheets[$0] }
    }

    func testAnInlineSpotGetsTheEventAndTheSettingsInItsInput() async throws {
        try inline(toml: "[settings]\ncity = { type = 'text' }", """
        export default {
          show({ event }, env) { return `item=a\\ntitle=${event} ${env.settings.city}\\n` },
        }
        """)
        let sheet = try sheet()
        runs.take(settings: [KeptSetting(spot: "script", key: "city", value: "Paris")])

        sheet.show(need: .change)

        try await wait("the show") { sheet.list.all.first?.title == "spot.change Paris" }
    }

    func testThreeSlowInlineSpotsShareOneWaitForTheirAnswers() async throws {
        runs(frameWait: .milliseconds(20))
        let sheets = try slowAnswering(["a", "b", "c"])
        runs.raise(.query("1"))
        try await wait("the loaded scripts") { sheets.allSatisfy { $0.answers.map(\.run) == ["1"] } }
        runs.raise(.query("7"))
        XCTAssertTrue(sheets.allSatisfy { $0.answers.map(\.run) == ["7"] })
        let waits = runs.frameWaits

        runs.raise(.query("12"))

        XCTAssertEqual(runs.frameWaits - waits, 1)
        try await wait("the slow answers") { sheets.allSatisfy { $0.answers.map(\.run) == ["12"] } }
    }

    func testTheWaitForTheAnswersStartsAfterTheTextReachesEachSpot() async throws {
        let sheets = try slowAnswering((1...30).map { "s\($0)" })

        runs.raise(.query("12"))

        XCTAssertEqual(runs.frameWaits, 1)
        try await wait("the slow answers") { sheets.allSatisfy { $0.answers.map(\.run) == ["12"] } }
    }

    func testASlowInlineSpotKeepsTheLastRowsUntilItsAnswerLandsInALaterTurn() async throws {
        try answering()
        let sheet = try sheet()
        sheet.answer("1")
        try await wait("the loaded script") { sheet.answers.map(\.run) == ["1"] }

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
        runs.api = CommandAPI(mac: Mac(), places: .test(), runs: runs)
        try inline(toml: "[on]\nsearch = '^[0-9]'", """
        export default {
          search({ text }) {
            const answer = openspot.call(["version"])
            return `item=${text}\ntitle=${answer.stdout.trim()}\ndetail=${answer.code}\n`
          },
        }
        """)
        let sheet = try sheet()

        sheet.answer("2+2")

        try await wait("the answer of the API") { sheet.answers.map(\.run) == ["2+2"] }
        XCTAssertEqual(sheet.answers.first?.title, Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")
        XCTAssertEqual(sheet.answers.first?.subtitle, "0")
    }

    func testAPickRunsItsOpenFunctionWithTheRow() async throws {
        try inline(toml: "[on]\nsearch = '^[0-9]'", """
        export default {
          search({ text }) { return `item=${text}\\ntitle=${text}\\n` },
          press({ item }) { return `item=picked\\ntitle=Picked ${item}\\n` },
        }
        """)
        let sheet = try sheet()
        let frames = FrameLog(sheet)

        sheet.pick(SpotItem(title: "5", run: "5"))

        try await wait("the frame of the pick") { frames.last == "item=picked\ntitle=Picked 5\n" }
    }

    func testAThrownErrorIsTheFailureOfTheCall() async throws {
        try inline(toml: "", "export default { show() { throw new Error('No sky today') } }")
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
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(60)], ofItemAtPath: path("script.spot/script.js"))
        _ = try scanned()

        try await wait("the end of the dropped answer") { !sheet.isAnswering }
    }

    func testACallAfterAnEditOfTheFileRunsTheNewCodeOnceTheScanSeesIt() async throws {
        try inline(toml: "[on]\nsearch = '^[0-9]'", "export default { search() { return 'item=a\\ntitle=Old' } }")
        let sheet = try sheet()
        sheet.answer("1")
        try await wait("the old answer") { sheet.answers.map(\.title) == ["Old"] }

        try inline(toml: "[on]\nsearch = '^[0-9]'", "export default { search() { return 'item=a\\ntitle=New' } }")
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(60)], ofItemAtPath: path("script.spot/script.js"))
        _ = try scanned()
        sheet.answer("2")

        try await wait("the new answer") { sheet.answers.map(\.title) == ["New"] }
    }

    private func counting() throws {
        try inline(toml: "", "let n = 0\nexport default { show() { n += 1; return `item=n\\ntitle=${n}\\n` }, asked() { n += 1; return true } }")
    }

    func testAHookAndACallOfOneSpotShareOneLoadedScript() async throws {
        try counting()
        let sheet = try sheet()
        sheet.show(need: .change)
        try await wait("the first call") { sheet.reading.value?.title == "1" }

        let said = await withCheckedContinuation { waiting in
            if let now = runs.answer("asked", of: sheet.spot, card: "", origin: "", later: { waiting.resume(returning: !$0.isEmpty) }) { waiting.resume(returning: !now.isEmpty) }
        }
        sheet.show(need: .change)

        XCTAssertTrue(said)
        try await wait("the count of the one script") { sheet.reading.value?.title == "3" }
    }

    func testACallReadsNoDateOfTheFileAndTheScriptLoadsAgainWhenTheScanSeesAChange() async throws {
        try counting()
        let sheet = try sheet()
        sheet.show(need: .change)
        try await wait("the first call") { sheet.reading.value?.title == "1" }
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(60)], ofItemAtPath: path("script.spot/script.js"))

        sheet.show(need: .change)
        try await wait("the second call of the same script") { sheet.reading.value?.title == "2" }
        _ = try scanned()
        sheet.show(need: .change)

        try await wait("the first call of the script that loaded again") { sheet.reading.value?.title == "1" }
    }

    func testAnAnswerOfBlocksWritesAValueWithANewLineAndAKeyLineAsOneValue() async throws {
        try inline(toml: "title = 'Script'", "export default { show() { return [{ item: 'a', title: 'one\\n\\ntext=x\\ntitle=x', hides: ['x', 'y'], none: null }, { item: 'b', value: true }] } }")
        let spot = try XCTUnwrap(try scanned().scripts.first)

        let text = try await runs.answer(of: spot, "show", limit: 60)

        let items = Frame(text: text).items
        XCTAssertEqual(items.map(\.run), ["a", "b"], text)
        XCTAssertEqual(items.first?.title, "one\n\ntext=x\ntitle=x")
        XCTAssertEqual(items.first?.hides, ["x", "y"])
        XCTAssertEqual(items.last?.isOn, true)
    }

    private func runs(limit: TimeInterval = 10, idle: TimeInterval = 30, frameWait: DispatchTimeInterval = .milliseconds(2), log: CallLog? = nil) {
        runs.quit()
        runs = SpotRuns(showLimit: limit, clock: clock.value, stopPause: 0.2, inlineIdle: idle, frameWait: frameWait, log: log)
    }

    func testAnEndlessLoopFailsAsTooSlowAndTheSpotAnswersItsNextCall() async throws {
        runs(limit: 0.5)
        try inline(toml: "", """
        export default {
          show({ event }) {
            if (event === "sheet.open") while (true) {}
            return "item=a\\ntitle=A\\n"
          },
        }
        """)
        let (sheet, told) = try toldSheet()
        sheet.open {}
        try await wait("the failure") { told().contains { $0.contains("took too long, so Openspot stopped it.") } }

        sheet.show(need: .change)

        try await wait("the next answer") { sheet.list.shown.map(\.run) == ["a"] }
    }

    private func fakeOpenspot(_ body: String) throws {
        let bin = folder.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try "#!/bin/sh\n\(body)\n".writeScript(to: bin.appendingPathComponent("openspot"))
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "\(bin.path):\(environment["PATH"] ?? "/usr/bin:/bin")"
        runs.quit()
        runs = SpotRuns(environment: environment, showLimit: 0.5, clock: clock.value, stopPause: 0.2)
    }

    private func callingSpot() throws -> Spot {
        try inline(toml: "", "const solve = () => openspot.call([\"version\"]).stdout\nexport default { save: solve, show: solve }")
        return try XCTUnwrap(try scanned().scripts.first)
    }

    func testAWorkCallHasNoLimitOfAReadAndWaitsForItsOpenspotCall() async throws {
        try fakeOpenspot("sleep 1\nprintf 'toast=Saved\\n'")
        let script = runs.script(of: try callingSpot())
        defer { script.end() }
        let call = InlineCall(arguments: ["save"])

        script.send(call)

        guard case .frame(let text) = await call.outcome() else { return XCTFail("the work call failed") }
        XCTAssertEqual(text, "toast=Saved\n")
    }

    func testACallQueuedBehindOneThatTimedOutFailsAsTooSlow() async throws {
        try fakeOpenspot("exec sleep 30")
        let script = runs.script(of: try callingSpot())
        defer { script.end() }
        let first = InlineCall(arguments: ["show"], limit: 0.5)
        let second = InlineCall(arguments: ["show"], limit: 0.5)

        script.send(first)
        script.send(second)

        guard case .failed(let error) = await second.outcome() else { return XCTFail("the queued call did not fail") }
        XCTAssertEqual(error as? SpotError, .timedOut)
    }

    func testACallThatHangsInOpenspotCallEndsAtItsLimitAndTheNextCallGetsANewScript() async throws {
        try fakeOpenspot("echo $$ > '\(path("child"))'\nexec sleep 30")
        try inline(toml: "", """
        export default {
          show({ event }) {
            if (event === "sheet.open") openspot.call(["version"])
            return "item=a\\ntitle=A\\n"
          },
        }
        """)
        let (sheet, told) = try toldSheet()
        sheet.open {}
        try await wait("the failure") { told().contains { $0.contains("took too long, so Openspot stopped it.") } }
        let child = try await pid("child")
        try await wait("the end of the hung child") { kill(child, 0) != 0 }

        sheet.show(need: .change)

        try await wait("the next answer") { sheet.list.shown.map(\.run) == ["a"] }
    }

    func testTheScriptLoadsAtItsFirstCallAndLetsGoAfterItsIdleTime() async throws {
        runs(idle: 0.3)
        try answering()
        let sheet = try sheet()
        let isLoaded = { self.runs.loaded["script"]?.script.isRunning == true }
        XCTAssertFalse(isLoaded())

        sheet.answer("1")

        try await wait("the answer") { sheet.answers.map(\.run) == ["1"] }
        XCTAssertTrue(isLoaded())
        try await wait("the idle end") { !isLoaded() }
        sheet.answer("7")
        try await wait("the answer after the idle end") { sheet.answers.map(\.run) == ["7"] }
    }

    func testATimedScriptKeepsItsContextPastItsIdleTimeUntilItsNextRead() async throws {
        runs(idle: 0.1)
        try inline(toml: "[on]\nevery = 60", "export default { show() { return 'item=n\\ntitle=3\\n' } }")
        try inline("other", toml: "", "export default { show() { return 'item=n\\ntitle=4\\n' } }")
        let sheet = try sheet()
        let other = try XCTUnwrap(runs.sheets["other"])
        let isLoaded = { (id: String) in self.runs.loaded[id]?.script.isRunning == true }

        sheet.show(need: .change)
        other.show(need: .change)
        try await wait("the values") { sheet.reading.value?.title == "3" && other.reading.value?.title == "4" }
        try await wait("the idle end of the spot with no clock") { !isLoaded("other") }

        XCTAssertTrue(isLoaded("script"))
    }

    func testEachCallGoesInTheCallLogWithItsArgumentsStdinAndFailure() async throws {
        let log = CallLog(folder: folder.appendingPathComponent("logs"))
        runs(log: log)
        try inline(toml: "", "export default { save() { throw new Error('No sky today') }, show() { return 'item=a\\n' } }")
        let (sheet, told) = try toldSheet()
        sheet.open {}
        try await wait("the rows") { sheet.list.shown.count == 1 }

        sheet.run(CommandAction(id: "save", title: "Save"), item: nil)

        try await wait("the failure") { !told().isEmpty }
        try await wait("the record") { log.text(of: "script").contains("No sky today") }
        XCTAssertTrue(log.text(of: "script").contains(" · show · exit 0"), log.text(of: "script"))
        XCTAssertTrue(log.text(of: "script").contains(" · save · "), log.text(of: "script"))
    }

    func testTheCPUTimeOfItsThreadCountsInItsUsage() async throws {
        try inline(toml: "", "export default { show() { let x = 0; for (let i = 0; i < 1e7; i++) { x = (x * 31 + i) % 1000003 } return 'item=a\\n' } }")
        let sheet = try sheet()
        sheet.open {}

        try await wait("the rows") { sheet.list.shown.count == 1 }
        XCTAssertGreaterThan(runs.usage.counts["script"]?.cost.cpu ?? 0, 0.1)
    }

    func testARunWithALimitStopsWaitingForAFunctionThatRunsTooLong() async throws {
        try inline(toml: "", "export default { show() { const end = Date.now() + 2000; while (Date.now() < end) {} } }")
        let spot = try XCTUnwrap(try scanned().scripts.first)

        do {
            _ = try await runs.answer(of: spot, ScriptEntry.show.name, limit: 0.2)
            XCTFail("the run returned")
        } catch {
            XCTAssertEqual(error as? SpotError, .timedOut)
        }
    }
}
