import XCTest
@testable import OpenspotCore

/// Proves the work of `openspot <noun> <verb>` that Core does, the same for the app and for a process of its own.
final class CommandAPITests: XCTestCase {
    private final class Host: Mac, @unchecked Sendable {
        var made = 0
        var opened: [URL] = []
        var access = CalendarAccess.allowed

        func eventStore() -> any EventStore {
            made += 1
            return FakeEventStore(calendars: [CalendarList(id: "A8E2", title: "Work", account: "iCloud", color: "#1BADF8")], access: access)
        }

        func reminderStore() -> any ReminderStore {
            FakeReminderStore()
        }

        func showCalendar(at time: Date) throws {}

        func open(_ link: URL) -> Bool {
            opened.append(link)
            return true
        }
    }

    private var folder: URL!
    private let host = Host()

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
        let work = try XCTUnwrap(CommandAPI(mac: host).work(for: call, input: { input }, environment: environment))
        return await work()
    }

    func testABatchPrintsTheOutputOfEachCallWithAMarkAfterIt() async throws {
        let answer = try await answer(["batch"], input: "calc solve 2+2\n\nsetting list --frame\n")

        XCTAssertEqual(answer.code, 0)
        XCTAssertEqual(answer.output.components(separatedBy: "---\n").count, 3)
        XCTAssertTrue(answer.output.hasPrefix("row=4\n"), answer.output)
    }

    func testAStoppedBatchRunsNoMoreLines() async throws {
        let work = try XCTUnwrap(CommandAPI(mac: host).work(for: .batch, input: {
            withUnsafeCurrentTask { $0?.cancel() }
            return "calc solve 2+2\ncalc solve 3+3\n"
        }, environment: environment))

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
        for line in ["clipboard copy", "translate --to en"] {
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

    func testASheetOnStdinIsChecked() async throws {
        let answer = try await answer(["check", "--sheet"], input: "title=Hi\n")

        XCTAssertEqual(answer.output, "the sheet has no parts\n1 faults.\n")
        XCTAssertEqual(answer.code, 1)
    }

    func testCalendarsComeFromTheStoreOfTheHost() async throws {
        let answer = try await answer(["calendar", "calendars"])

        XCTAssertEqual(TextBlock.blocks(in: answer.output).first?.value("title"), "Work")
        XCTAssertEqual(host.made, 1)
    }

    func testTenCallsShareOneEventStore() async throws {
        let api = CommandAPI(mac: host)
        let call = try XCTUnwrap(CommandLineCall(arguments: ["calendar", "calendars"], environment: environment))

        for _ in 0..<10 {
            _ = await api.work(for: call, input: { "" }, environment: environment)?()
        }

        XCTAssertEqual(host.made, 1)
    }

    func testAStoreWithNoLeaveIsMadeAgainAtTheNextCall() async throws {
        host.access = .denied
        let api = CommandAPI(mac: host)
        let call = try XCTUnwrap(CommandLineCall(arguments: ["calendar", "calendars"], environment: environment))

        _ = await api.work(for: call, input: { "" }, environment: environment)?()
        host.access = .allowed
        _ = await api.work(for: call, input: { "" }, environment: environment)?()
        _ = await api.work(for: call, input: { "" }, environment: environment)?()

        XCTAssertEqual(host.made, 2)
    }

    func testAnEventReachesTheRunningApp() async throws {
        let raised = LockedEvents()
        let call = try XCTUnwrap(CommandLineCall(arguments: ["event", "emit", "music.track", "Song"], environment: [:]))
        let work = try XCTUnwrap(CommandAPI(mac: host, raise: { await raised.add($0) }).work(for: call, input: { "" }, environment: [:]))

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
        runs.usage.called(Spot(id: "a", name: "Alpha", url: folder), seconds: 1, isFailure: false, at: Date())
        let call = try XCTUnwrap(CommandLineCall(arguments: ["spot", "stats", "--frame"], environment: environment))
        let work = try XCTUnwrap(CommandAPI(mac: host, runs: runs).work(for: call, input: { "" }, environment: environment))

        let answer = await work()

        XCTAssertTrue(answer.output.hasPrefix("row=a\ntitle=Alpha\n"), answer.output)
    }

    func testStatsWithNoAppToReachReadTheFiles() async throws {
        let usage = SpotUsage(folder: folder.appendingPathComponent("stats"), pause: 60)
        usage.called(Spot(id: "a", name: "Alpha", url: folder), seconds: 1, isFailure: false, at: Date())
        usage.flush()

        let answer = try await answer(["spot", "stats"])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertTrue(answer.output.contains("Alpha"), answer.output)
    }

    func testACallThatTheShellDoesOrThatNeedsTheAppHasNoWorkInCoreWithNoApp() throws {
        for arguments in [["render", "a.png"], ["helper", "calc"], ["spot", "show", "notes"], ["sandbox"]] {
            let call = try XCTUnwrap(CommandLineCall(arguments: arguments, environment: [:]))
            XCTAssertNil(CommandAPI(mac: host).work(for: call, input: { "" }, environment: [:]), arguments.joined(separator: " "))
        }
    }
}

/// The events that a test's API raised.
private actor LockedEvents {
    private(set) var events: [SpotEvent] = []

    func add(_ event: SpotEvent) {
        events.append(event)
    }
}
