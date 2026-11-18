import os
import XCTest
@testable import OpenspotCore

final class CommandAPITests: XCTestCase {
    private final class Host: MacCalendar, @unchecked Sendable {
        var made = 0
        var access = CalendarAccess.allowed

        func store() -> any EventStore {
            made += 1
            return FakeEventStore(calendars: [CalendarList(id: "A8E2", title: "Work", account: "iCloud", color: "#1BADF8")], access: access)
        }

        func show(_ time: Date) throws {}
    }

    private var folder: URL!
    private let calendar = Host()

    private var host: Mac {
        Mac(calendar: calendar, reminders: FakeReminders())
    }

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("api-\(UUID().uuidString.prefix(8))")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private var environment: [String: String] {
        ["OPENSPOT_CONFIG": folder.path]
    }

    private func answer(_ arguments: [String], input: String = "", environment: [String: String]? = nil) async throws -> CommandAnswer {
        let environment = environment ?? self.environment
        let call = try XCTUnwrap(CommandLineCall(arguments: arguments, environment: environment))
        let work = try XCTUnwrap(CommandAPI(mac: host, places: .test(environment), rates: .offline).work(for: call, request: .test(arguments, in: environment), input: { input }))
        return await work()
    }

    func testABatchPrintsTheOutputOfEachCallWithAMarkAfterIt() async throws {
        let answer = try await answer(["batch"], input: "calc solve 2+2\n\nsetting list\n")

        XCTAssertEqual(answer.code, 0)
        XCTAssertEqual(answer.output.components(separatedBy: "---\n").count, 3)
        XCTAssertTrue(answer.output.hasPrefix("row=4\n"), answer.output)
    }

    func testAStoppedBatchRunsNoMoreLines() async throws {
        let work = try XCTUnwrap(CommandAPI(mac: host, places: .test(environment), rates: .offline).work(for: .test(["batch"]), input: {
            withUnsafeCurrentTask { $0?.cancel() }
            return "calc solve 2+2\ncalc solve 3+3\n"
        }))

        let answer = await Task { await work() }.value

        XCTAssertEqual(answer.output, "")
    }

    func testABatchStopsAtACallThatPrintsNoData() async throws {
        let answer = try await answer(["batch"], input: "calc solve 2+2\ncolor pick\ncalc solve 3+3\n")

        XCTAssertEqual(answer.code, 2)
        XCTAssertEqual(answer.errors, "openspot batch cannot run `color pick`, because it does not print data. Run it on its own.\n")
        XCTAssertFalse(answer.output.contains("row=6"))
    }

    func testABatchRunsNoCallThatReadsStdin() async throws {
        for line in ["clipboard copy", "translate text --to en"] {
            let answer = try await answer(["batch"], input: line + "\n")

            XCTAssertEqual(answer.errors, "openspot batch cannot run `\(line)`, because it does not print data. Run it on its own.\n")
        }
    }

    func testABatchRunsNoCallThatCanWaitForThePerson() async throws {
        for line in ["color pick", "folder pick", "screen shot", "screen record start"] {
            let answer = try await answer(["batch"], input: line + "\n")

            XCTAssertEqual(answer.errors, "openspot batch cannot run `\(line)`, because it does not print data. Run it on its own.\n")
        }
    }

    func testCalcSolvesASum() async throws {
        let answer = try await answer(["calc", "solve", "2+2"])

        XCTAssertEqual(TextBlock.blocks(in: answer.output).first?.value("title"), "4")
        XCTAssertEqual(answer.errors, "")
        XCTAssertEqual(answer.code, 0)
    }

    func testACurrencyIsAnsweredFromTheDatedFileOfTheRatesAndASumAsksForNone() async throws {
        let fetches = OSAllocatedUnfairLock(initialState: 0)
        let file = folder.appendingPathComponent("rates.json")
        let rates = CalcRateCache(file: file, now: { Date() }) {
            fetches.withLock { $0 += 1 }
            return CalcRatesTests.file
        }
        let api = CommandAPI(mac: host, places: .test(environment), rates: rates)

        let sum = try await XCTUnwrap(api.work(for: .test(["calc", "solve", "2+2"]), input: { "" }))()
        XCTAssertEqual(TextBlock.blocks(in: sum.output).first?.value("title"), "4")
        XCTAssertEqual(fetches.withLock { $0 }, 0)

        for _ in 0..<2 {
            let answer = try await XCTUnwrap(api.work(for: .test(["calc", "solve", "15 usd in eur"]), input: { "" }))()
            XCTAssertEqual(TextBlock.blocks(in: answer.output).first?.value("detail"), "15 USD in EUR")
        }
        XCTAssertEqual(fetches.withLock { $0 }, 1)
        XCTAssertNotNil(CalcRates(file: try Data(contentsOf: file)))
    }

    func testACurrencyWithNoRatesSaysWhy() async throws {
        let rates = CalcRateCache(file: folder.appendingPathComponent("rates.json"), now: { Date() }) { throw URLError(.notConnectedToInternet) }
        let api = CommandAPI(mac: host, places: .test(environment), rates: rates)

        let answer = try await XCTUnwrap(api.work(for: .test(["calc", "solve", "15 usd in eur"]), input: { "" }))()

        XCTAssertEqual(answer.output, "status=offline\n")
    }

    func testAnUnknownCallPrintsTheUsageWithCode2() async throws {
        let answer = try await answer(["calc", "2+2"])

        XCTAssertEqual(answer.output, "")
        XCTAssertTrue(answer.errors.hasPrefix("openspot cannot do this: calc 2+2\n\n"))
        XCTAssertEqual(answer.code, 2)
    }

    func testASettingThatASpotKeepsIsReadBack() async throws {
        let spot = environment.merging(["OPENSPOT_ID": "notes"]) { _, new in new }

        let set = try await answer(["setting", "set", "tone", "warm"], environment: spot)
        let get = try await answer(["setting", "get", "tone"], environment: spot)

        XCTAssertEqual(set, CommandAnswer(output: "", errors: "", code: 0))
        XCTAssertEqual(get.output, "warm\n")
    }

    func testASecretIsNeverPrintedAndOnlyOpenspotsFormChangesIt() async throws {
        let spots = folder.appendingPathComponent("spots", isDirectory: true)
        try TestSpot(toml: "title = 'Weather'\n[settings.token]\ntype = 'secret'\n[settings.key]\ntype = 'secret'", body: "echo").write(to: spots.spotFile("weather"))
        let places = environment.merging(["OPENSPOT_SPOTS": spots.path]) { _, new in new }
        let spot = places.merging(["OPENSPOT_ID": "weather"]) { _, new in new }
        try AppPlaces.test(places).secrets.keep("MARKER-7f3c", key: "token", of: "weather")

        let get = try await answer(["setting", "get", "token"], environment: spot)
        let list = try await answer(["setting", "list"], environment: places)
        let set = try await answer(["setting", "set", "token", "other"], environment: spot)
        let unset = try await answer(["setting", "set", "key", "other"], environment: spot)

        XCTAssertEqual(get.output, "•••\n")
        XCTAssertFalse(list.output.contains("MARKER"), list.output)
        XCTAssertTrue(list.output.contains("•••"), list.output)
        XCTAssertEqual(set.code, 1)
        XCTAssertEqual(set.errors, "Openspot keeps `token` of weather as a secret, so only its own form changes it. Open the Settings of weather, and press Return on its row.\n")
        XCTAssertEqual(unset.code, 1)
        XCTAssertEqual(try AppPlaces.test(places).secrets.read(), ["weather": ["token": "MARKER-7f3c"]])
        XCTAssertNil(ConfigFile.standard(environment: places).read().setting("key", of: "weather"))
    }

    func testASheetOnStdinIsChecked() async throws {
        let answer = try await answer(["check", "sheet"], input: "title=Hi\n")

        XCTAssertEqual(answer.output, "the sheet has no parts\n1 faults.\n")
        XCTAssertEqual(answer.code, 1)
    }

    func testCalendarsComeFromTheStoreOfTheHost() async throws {
        let answer = try await answer(["calendar", "calendars"])

        XCTAssertEqual(TextBlock.blocks(in: answer.output).first?.value("title"), "Work")
        XCTAssertEqual(calendar.made, 1)
    }

    func testTenCallsShareOneEventStore() async throws {
        let api = CommandAPI(mac: host, places: .test(environment), rates: .offline)
        let call = try XCTUnwrap(CommandLineCall(arguments: ["calendar", "calendars"], environment: environment))

        for _ in 0..<10 {
            _ = await api.work(for: call, request: .test(), input: { "" })?()
        }

        XCTAssertEqual(calendar.made, 1)
    }

    func testAStoreWithNoLeaveIsMadeAgainAtTheNextCall() async throws {
        calendar.access = .denied
        let api = CommandAPI(mac: host, places: .test(environment), rates: .offline)
        let call = try XCTUnwrap(CommandLineCall(arguments: ["calendar", "calendars"], environment: environment))

        _ = await api.work(for: call, request: .test(), input: { "" })?()
        calendar.access = .allowed
        _ = await api.work(for: call, request: .test(), input: { "" })?()
        _ = await api.work(for: call, request: .test(), input: { "" })?()

        XCTAssertEqual(calendar.made, 2)
    }

    func testAnEventReachesTheRunningApp() async throws {
        let raised = LockedEvents()
        let call = try XCTUnwrap(CommandLineCall(arguments: ["event", "emit", "music.track", "Song"], environment: [:]))
        let work = try XCTUnwrap(CommandAPI(mac: host, places: .test(), raise: { await raised.add($0) }, rates: .offline).work(for: call, request: .test(), input: { "" }))

        let answer = await work()

        XCTAssertEqual(answer, CommandAnswer())
        let events = await raised.events
        XCTAssertEqual(events, [.named("music.track", value: "Song")])
    }

    func testAnEventWithNoAppToReachFails() async throws {
        let answer = try await answer(["event", "emit", "music.track"])

        XCTAssertEqual(answer.errors, "Openspot is not running, so no spot hears `music.track`. Open Openspot, then run this again.\n")
        XCTAssertEqual(answer.code, 1)
    }

    @MainActor
    func testStatsComeFromTheLiveCountsOfTheRunningApp() async throws {
        let runs = SpotRuns()
        runs.usage.called(Spot(id: "a", name: "Alpha", url: folder), CallOutcome(seconds: 1), at: Date())
        let call = try XCTUnwrap(CommandLineCall(arguments: ["spot", "stats"], environment: environment))
        let work = try XCTUnwrap(CommandAPI(mac: host, places: .test(environment), runs: runs, rates: .offline).work(for: call, request: .test(), input: { "" }))

        let answer = await work()

        XCTAssertTrue(answer.output.hasPrefix("row=a\ntitle=Alpha\n"), answer.output)
    }

    func testStatsWithNoAppToReachReadTheFiles() async throws {
        let usage = StatsLog(folder: folder.appendingPathComponent("stats"), pause: 60)
        usage.called(Spot(id: "a", name: "Alpha", url: folder), CallOutcome(seconds: 1), at: Date())
        usage.flush()

        let answer = try await answer(["spot", "stats"])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertTrue(answer.output.contains("Alpha"), answer.output)
    }

    func testACallThatTheShellDoesOrThatNeedsTheAppHasNoWorkInCoreWithNoApp() throws {
        for arguments in [["render", "sheet", "a.png"], ["helper", "calc"], ["spot", "open", "notes", "--select"], ["playground", "open"]] {
            let call = try XCTUnwrap(CommandLineCall(arguments: arguments, environment: [:]))
            XCTAssertNil(CommandAPI(mac: host, places: .test(), rates: .offline).work(for: call, request: .test(), input: { "" }), arguments.joined(separator: " "))
        }
    }

    func testACallThatStartsScriptsForASandboxedCallerRunsAloneInItsSandbox() throws {
        for arguments in [["check", "spots"], ["check", "spots", "--json"], ["spot", "run", "notes"], ["playground", "open"]] {
            let call = try XCTUnwrap(CommandLineCall(arguments: arguments, environment: [:]))
            XCTAssertNil(CommandAPI(mac: host, places: .test(), app: FakeRunningApp(), rates: .offline).work(for: call, request: .test(), input: { "" }, isSandboxed: true), arguments.joined(separator: " "))
            XCTAssertNotNil(CommandAPI(mac: host, places: .test(), app: FakeRunningApp(), rates: .offline).work(for: call, request: .test(), input: { "" }), arguments.joined(separator: " "))
        }
    }
}

private actor LockedEvents {
    private(set) var events: [SpotEvent] = []

    func add(_ event: SpotEvent) {
        events.append(event)
    }
}
