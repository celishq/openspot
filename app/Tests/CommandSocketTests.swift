import XCTest
@testable import OpenspotCore

/// Proves that the socket of the API answers a JSON-RPC request on one line with a stream of JSON-RPC notifications, one
/// object per line: each piece of stdout and stderr as it comes, a pull of stdin, and then the exit code.
final class CommandSocketTests: XCTestCase {
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
        func allows(_ reason: String) async -> Bool { false }
        func quit() async {}
        func open(_ id: String, page: String?) async -> Bool { true }
        func back(_ id: String) async -> Bool { true }
        func review(_ id: String) async -> Bool { true }
        func act(_ act: CardAct, on id: String) async -> Bool { true }
        func choose(for id: String) async -> Bool { true }
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

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("os-\(UUID().uuidString.prefix(8))", isDirectory: true)
        socket = CommandSocket(folder: folder, api: CommandAPI(mac: Host()))
    }

    override func tearDownWithError() throws {
        socket?.close()
        try? FileManager.default.removeItem(at: folder)
    }

    private func connect() -> SocketConnection {
        SocketConnection(path: folder.appendingPathComponent(CommandSocket.name).path)
    }

    private func request(_ argv: [String], env: [String: String]? = nil, cwd: String? = nil) -> [String: Any] {
        ["jsonrpc": "2.0", "id": 7, "method": "ask", "params": ["argv": argv, "cwd": cwd ?? folder.path, "env": env ?? ["OPENSPOT_CONFIG": folder.path]]]
    }

    private func ask(_ argv: [String], env: [String: String]? = nil, cwd: String? = nil, input: [String] = []) throws -> SocketConnection.Exchange {
        let connection = connect()
        defer { connection.close() }
        try connection.send(request(argv, env: env, cwd: cwd))
        return try connection.exchange(input: input)
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

    func testOnlyThePersonCanReachTheSocket() throws {
        let mode = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: folder.appendingPathComponent(CommandSocket.name).path)[.posixPermissions] as? Int)

        XCTAssertEqual(mode & 0o777, 0o600)
    }

    func testACalcSumStreamsItsOutputThenItsCode() throws {
        let answer = try ask(["calc", "solve", "2+2"])

        XCTAssertEqual(answer.reply["id"] as? Int, 7)
        XCTAssertEqual(TextBlock.blocks(in: answer.stdout).first?.value("title"), "4")
        XCTAssertEqual(answer.stderr, "")
        XCTAssertEqual(answer.code, 0)
    }

    func testAFailedCallKeepsItsStderrAndCode() throws {
        let answer = try ask(["calc", "2+2"])

        XCTAssertTrue(answer.stderr.hasPrefix("openspot cannot do this: calc 2+2"))
        XCTAssertEqual(answer.code, 2)
    }

    func testACallThatRunsAloneGetsAnError() throws {
        let answer = try ask(["render", "x.png"])

        XCTAssertNil(answer.reply["result"])
        XCTAssertEqual((answer.reply["error"] as? [String: Any])?["code"] as? Int, -32000)
    }

    func testStdinComesInChunksOnlyWhenTheCallPullsIt() throws {
        let answer = try ask(["check", "--sheet"], input: ["title=", "Hi\n"])

        XCTAssertEqual(answer.stdout, "the sheet has no parts\n1 faults.\n")
        XCTAssertEqual(answer.code, 1)
    }

    func testASlowCallSendsItsFirstChunkBeforeItsEnd() async throws {
        socket?.close()
        socket = CommandSocket(folder: folder, api: CommandAPI(mac: Host(), app: SlowApp(folder: folder)))
        let connection = connect()
        defer { connection.close() }
        try connection.send(request(["batch"]))
        XCTAssertEqual(try connection.next()?["method"] as? String, "stdin")
        try connection.send(["jsonrpc": "2.0", "method": "stdin", "params": ["text": "calc solve 2+2\nsetting change --spot repos folder\n"]])
        try connection.send(["jsonrpc": "2.0", "method": "stdin", "params": ["end": true]])

        let first = try XCTUnwrap(try connection.next())

        XCTAssertEqual(first["method"] as? String, "stdout")
        XCTAssertEqual(TextBlock.blocks(in: (first["params"] as? [String: Any])?["text"] as? String ?? "").first?.value("title"), "4")
        XCTAssertFalse(exists("ended"))
    }

    func testAClosedConnectionStopsItsCallAndTheCallChangesNothing() async throws {
        socket?.close()
        socket = CommandSocket(folder: folder, api: CommandAPI(mac: Host(), app: SlowApp(folder: folder)))
        let connection = connect()
        try connection.send(request(["setting", "change", "--spot", "repos", "folder"]))
        try await wait("the start of the work") { exists("started") }

        connection.close()

        try await wait("the end of the work") { exists("ended") }
        XCTAssertFalse(exists("far"))
    }

    func testARelativeFolderOfTheCallerIsReadFromItsWorkingFolder() throws {
        _ = try ask(["setting", "set", "--spot", "notes", "tone", "warm"], env: ["OPENSPOT_CONFIG": "own"])

        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("own/config.toml").path))
    }

    func testAVariableThatIsNoPathPassesAsItIs() throws {
        _ = try ask(["setting", "set", "tone", "warm"], env: ["OPENSPOT_CONFIG": folder.path, "OPENSPOT_ID": "home/coffee"])

        XCTAssertEqual(ConfigFile(url: folder.appendingPathComponent("config.toml")).read().setting("tone", of: "home/coffee"), "warm")
    }

    func testARelativeSourceOfSpotAddIsReadFromTheWorkingFolderOfTheCaller() throws {
        let source = folder.appendingPathComponent("sources/tea")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try "#!/bin/sh\n".writeScript(to: source.appendingPathComponent("tea.sh"))
        let spots = folder.appendingPathComponent("spots").path

        let answer = try ask(["spot", "add", "tea"], env: ["OPENSPOT_CONFIG": folder.path, "OPENSPOT_SPOTS": spots], cwd: folder.appendingPathComponent("sources").path)

        XCTAssertEqual(answer.code, 0, answer.stderr)
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots + "/tea.spot/tea.sh"))
    }

    func testALineThatIsNoRequestGetsAnError() throws {
        let connection = connect()
        defer { connection.close() }
        connection.send(line: "hello")

        XCTAssertEqual((try connection.exchange().reply["error"] as? [String: Any])?["code"] as? Int, -32700)
    }
}
