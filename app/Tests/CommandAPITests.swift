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
        let work = try XCTUnwrap(CommandAPI(mac: host, places: .test(environment)).work(for: call, request: .test(arguments, in: environment), input: { input }))
        return await work()
    }

    func testABatchPrintsTheOutputOfEachCallWithAMarkAfterIt() async throws {
        let answer = try await answer(["batch"], input: "version\n\nsetting list\n")

        XCTAssertEqual(answer.code, 0)
        XCTAssertEqual(answer.output.components(separatedBy: "---\n").count, 3)
        XCTAssertTrue(answer.output.hasPrefix((Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown") + "\n"), answer.output)
    }

    func testAStoppedBatchRunsNoMoreLines() async throws {
        let work = try XCTUnwrap(CommandAPI(mac: host, places: .test(environment)).work(for: .test(["batch"]), input: {
            withUnsafeCurrentTask { $0?.cancel() }
            return "version\nversion\n"
        }))

        let answer = await Task { await work() }.value

        XCTAssertEqual(answer.output, "")
    }

    func testABatchStopsAtACallThatPrintsNoData() async throws {
        let answer = try await answer(["batch"], input: "version\ncolor pick\nversion\n")

        XCTAssertEqual(answer.code, 2)
        XCTAssertEqual(answer.errors, "openspot batch cannot run `color pick`, because it does not print data. Run it on its own.\n")
        XCTAssertEqual(answer.output.components(separatedBy: "---\n").count, 2)
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

    func testAnUnknownCallPrintsTheUsageWithCode2() async throws {
        let answer = try await answer(["emoji", "2+2"])

        XCTAssertEqual(answer.output, "")
        XCTAssertTrue(answer.errors.hasPrefix("openspot cannot do this: emoji 2+2\n\n"), answer.errors)
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
        try TestSpot(toml: "title = 'Weather'\n[settings]\ntoken = 'secret'\nkey = 'secret'", body: "echo").write(to: spots.spotFile("weather"))
        let places = environment.merging(["OPENSPOT_SPOTS": spots.path]) { _, new in new }
        let spot = places.merging(["OPENSPOT_ID": "weather"]) { _, new in new }
        try AppPlaces.test(places).secrets.keep("MARKER-7f3c", key: "token", of: "weather")

        let get = try await answer(["setting", "get", "token"], environment: spot)
        let list = try await answer(["setting", "list"], environment: places)
        let set = try await answer(["setting", "set", "token", "other"], environment: spot)
        let unset = try await answer(["setting", "set", "key", "other"], environment: spot)

        XCTAssertEqual(get.output, "•••\n")
        XCTAssertFalse(list.output.contains("MARKER"), list.output)
        XCTAssertTrue(list.output.contains("value=set\n"), list.output)
        XCTAssertEqual(set.code, 1)
        XCTAssertEqual(set.errors, "Openspot keeps `token` of weather as a secret, so only its own form changes it. Open the Settings of weather, and press Return on its row.\n")
        XCTAssertEqual(unset.code, 1)
        XCTAssertEqual(try AppPlaces.test(places).secrets.read(), ["weather": ["token": "MARKER-7f3c"]])
        XCTAssertNil(ConfigFile.standard(environment: places).read().setting("key", of: "weather"))
    }

    func testRemoveTakesAwayASecretAndAValueThatThePersonKept() async throws {
        let spots = folder.appendingPathComponent("spots", isDirectory: true)
        try TestSpot(toml: "title = 'Weather'\n[settings]\ntoken = 'secret'\ncity = 'text'", body: "echo").write(to: spots.spotFile("weather"))
        let places = environment.merging(["OPENSPOT_SPOTS": spots.path]) { _, new in new }
        try AppPlaces.test(places).secrets.keep("MARKER-7f3c", key: "token", of: "weather")
        _ = try await answer(["setting", "set", "--spot", "weather", "city", "Lisbon"], environment: places)

        let secret = try await answer(["setting", "remove", "--spot", "weather", "token"], environment: places)
        let value = try await answer(["setting", "remove", "--spot", "weather", "city"], environment: places)

        XCTAssertEqual(secret, CommandAnswer(output: "", errors: "", code: 0))
        XCTAssertEqual(value, CommandAnswer(output: "", errors: "", code: 0))
        XCTAssertNil(try AppPlaces.test(places).secrets.read()["weather"]?["token"])
        XCTAssertNil(ConfigFile.standard(environment: places).read().setting("city", of: "weather"))
    }

    func testASheetOnStdinIsChecked() async throws {
        let answer = try await answer(["check", "sheet"], input: "frame=\ntitle=Hi\n")

        XCTAssertEqual(answer.output, "the sheet has no parts\n1 faults.\n")
        XCTAssertEqual(answer.code, 1)
    }

    func testCalendarsComeFromTheStoreOfTheHost() async throws {
        let answer = try await answer(["calendar", "calendars"])

        XCTAssertEqual(TextBlock.blocks(in: answer.output).first?.value("title"), "Work")
        XCTAssertEqual(calendar.made, 1)
    }

    func testTenCallsShareOneEventStore() async throws {
        let api = CommandAPI(mac: host, places: .test(environment))
        let call = try XCTUnwrap(CommandLineCall(arguments: ["calendar", "calendars"], environment: environment))

        for _ in 0..<10 {
            _ = await api.work(for: call, request: .test(), input: { "" })?()
        }

        XCTAssertEqual(calendar.made, 1)
    }

    func testAStoreWithNoLeaveIsMadeAgainAtTheNextCall() async throws {
        calendar.access = .denied
        let api = CommandAPI(mac: host, places: .test(environment))
        let call = try XCTUnwrap(CommandLineCall(arguments: ["calendar", "calendars"], environment: environment))

        _ = await api.work(for: call, request: .test(), input: { "" })?()
        calendar.access = .allowed
        _ = await api.work(for: call, request: .test(), input: { "" })?()
        _ = await api.work(for: call, request: .test(), input: { "" })?()

        XCTAssertEqual(calendar.made, 2)
    }

    @MainActor
    func testStatsComeFromTheLiveCountsOfTheRunningApp() async throws {
        let runs = SpotRuns()
        runs.usage.called(Spot(id: "a", name: "Alpha", url: folder), CallOutcome(seconds: 1), at: Date())
        let call = try XCTUnwrap(CommandLineCall(arguments: ["spot", "stats"], environment: environment))
        let work = try XCTUnwrap(CommandAPI(mac: host, places: .test(environment), runs: runs).work(for: call, request: .test(), input: { "" }))

        let answer = await work()

        XCTAssertTrue(answer.output.hasPrefix("item=a\ntitle=Alpha\n"), answer.output)
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
            XCTAssertNil(CommandAPI(mac: host, places: .test()).work(for: call, request: .test(), input: { "" }), arguments.joined(separator: " "))
        }
    }

    func testACallThatStartsScriptsForASandboxedCallerRunsAloneInItsSandbox() throws {
        for arguments in [["check", "spots"], ["check", "spots", "--json"], ["spot", "run", "notes"], ["playground", "open"]] {
            let call = try XCTUnwrap(CommandLineCall(arguments: arguments, environment: [:]))
            XCTAssertNil(CommandAPI(mac: host, places: .test(), app: FakeRunningApp()).work(for: call, request: .test(), input: { "" }, isSandboxed: true), arguments.joined(separator: " "))
            XCTAssertNotNil(CommandAPI(mac: host, places: .test(), app: FakeRunningApp()).work(for: call, request: .test(), input: { "" }), arguments.joined(separator: " "))
        }
    }
}
