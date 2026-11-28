import XCTest
import os
@testable import OpenspotCore

final class CommandSocketTests: XCTestCase {
    private struct SlowApp: RunningApp {
        let folder: URL

        func configChanged(_ change: ConfigChange, to config: KeptConfig) async {}
        func spotsChanged() async {}
        func status() async -> (update: String?, calls: Int, isFirstLaunch: Bool) { (nil, 0, false) }
        func checkUpdate() async -> Bool { true }
        func installUpdate() async -> Bool { true }
        func allows(_ reason: String) async -> Bool { false }
        func quit() async {}
        func apply(_ theme: Theme) async {}
        func open(_ id: String) async -> Bool { true }
        func push(_ id: String, route: String?, title: String?, replace: Bool) async -> Bool { true }
        func pop(_ id: String, all: Bool) async -> Bool { true }
        func openSession(_ id: String) async -> Bool { true }
        func stepSession(by steps: Int) async -> Bool { true }
        func review(_ id: String) async -> Bool { true }
        func act(_ act: CardAct, on id: String) async -> Bool { true }
        func choose(for id: String) async -> Bool { true }
        func editGrid() async {}
        func reveal(_ id: String) async -> Bool { true }
        func playground(_ file: URL?) async {}

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
    private var clock: CommandSocket?

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("os-\(UUID().uuidString.prefix(8))", isDirectory: true)
        socket = CommandSocket(folder: folder, api: CommandAPI(mac: Mac(), places: .test(["OPENSPOT_CONFIG": folder.path, "OPENSPOT_SPOTS": folder.appendingPathComponent("spots").path])))
    }

    override func tearDownWithError() throws {
        socket?.close()
        clock?.close()
        try? FileManager.default.removeItem(at: folder)
    }

    private func connect() -> SocketConnection {
        SocketConnection(path: folder.appendingPathComponent(CommandSocket.name).path)
    }

    private func request(_ argv: [String], env: [String: String]? = nil, cwd: String? = nil) -> [String: Any] {
        ["jsonrpc": "2.0", "id": 7, "method": "ask", "params": ["argv": argv, "cwd": cwd ?? folder.path].merging(env.map { ["env": $0] } ?? [:]) { _, new in new }]
    }

    private func ask(_ argv: [String], env: [String: String]? = nil, cwd: String? = nil, input: [String] = []) throws -> SocketConnection.Exchange {
        let connection = connect()
        defer { connection.close() }
        try connection.send(request(argv, env: env, cwd: cwd))
        return try connection.exchange(input: input)
    }

    private func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path)
    }

    func testOnlyThePersonCanReachTheSocket() throws {
        let mode = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: folder.appendingPathComponent(CommandSocket.name).path)[.posixPermissions] as? Int)

        XCTAssertEqual(mode & 0o777, 0o600)
    }

    private var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown") + "\n"
    }

    func testACallStreamsItsOutputThenItsCode() throws {
        let answer = try ask(["version"])

        XCTAssertEqual(answer.reply["id"] as? Int, 7)
        XCTAssertEqual(answer.stdout, version)
        XCTAssertEqual(answer.stderr, "")
        XCTAssertEqual(answer.code, 0)
    }

    func testAFailedCallKeepsItsStderrAndCode() throws {
        let answer = try ask(["calc", "2+2"])

        XCTAssertTrue(answer.stderr.hasPrefix("openspot cannot do this: calc 2+2"))
        XCTAssertEqual(answer.code, 2)
    }

    func testACallThatRunsAloneGetsAnError() throws {
        let answer = try ask(["render", "sheet", "x.png"])

        XCTAssertNil(answer.reply["result"])
        XCTAssertEqual((answer.reply["error"] as? [String: Any])?["code"] as? Int, -32000)
    }

    func testStdinComesInChunksOnlyWhenTheCallPullsIt() throws {
        let answer = try ask(["check", "sheet"], input: ["frame=\ntitle=", "Hi\n"])

        XCTAssertEqual(answer.stdout, "the sheet has no parts\n1 faults.\n")
        XCTAssertEqual(answer.code, 1)
    }

    func testASlowCallSendsItsFirstChunkBeforeItsEnd() async throws {
        socket?.close()
        socket = CommandSocket(folder: folder, api: CommandAPI(mac: Mac(), places: .test(["OPENSPOT_CONFIG": folder.path]), app: SlowApp(folder: folder)))
        let connection = connect()
        defer { connection.close() }
        try connection.send(request(["batch"]))
        XCTAssertEqual(try connection.next()?["method"] as? String, "stdin")
        try connection.send(["jsonrpc": "2.0", "method": "stdin", "params": ["text": "version\nsetting change --spot repos folder\n"]])
        try connection.send(["jsonrpc": "2.0", "method": "stdin", "params": ["end": true]])

        let first = try XCTUnwrap(try connection.next())

        XCTAssertEqual(first["method"] as? String, "stdout")
        XCTAssertEqual(((first["params"] as? [String: Any])?["text"] as? String)?.hasPrefix(version), true)
        XCTAssertFalse(exists("ended"))
    }

    func testAClosedConnectionStopsItsCallAndTheCallChangesNothing() async throws {
        socket?.close()
        socket = CommandSocket(folder: folder, api: CommandAPI(mac: Mac(), places: .test(["OPENSPOT_CONFIG": folder.path]), app: SlowApp(folder: folder)))
        let connection = connect()
        try connection.send(request(["setting", "change", "--spot", "repos", "folder"]))
        try await wait("the start of the work") { exists("started") }

        connection.close()

        try await wait("the end of the work") { exists("ended") }
        XCTAssertFalse(exists("far"))
    }

    func testTheConfigAndTheSpotsOfACallerChangeNothingTheAppWrites() throws {
        let other = folder.appendingPathComponent("other")
        let env = ["OPENSPOT_CONFIG": other.appendingPathComponent("config").path, "OPENSPOT_SPOTS": other.appendingPathComponent("spots").path, "OPENSPOT_ID": "home/coffee"]

        _ = try ask(["setting", "set", "--spot", "notes", "tone", "warm"], env: env)
        _ = try ask(["setting", "set", "tone", "warm"], env: env)
        _ = try ask(["spot", "new", "Tea"], env: env)

        XCTAssertFalse(FileManager.default.fileExists(atPath: other.path))
        let config = ConfigFile(url: folder.appendingPathComponent("config.toml")).read()
        XCTAssertEqual(config.setting("tone", of: "notes"), "warm")
        XCTAssertNil(config.setting("tone", of: "home/coffee"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("spots/tea.spot").path))
    }

    func testARelativeSourceOfSpotAddIsReadFromTheWorkingFolderOfTheCaller() throws {
        let source = folder.appendingPathComponent("sources/tea")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try "#!/bin/sh\n".writeScript(to: source.appendingPathComponent("tea.sh"))
        let spots = folder.appendingPathComponent("spots").path

        let answer = try ask(["spot", "add", "tea"], cwd: folder.appendingPathComponent("sources").path)

        XCTAssertEqual(answer.code, 0, answer.stderr)
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots + "/tea.spot/tea.sh"))
    }

    func testALineThatIsNoRequestGetsAnError() throws {
        let connection = connect()
        defer { connection.close() }
        connection.send(line: "hello")

        XCTAssertEqual((try connection.exchange().reply["error"] as? [String: Any])?["code"] as? Int, -32700)
    }

    private func listen(_ limits: CommandConnection.Limits = CommandConnection.Limits(), mac: Mac = Mac(), peer: @escaping @Sendable (Int32) -> pid_t? = CommandSocket.peer(of:)) {
        socket?.close()
        socket = CommandSocket(folder: folder, api: CommandAPI(mac: mac, places: .test(["OPENSPOT_CONFIG": folder.path])), limits: limits, peer: peer)
    }

    private func isClosed(_ connection: SocketConnection) -> Bool {
        var watched = pollfd(fd: connection.descriptor, events: Int16(POLLIN), revents: 0)
        return poll(&watched, 1, 0) > 0 && watched.revents & Int16(POLLHUP) != 0
    }

    private func tick() async throws {
        let silent = SocketConnection(path: folder.appendingPathComponent("clock").appendingPathComponent(CommandSocket.name).path)
        defer { silent.close() }
        try await wait("the close of a silent caller of the clock") { isClosed(silent) }
    }

    private func askForMuch(_ connection: SocketConnection) throws {
        try connection.send(request(["batch"]))
        XCTAssertEqual(try connection.next()?["method"] as? String, "stdin")
        try connection.send(["jsonrpc": "2.0", "method": "stdin", "params": ["text": String(repeating: "help\n", count: 200)]])
        try connection.send(["jsonrpc": "2.0", "method": "stdin", "params": ["end": true]])
    }

    private func hasAReply(_ connection: SocketConnection) throws -> Bool {
        while let line = try connection.next() {
            if line["result"] != nil || line["error"] != nil { return true }
        }
        return false
    }

    func testASilentCallerHoldsNoThread() async throws {
        listen(CommandConnection.Limits(caller: 600))
        let path = folder.appendingPathComponent(CommandSocket.name).path
        var silent: [SocketConnection] = []
        defer { silent.forEach { $0.close() } }
        for _ in 0..<80 {
            try await wait("the connection of a silent caller") {
                let caller = SocketConnection(path: path, mustConnect: false)
                if caller.isConnected { silent.append(caller) } else { caller.close() }
                return caller.isConnected
            }
        }

        let answer = try ask(["version"])

        XCTAssertEqual(answer.code, 0)
    }

    func testACallerThatStaysSilentGetsAnErrorAndIsClosed() async throws {
        listen(CommandConnection.Limits(caller: 0.05))
        let connection = connect()
        defer { connection.close() }

        try await wait("the close of the silent caller") { isClosed(connection) }

        XCTAssertEqual((try connection.next()?["error"] as? [String: Any])?["code"] as? Int, -32700)
        XCTAssertNil(try connection.next())
    }

    func testARequestLineOverTheLimitIsClosed() async throws {
        listen(CommandConnection.Limits(caller: 600, line: 1024))
        let connection = connect()
        defer { connection.close() }
        let bytes = [UInt8](repeating: UInt8(ascii: "a"), count: 4096)
        XCTAssertEqual(write(connection.descriptor, bytes, bytes.count), bytes.count)

        try await wait("the close of the long line") { isClosed(connection) }

        XCTAssertNil(try connection.next())
    }

    func testAReaderThatTakesNoByteInTimeIsClosedWithNoReply() async throws {
        listen(CommandConnection.Limits(reader: 0.05))
        let connection = connect()
        defer { connection.close() }
        try askForMuch(connection)

        try await wait("the close of the stopped reader") { isClosed(connection) }

        XCTAssertFalse(try hasAReply(connection))
    }

    func testAReaderWithMoreOutputWaitingThanTheLimitIsClosedWithNoReply() async throws {
        listen(CommandConnection.Limits(reader: 600, output: 65_536))
        let connection = connect()
        defer { connection.close() }
        try askForMuch(connection)

        try await wait("the close of the reader that is behind") { isClosed(connection) }

        XCTAssertFalse(try hasAReply(connection))
    }

    func testAnAnswerOverTheOutputLimitReachesAReaderThatKeepsUp() throws {
        let text = String(repeating: "0123456789abcdef", count: 65_536)
        listen(CommandConnection.Limits(output: 65_536), mac: Mac(clipboard: FakeClipboard(text: text)))

        let answer = try ask(["clipboard", "read"])

        XCTAssertEqual(answer.code, 0)
        XCTAssertTrue(answer.stdout.trimmingCharacters(in: .newlines) == text)
    }

    func testAReaderThatIsSlowButTakesBytesGetsTheWholeAnswer() async throws {
        listen(CommandConnection.Limits(reader: 1))
        clock = CommandSocket(folder: folder.appendingPathComponent("clock"), api: CommandAPI(mac: Mac(), places: .test()), limits: CommandConnection.Limits(caller: 0.01))
        let slow = connect()
        let stopped = connect()
        defer {
            slow.close()
            stopped.close()
        }
        try askForMuch(slow)
        try askForMuch(stopped)

        var taken = 0
        while !isClosed(stopped) {
            slow.take(4096)
            taken += 4096
            try await tick()
        }
        let answer = try slow.exchange()

        XCTAssertGreaterThan(answer.stdout.utf8.count, taken)
        XCTAssertEqual(answer.code, 0)
        XCTAssertEqual(answer.stdout.components(separatedBy: "openspot guide ").count - 1, 200)
    }

    func testTheCallerOfEachLineIsReadOnceWhileItsConnectionIsOpen() async throws {
        let reads = OSAllocatedUnfairLock(initialState: [Bool]())
        listen(peer: { descriptor in
            reads.withLock { $0.append(fcntl(descriptor, F_GETFD) >= 0) }
            return getpid()
        })

        for _ in 0..<20 {
            let connection = connect()
            try connection.send(request(["version"]))
            connection.close()
        }

        try await wait("the read of each caller") { reads.withLock { $0.count } >= 20 }
        XCTAssertEqual(reads.withLock { $0 }, Array(repeating: true, count: 20))
    }

    func testARequestWhoseCallerCannotBeReadIsRefused() throws {
        listen(peer: { _ in nil })

        let answer = try ask(["setting", "set", "--spot", "notes", "tone", "warm"])

        XCTAssertEqual((answer.reply["error"] as? [String: Any])?["code"] as? Int, -32001)
        XCTAssertNil(ConfigFile(url: folder.appendingPathComponent("config.toml")).read().setting("tone", of: "notes"))
    }
}
