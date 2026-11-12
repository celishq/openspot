import XCTest
@testable import OpenspotCore

/// Proves `Contents/Helpers/openspot`: it asks the socket of the running app, and runs the program of its app with the same
/// arguments for a call of files when no socket answers or the call runs in a process of its own. A live call starts the
/// app and waits for its socket, and Ctrl-C stops its work in the app (protocol: The openspot command).
final class CommandClientTests: XCTestCase {
    private final class Host: Mac {
        func eventStore() -> any EventStore { FakeEventStore() }
        func reminderStore() -> any ReminderStore { FakeReminderStore() }
        func showCalendar(at time: Date) throws {}
        func open(_ link: URL) -> Bool { true }
    }

    /// A running app whose change of a setting takes 30 seconds and then writes a far-off file, unless its call stops first.
    /// It writes `started` as it begins and `ended` as it ends.
    private struct SlowApp: RunningApp {
        let folder: URL

        func configChanged(_ change: ConfigChange) async {}
        func status() async -> (update: String?, calls: Int, isFirstLaunch: Bool) { (nil, 0, false) }
        func checkUpdate() async -> Bool { true }
        func installUpdate() async -> Bool { true }
        func openAccount(_ open: AccountOpen) async -> Bool { false }
        func quit() async {}
        func open(_ id: String) async -> Bool { true }
        func review(_ id: String) async -> Bool { true }
        func openStore() async {}
        func reveal(_ id: String) async -> Bool { true }
        func sandbox(_ file: URL?, isCareful: Bool) async {}

        func changeSetting(_ key: String, of spot: String) async -> Bool {
            FileManager.default.createFile(atPath: folder.appendingPathComponent("started").path, contents: nil)
            defer { FileManager.default.createFile(atPath: folder.appendingPathComponent("ended").path, contents: nil) }
            do {
                try await Task.sleep(for: .seconds(30))
                FileManager.default.createFile(atPath: folder.appendingPathComponent("far").path, contents: nil)
            } catch {}
            return true
        }
    }

    private var folder: URL!
    private var socket: CommandSocket?

    private var config: URL { folder.appendingPathComponent("config") }
    private var client: URL { folder.appendingPathComponent("A.app/Contents/Helpers/openspot") }

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("oc-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("A.app/Contents/MacOS"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        let built = Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot")
        try FileManager.default.copyItem(at: built, to: client)
        try "#!/bin/sh\necho \"app: $*\"\n".writeScript(to: folder.appendingPathComponent("A.app/Contents/MacOS/Openspot"))
    }

    override func tearDownWithError() throws {
        socket?.close()
        try? FileManager.default.removeItem(at: folder)
    }

    private func listen() {
        socket = CommandSocket(folder: config, api: CommandAPI(mac: Host()))
    }

    /// Runs the program with the arguments and stdin, and returns what it prints and its exit code.
    private func run(_ program: URL, _ arguments: [String], input: String = "") throws -> (output: String, errors: String, code: Int32) {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        let stdin = Pipe()
        process.executableURL = program
        process.arguments = arguments
        process.environment = ["OPENSPOT_CONFIG": config.path, "PATH": "/usr/bin:/bin"]
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = stdin
        try process.run()
        stdin.fileHandleForWriting.write(Data(input.utf8))
        try stdin.fileHandleForWriting.close()
        let printed = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let said = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        return (printed, said, process.terminationStatus)
    }

    func testTheRunningAppAnswersACalcSum() throws {
        listen()

        let answer = try run(client, ["calc", "solve", "2+2"])

        XCTAssertEqual(TextBlock.blocks(in: answer.output).first?.value("title"), "4")
        XCTAssertEqual(answer.code, 0)
    }

    func testStdinStderrAndTheCodeComeThroughTheSocket() throws {
        listen()

        XCTAssertEqual(try run(client, ["check", "--sheet"], input: "title=Hi\n").output, "the sheet has no parts\n1 faults.\n")
        XCTAssertEqual(try run(client, ["check", "--sheet"], input: "title=Hi\n").code, 1)
        let unknown = try run(client, ["calc", "2+2"])
        XCTAssertTrue(unknown.errors.hasPrefix("openspot cannot do this: calc 2+2\n"))
        XCTAssertEqual(unknown.code, 2)
    }

    func testACallThatTakesNoStdinLeavesItForTheNextReader() throws {
        listen()
        let file = folder.appendingPathComponent("calls")
        try "call=next\n".write(to: file, atomically: true, encoding: .utf8)
        let stdin = try FileHandle(forReadingFrom: file)
        defer { try? stdin.close() }
        let process = Process()
        process.executableURL = client
        process.arguments = ["calc", "solve", "2+2"]
        process.environment = ["OPENSPOT_CONFIG": config.path, "PATH": "/usr/bin:/bin"]
        process.standardOutput = FileHandle.nullDevice
        process.standardInput = stdin
        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(try stdin.offset(), 0)
    }

    func testAPipedStdinThatComesInPartsReachesTheCall() throws {
        listen()
        let process = Process()
        let output = Pipe()
        let stdin = Pipe()
        process.executableURL = client
        process.arguments = ["check", "--sheet"]
        process.environment = ["OPENSPOT_CONFIG": config.path, "PATH": "/usr/bin:/bin"]
        process.standardOutput = output
        process.standardInput = stdin
        try process.run()
        stdin.fileHandleForWriting.write(Data("title=Hi\n".utf8))
        stdin.fileHandleForWriting.write(Data("text=Привіт\n".utf8))
        try stdin.fileHandleForWriting.close()
        let printed = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()

        XCTAssertEqual(printed, "the sheet has no parts\n1 faults.\n")
    }

    func testWithNoSocketItStartsTheAppWithTheSameArguments() throws {
        XCTAssertEqual(try run(client, ["guide"]).output, "app: guide\n")
    }

    func testACallThatRunsAloneStartsTheApp() throws {
        listen()

        XCTAssertEqual(try run(client, ["render", "x.png"]).output, "app: render x.png\n")
    }

    /// Starts the program with the arguments and these more variables, and returns it as it runs.
    private func start(_ arguments: [String], variables: [String: String] = [:]) throws -> (process: Process, output: Pipe, errors: Pipe) {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = client
        process.arguments = arguments
        process.environment = ["OPENSPOT_CONFIG": config.path, "PATH": "/usr/bin:/bin"].merging(variables) { _, new in new }
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = FileHandle.nullDevice
        try process.run()
        return (process, output, errors)
    }

    /// Waits for a fact, for 10 seconds at most.
    private func wait(_ what: String, until fact: () -> Bool) async throws {
        for _ in 0..<1000 {
            if fact() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited for \(what)")
    }

    private func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path)
    }

    func testALiveCallWithNoAppStartsItInTheBackgroundAndAsksItsSocket() async throws {
        try "#!/bin/sh\nif [ $# -gt 0 ]; then echo \"app: $*\"; else touch '\(folder.appendingPathComponent("started").path)'; fi\n".writeScript(to: folder.appendingPathComponent("A.app/Contents/MacOS/Openspot"))
        let run = try start(["app", "status"])

        try await wait("the start of the app") { exists("started") }
        listen()
        try await wait("the end of the call") { !run.process.isRunning }

        let printed = String(decoding: run.output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        XCTAssertTrue(printed.hasPrefix("{"), printed)
        XCTAssertEqual(run.process.terminationStatus, 0)
    }

    func testALiveCallFailsAndSaysSoWhenTheAppDoesNotStartInTime() async throws {
        let run = try start(["event", "emit", "music.track"], variables: ["OPENSPOT_START_WAIT": "0.3"])

        try await wait("the end of the call") { !run.process.isRunning }

        let said = String(decoding: run.errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        XCTAssertEqual(said, "Openspot did not start within 0.3 seconds, so this call did not run. Open Openspot, then run it again.\n")
        XCTAssertEqual(String(decoding: run.output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self), "")
        XCTAssertEqual(run.process.terminationStatus, 1)
    }

    func testAQuitOrTheStatsOfAClosedAppStartNoApp() async throws {
        for call in [["app", "quit"], ["spot", "stats"]] {
            let run = try start(call, variables: ["OPENSPOT_START_WAIT": "5"])

            try await wait("the end of the call") { !run.process.isRunning }

            XCTAssertEqual(String(decoding: run.output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self), "app: \(call.joined(separator: " "))\n")
        }
    }

    func testCtrlCStopsTheWorkOfTheCallInTheAppAndItChangesNothing() async throws {
        socket = CommandSocket(folder: config, api: CommandAPI(mac: Host(), app: SlowApp(folder: folder)))
        let run = try start(["setting", "change", "--spot", "repos", "folder"])
        try await wait("the start of the work") { exists("started") }

        run.process.interrupt()

        try await wait("the end of the work") { exists("ended") }
        try await wait("the end of the command") { !run.process.isRunning }
        XCTAssertFalse(exists("far"))
        XCTAssertEqual(run.process.terminationStatus, 130)
    }

    func testOnlyACallThatNeedsTheStateOfTheAppIsLive() {
        for live in [["app", "status"], ["spot", "open", "x"], ["setting", "change", "k"], ["event", "emit", "a.b"], ["update", "check"], ["batch"]] {
            XCTAssertTrue(CommandKind.needsApp(live), live.joined(separator: " "))
        }
        for files in [["spot", "list"], ["setting", "get", "k"], ["calc", "solve", "1"], ["setting", "set", "--spot", "openspot", "login", "true"], ["app", "quit"], ["spot", "stats"], ["guide"], ["screen", "shot"], []] {
            XCTAssertFalse(CommandKind.needsApp(files), files.joined(separator: " "))
        }
    }

    func testThroughALinkItStartsTheAppOfItsResolvedPath() throws {
        let link = folder.appendingPathComponent("openspot")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: client)

        XCTAssertEqual(try run(link, ["spot", "new", "x"]).output, "app: spot new x\n")
    }
}
