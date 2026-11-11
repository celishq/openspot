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
        func quit() async {}
        func open(_ id: String) async -> Bool { true }
        func review(_ id: String) async -> Bool { true }

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

    /// One connection to the socket, which reads the lines that come back one at a time.
    private final class Connection {
        let descriptor: Int32
        private var buffer = Data()

        init(path: String) {
            var address = sockaddr_un()
            address.sun_family = sa_family_t(AF_UNIX)
            let bytes = Array(path.utf8)
            withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
            descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
            var time = timeval(tv_sec: 10, tv_usec: 0)
            setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &time, socklen_t(MemoryLayout<timeval>.size))
            let connected = withUnsafePointer(to: address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
            }
            XCTAssertEqual(connected, 0)
        }

        func send(_ object: [String: Any]) throws {
            let bytes = Array(try JSONSerialization.data(withJSONObject: object)) + [UInt8(ascii: "\n")]
            XCTAssertEqual(write(descriptor, bytes, bytes.count), bytes.count)
        }

        func send(line: String) {
            let bytes = Array((line + "\n").utf8)
            XCTAssertEqual(write(descriptor, bytes, bytes.count), bytes.count)
        }

        /// The next line as a JSON object, or nil at the end of the stream or after 10 seconds with none.
        func next() throws -> [String: Any]? {
            var chunk = [UInt8](repeating: 0, count: 4096)
            while !buffer.contains(UInt8(ascii: "\n")) {
                let count = read(descriptor, &chunk, chunk.count)
                guard count > 0 else { return nil }
                buffer.append(contentsOf: chunk[..<count])
            }
            let end = buffer.firstIndex(of: UInt8(ascii: "\n"))!
            let line = buffer[buffer.startIndex..<end]
            buffer = Data(buffer[(end + 1)...])
            return try XCTUnwrap(JSONSerialization.jsonObject(with: line) as? [String: Any])
        }

        func close() {
            Darwin.close(descriptor)
        }
    }

    /// What one call printed, and the reply that ended it.
    private struct Exchange {
        var stdout = ""
        var stderr = ""
        var reply: [String: Any] = [:]

        var code: Int? {
            (reply["result"] as? [String: Any])?["code"] as? Int
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

    private func connect() -> Connection {
        Connection(path: folder.appendingPathComponent(CommandSocket.name).path)
    }

    /// Reads the stream of a call to its reply, and answers a pull of stdin with the input.
    private func exchange(on connection: Connection, input: [String] = []) throws -> Exchange {
        var exchange = Exchange()
        while let line = try connection.next() {
            let text = (line["params"] as? [String: Any])?["text"] as? String ?? ""
            switch line["method"] as? String {
            case "stdout": exchange.stdout += text
            case "stderr": exchange.stderr += text
            case "stdin":
                for chunk in input { try connection.send(["jsonrpc": "2.0", "method": "stdin", "params": ["text": chunk]]) }
                try connection.send(["jsonrpc": "2.0", "method": "stdin", "params": ["end": true]])
            default:
                exchange.reply = line
                return exchange
            }
        }
        XCTFail("the stream ended with no reply")
        return exchange
    }

    private func request(_ argv: [String], env: [String: String]? = nil, cwd: String? = nil) -> [String: Any] {
        ["jsonrpc": "2.0", "id": 7, "method": "ask", "params": ["argv": argv, "cwd": cwd ?? folder.path, "env": env ?? ["OPENSPOT_CONFIG": folder.path]]]
    }

    private func ask(_ argv: [String], env: [String: String]? = nil, cwd: String? = nil, input: [String] = []) throws -> Exchange {
        let connection = connect()
        defer { connection.close() }
        try connection.send(request(argv, env: env, cwd: cwd))
        return try exchange(on: connection, input: input)
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
        let plugins = folder.appendingPathComponent("plugins").path

        let answer = try ask(["spot", "add", "tea"], env: ["OPENSPOT_CONFIG": folder.path, "OPENSPOT_PLUGINS": plugins], cwd: folder.appendingPathComponent("sources").path)

        XCTAssertEqual(answer.code, 0, answer.stderr)
        XCTAssertTrue(FileManager.default.fileExists(atPath: plugins + "/tea/tea.sh"))
    }

    func testALineThatIsNoRequestGetsAnError() throws {
        let connection = connect()
        defer { connection.close() }
        connection.send(line: "hello")

        XCTAssertEqual((try exchange(on: connection).reply["error"] as? [String: Any])?["code"] as? Int, -32700)
    }
}
