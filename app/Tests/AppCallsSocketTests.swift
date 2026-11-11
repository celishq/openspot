import XCTest
@testable import OpenspotCore

/// Proves that the running app answers `check`, `spot run`, `spot show` and `sandbox` on its socket: a run gets the folder,
/// the variables and the stdin of its caller and streams each frame, Ctrl-C stops its script, and Careful mode fences what
/// a run or a check starts to the uses of the spot and of its caller (Z8).
final class AppCallsSocketTests: XCTestCase {
    private final class Host: Mac {
        func eventStore() -> any EventStore { FakeEventStore() }
        func reminderStore() -> any ReminderStore { FakeReminderStore() }
        func showCalendar(at time: Date) throws {}
        func open(_ link: URL) -> Bool { true }
    }

    private var folder: URL!
    private var outside: URL!
    private var socket: CommandSocket?

    private var config: URL { folder.appendingPathComponent("config", isDirectory: true) }
    private var plugins: URL { config.appendingPathComponent("plugins", isDirectory: true) }

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("oa-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        let home = try XCTUnwrap(ProcessInfo.processInfo.environment["HOME"], "the test scheme gives a private home")
        outside = URL(fileURLWithPath: home, isDirectory: true).appendingPathComponent("oa-\(UUID().uuidString.prefix(8))", isDirectory: true).standardizedFileURL
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        socket?.close()
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.removeItem(at: outside)
    }

    private func listen(app: (any RunningApp)? = nil, runs: SpotRuns? = nil) {
        socket = CommandSocket(folder: folder, api: CommandAPI(mac: Host(), app: app, runs: runs))
    }

    private func connect() -> SocketConnection {
        SocketConnection(path: folder.appendingPathComponent(CommandSocket.name).path)
    }

    private func request(_ argv: [String], env: [String: String] = [:], cwd: URL? = nil, piped: Bool = false) -> [String: Any] {
        let variables = ["OPENSPOT_CONFIG": config.path, "OPENSPOT_PLUGINS": plugins.path].merging(env) { _, new in new }
        return ["jsonrpc": "2.0", "id": 1, "method": "ask", "params": ["argv": argv, "cwd": (cwd ?? folder).path, "env": variables, "piped": piped]]
    }

    private func ask(_ argv: [String], env: [String: String] = [:], cwd: URL? = nil, input: [String]? = nil) throws -> SocketConnection.Exchange {
        let connection = connect()
        defer { connection.close() }
        try connection.send(request(argv, env: env, cwd: cwd, piped: input != nil))
        return try connection.exchange(input: input ?? [])
    }

    private func spot(_ name: String, header: String = "", _ body: String) throws {
        let lines = header.split(separator: "\n").map { "# \($0)" }.joined(separator: "\n")
        try "#!/bin/sh\n\(lines)\n\(body)\n".writeScript(to: plugins.appendingPathComponent("\(name).sh"))
    }

    /// Waits for a fact, for 10 seconds at most.
    private func wait(_ what: String, until fact: () -> Bool) async throws {
        for _ in 0..<1000 {
            if fact() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited for \(what)")
    }

    private func exists(_ file: URL) -> Bool {
        FileManager.default.fileExists(atPath: file.path)
    }

    func testASpotRunGetsTheFolderTheVariablesAndTheStdinOfItsCaller() throws {
        try spot("echo", "printf 'folder=%s\\ntone=%s\\n---\\n' \"$PWD\" \"$TONE\"; cat")
        listen()

        let answer = try ask(["spot", "run", "echo"], env: ["TONE": "warm"], cwd: outside, input: ["note=", "hi\n"])

        XCTAssertEqual(answer.stdout, "folder=\(outside.path)\ntone=warm\n---\nnote=hi\n")
        XCTAssertEqual(answer.code, 0, answer.stderr)
    }

    func testASpotRunSendsEachFrameAsItComes() throws {
        let go = folder.appendingPathComponent("go")
        try spot("slow", "printf 'title=one\\n---\\n'; i=0; while [ ! -f '\(go.path)' ] && [ $i -lt 1000 ]; do sleep 0.01; i=$((i+1)); done; printf 'title=two\\n'")
        listen()
        let connection = connect()
        defer { connection.close() }
        try connection.send(request(["spot", "run", "slow"]))

        let first = try XCTUnwrap(try connection.next())
        FileManager.default.createFile(atPath: go.path, contents: nil)
        let rest = try connection.exchange()

        XCTAssertEqual((first["params"] as? [String: Any])?["text"] as? String, "title=one\n")
        XCTAssertEqual(rest.stdout, "---\ntitle=two\n")
        XCTAssertEqual(rest.code, 0)
    }

    func testCtrlCStopsTheScriptOfASpotRunAndItChangesNothing() async throws {
        let started = folder.appendingPathComponent("started")
        let far = folder.appendingPathComponent("far")
        try spot("long", "echo $$ > '\(started.path)'; sleep 30; touch '\(far.path)'")
        listen()
        let connection = connect()
        try connection.send(request(["spot", "run", "long"]))
        try await wait("the start of the script") { exists(started) && !((try? String(contentsOf: started, encoding: .utf8)) ?? "").isEmpty }
        let script = try XCTUnwrap(pid_t(try String(contentsOf: started, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)))

        connection.close()

        try await wait("the end of the script") { kill(script, 0) != 0 }
        XCTAssertFalse(exists(far))
    }

    func testCarefulModeRunsASpotRunWithinItsUsesAndThoseOfItsCaller() async throws {
        try spot("writer", header: "uses=files", "echo a > '\(outside.path)/'\"$1\" && echo wrote")
        try spot("reader", "echo")
        let runs = await SpotRuns()
        await MainActor.run { runs.isCareful = true }
        listen(runs: runs)
        let reader = try XCTUnwrap(SpotFolder(url: plugins).scan().scripts.first { $0.id == "reader" })
        let token = runs.tokens.issue(for: reader)

        let person = try ask(["spot", "run", "writer", "person"])
        let spot = try ask(["spot", "run", "writer", "spot"], env: [CallerTokens.variable: token])

        XCTAssertEqual(person.stdout, "wrote\n", person.stderr)
        XCTAssertTrue(exists(outside.appendingPathComponent("person")))
        XCTAssertFalse(exists(outside.appendingPathComponent("spot")))
        XCTAssertNotEqual(spot.code, 0)
    }

    func testACheckInTheAppReadsARelativeFolderOfItsCallerAndRunsEachReadInCarefulMode() async throws {
        let leak = outside.appendingPathComponent("leak")
        try spot("leaky", header: "read=sheet", "echo a > '\(leak.path)'; printf 'title=Leaky\\n'")
        let runs = await SpotRuns()
        await MainActor.run { runs.isCareful = true }
        listen(runs: runs)

        let answer = try ask(["check", "plugins"], cwd: config)

        XCTAssertEqual(answer.stdout, "No faults in \(plugins.path).\n")
        XCTAssertEqual(answer.code, 0)
        XCTAssertFalse(exists(leak))
    }

    func testACheckAsJSONInTheAppNamesEachFault() async throws {
        try spot("weather", header: "size=huge", "echo")
        listen()

        let answer = try ask(["check", "--json"])

        let json = try JSONSerialization.jsonObject(with: Data(answer.stdout.utf8)) as? [[String: String]]
        XCTAssertEqual(json?.map { $0["fault"] }, ["Weather has an unknown size: huge"])
        XCTAssertEqual(answer.code, 1)
    }

    func testSpotShowRevealsTheSpotInTheApp() async throws {
        let app = FakeRunningApp()
        listen(app: app)

        let shown = try ask(["spot", "show", "notes"])
        let gone = try ask(["spot", "show", "gone"])

        XCTAssertEqual(shown.stdout, "Openspot shows notes.\n")
        XCTAssertEqual(gone.stderr, "Openspot has no spot gone. Run `openspot check` to see each file that does not load.\n")
        XCTAssertEqual(gone.code, 1)
        let opened = await app.opened
        XCTAssertEqual(opened, ["reveal notes", "reveal gone"])
    }

    func testSandboxOpensAsAWindowOfTheAppWithTheFileOfTheCallersFolder() async throws {
        let app = FakeRunningApp()
        listen(app: app)

        let answer = try ask(["sandbox", "sheet.txt"], cwd: outside)

        XCTAssertEqual(answer.code, 0)
        let opened = await app.opened
        XCTAssertEqual(opened, ["sandbox \(outside.appendingPathComponent("sheet.txt").path) careful=false"])
    }
}
