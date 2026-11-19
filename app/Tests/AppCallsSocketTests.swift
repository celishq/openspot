import XCTest
@testable import OpenspotCore

final class AppCallsSocketTests: XCTestCase {
    private var folder: URL!
    private var outside: URL!
    private var socket: CommandSocket?

    private var config: URL { folder.appendingPathComponent("config", isDirectory: true) }
    private var spots: URL { config.appendingPathComponent("spots", isDirectory: true) }

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("oa-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
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
        socket = CommandSocket(folder: folder, api: CommandAPI(mac: Mac(), places: .test(ProcessInfo.processInfo.environment.merging(["OPENSPOT_CONFIG": config.path, "OPENSPOT_SPOTS": spots.path, "TONE": "warm"]) { _, new in new }), app: app, runs: runs, rates: .offline))
    }

    private func connect() -> SocketConnection {
        SocketConnection(path: folder.appendingPathComponent(CommandSocket.name).path)
    }

    private func request(_ argv: [String], cwd: URL? = nil, piped: Bool = false) -> [String: Any] {
        ["jsonrpc": "2.0", "id": 1, "method": "ask", "params": ["argv": argv, "cwd": (cwd ?? folder).path, "piped": piped] as [String: Any]]
    }

    private func ask(_ argv: [String], channel: RunChannel? = nil, cwd: URL? = nil, input: [String]? = nil) throws -> SocketConnection.Exchange {
        let connection = channel.map(SocketConnection.init(channel:)) ?? connect()
        defer { connection.close() }
        try connection.send(request(argv, cwd: cwd, piped: input != nil))
        return try connection.exchange(input: input ?? [])
    }

    private func spot(_ name: String, toml: String = "", _ body: String) throws {
        try TestSpot(toml: toml, body: "\(body)").write(to: spots.spotFile(name))
    }

    private func exists(_ file: URL) -> Bool {
        FileManager.default.fileExists(atPath: file.path)
    }

    func testASpotRunGetsTheFolderAndTheStdinOfItsCallerAndTheVariablesOfTheApp() throws {
        try spot("echo", "printf 'folder=%s\\ntone=%s\\n---\\n' \"$PWD\" \"$TONE\"; cat")
        listen()

        let answer = try ask(["spot", "run", "echo"], cwd: outside, input: ["note=", "hi\n"])

        XCTAssertEqual(answer.stdout, "folder=\(outside.path)\ntone=warm\n---\nnote=hi\n")
        XCTAssertEqual(answer.code, 0, answer.stderr)
    }

    func testASpotRunSendsEachFrameAsItComes() throws {
        let go = folder.appendingPathComponent("go")
        try spot("slow", "printf 'frame=\\ntitle=one\\n---\\n'; i=0; while [ ! -f '\(go.path)' ] && [ $i -lt 1000 ]; do sleep 0.01; i=$((i+1)); done; printf 'frame=\\ntitle=two\\n'")
        listen()
        let connection = connect()
        defer { connection.close() }
        try connection.send(request(["spot", "run", "slow"]))

        let first = try XCTUnwrap(try connection.next())
        FileManager.default.createFile(atPath: go.path, contents: nil)
        let rest = try connection.exchange()

        XCTAssertEqual((first["params"] as? [String: Any])?["text"] as? String, "frame=\ntitle=one\n")
        XCTAssertEqual(rest.stdout, "---\nframe=\ntitle=two\n")
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

    func testCarefulModeRunsAPersonsSpotRunInItsUsesAndLeavesASpotsRunToItsOwnSandbox() async throws {
        try spot("writer", toml: "uses = ['files']", "echo a > '\(outside.path)/'\"$1\" && echo wrote")
        try spot("reader", toml: "uses = ['spots']", "echo")
        let runs = await SpotRuns()
        await MainActor.run { runs.isCareful = true }
        listen(runs: runs)
        let reader = try XCTUnwrap(SpotsFolder(url: spots).scan().scripts.first { $0.id == "reader" })
        let channel = try XCTUnwrap(runs.callers.channel(for: runs.callers.issue(for: reader)))
        defer { channel.close() }

        let person = try ask(["spot", "run", "writer", "person"])
        let spot = try ask(["spot", "run", "writer", "spot"], channel: channel)

        XCTAssertEqual(person.stdout, "wrote\n", person.stderr)
        XCTAssertTrue(exists(outside.appendingPathComponent("person")))
        XCTAssertFalse(exists(outside.appendingPathComponent("spot")))
        XCTAssertEqual((spot.reply["error"] as? [String: Any])?["code"] as? Int, -32000)
    }

    func testACheckInTheAppReadsARelativeFolderOfItsCallerAndRunsEachReadInCarefulMode() async throws {
        let leak = outside.appendingPathComponent("leak")
        try spot("leaky", toml: "on = ['sheet.open']", "echo a > '\(leak.path)'; printf 'frame=\\ntitle=Leaky\\n'")
        let runs = await SpotRuns()
        await MainActor.run { runs.isCareful = true }
        listen(runs: runs)

        let answer = try ask(["check", "spots", "spots"], cwd: config)

        XCTAssertEqual(answer.stdout, "")
        XCTAssertEqual(answer.code, 0)
        XCTAssertFalse(exists(leak))
    }

    func testTheReadsOfACheckInCarefulModeAreKnownAsTheirSpots() async throws {
        let token = folder.appendingPathComponent("token")
        let go = folder.appendingPathComponent("go")
        let client = Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot")
        try spot("reader", toml: "on = ['sheet.open']", "'\(client.path)' setting get tone > '\(token.path)'; i=0; while [ ! -f '\(go.path)' ] && [ $i -lt 1000 ]; do sleep 0.01; i=$((i+1)); done; printf 'frame=\\ntitle=Reader\\n'")
        let runs = await SpotRuns()
        await MainActor.run { runs.isCareful = true }
        listen(runs: runs)
        XCTAssertEqual(try ask(["setting", "set", "--spot", "reader", "tone", "mine"]).code, 0)
        let connection = connect()
        defer { connection.close() }
        try connection.send(request(["check", "spots"]))
        try await wait("the read") { !((try? String(contentsOf: token, encoding: .utf8)) ?? "").isEmpty }

        let told = try String(contentsOf: token, encoding: .utf8)
        FileManager.default.createFile(atPath: go.path, contents: nil)

        XCTAssertEqual(told, "mine\n")
        XCTAssertEqual(try connection.exchange().code, 0)
    }

    func testACheckAsJSONInTheAppNamesEachFault() async throws {
        try spot("weather", toml: "mode = 'huge'", "echo")
        listen()

        let answer = try ask(["check", "spots", "--json"])

        let json = try JSONSerialization.jsonObject(with: Data(answer.stdout.utf8)) as? [[String: String]]
        XCTAssertEqual(json?.map { $0["fault"] }, ["Weather has an unknown mode: huge. Use once or stay"])
        XCTAssertEqual(answer.code, 1)
    }

    func testSpotShowRevealsTheSpotInTheApp() async throws {
        let app = FakeRunningApp()
        listen(app: app)

        let shown = try ask(["spot", "open", "notes", "--select"])
        let gone = try ask(["spot", "open", "gone", "--select"])

        XCTAssertEqual(shown.stdout, "Openspot shows notes.\n")
        XCTAssertEqual(gone.stderr, "Openspot has no spot gone. Run `openspot check spots` to see each file that does not load.\n")
        XCTAssertEqual(gone.code, 1)
        let opened = await app.opened
        XCTAssertEqual(opened, ["reveal notes", "reveal gone"])
    }

    func testPlaygroundOpensAsAWindowOfTheAppWithTheFileOfTheCallersFolder() async throws {
        let app = FakeRunningApp()
        listen(app: app)

        let answer = try ask(["playground", "open", "sheet.txt"], cwd: outside)

        XCTAssertEqual(answer.code, 0)
        let opened = await app.opened
        XCTAssertEqual(opened, ["playground \(outside.appendingPathComponent("sheet.txt").path) careful=false"])
    }
}
