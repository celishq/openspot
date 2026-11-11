import XCTest
@testable import OpenspotCore

/// Proves that the socket of the API answers a JSON-RPC request on one line with what the call prints.
final class CommandSocketTests: XCTestCase {
    private final class Host: Mac {
        func eventStore() -> any EventStore { FakeEventStore() }
        func reminderStore() -> any ReminderStore { FakeReminderStore() }
        func showCalendar(at time: Date) throws {}
        func open(_ link: URL) -> Bool { true }
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

    /// Sends one line to the socket, and returns the JSON line that comes back.
    private func send(_ line: String) throws -> [String: Any] {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let path = Array(folder.appendingPathComponent(CommandSocket.name).path.utf8)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: path) }
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        defer { close(descriptor) }
        let connected = withUnsafePointer(to: address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        XCTAssertEqual(connected, 0)
        let bytes = Array((line + "\n").utf8)
        XCTAssertEqual(write(descriptor, bytes, bytes.count), bytes.count)
        var answer = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while case let count = read(descriptor, &buffer, buffer.count), count > 0 {
            answer.append(contentsOf: buffer[..<count])
        }
        XCTAssertEqual(answer.last, UInt8(ascii: "\n"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: answer) as? [String: Any])
    }

    private func ask(_ argv: [String]) throws -> [String: Any] {
        let request: [String: Any] = ["jsonrpc": "2.0", "id": 7, "method": "ask", "params": ["argv": argv, "cwd": folder.path, "env": ["OPENSPOT_CONFIG": folder.path]]]
        return try send(String(decoding: JSONSerialization.data(withJSONObject: request), as: UTF8.self))
    }

    func testACalcSumIsAnswered() throws {
        let answer = try ask(["calc", "solve", "2+2"])
        let result = try XCTUnwrap(answer["result"] as? [String: Any])

        XCTAssertEqual(answer["id"] as? Int, 7)
        XCTAssertEqual(TextBlock.blocks(in: result["stdout"] as? String ?? "").first?.value("title"), "4")
        XCTAssertEqual(result["stderr"] as? String, "")
        XCTAssertEqual(result["code"] as? Int, 0)
    }

    func testAFailedCallKeepsItsStderrAndCode() throws {
        let result = try XCTUnwrap(try ask(["calc", "2+2"])["result"] as? [String: Any])

        XCTAssertTrue((result["stderr"] as? String ?? "").hasPrefix("openspot cannot do this: calc 2+2"))
        XCTAssertEqual(result["code"] as? Int, 2)
    }

    func testACallThatRunsAloneGetsAnError() throws {
        let answer = try ask(["color", "pick"])

        XCTAssertNil(answer["result"])
        XCTAssertNotNil((answer["error"] as? [String: Any])?["code"] as? Int)
    }

    func testARelativeFolderOfTheCallerIsReadFromItsWorkingFolder() throws {
        let request: [String: Any] = ["jsonrpc": "2.0", "id": 1, "method": "ask", "params": ["argv": ["setting", "set", "--spot", "notes", "tone", "warm"], "cwd": folder.path, "env": ["OPENSPOT_CONFIG": "own"]]]
        _ = try send(String(decoding: JSONSerialization.data(withJSONObject: request), as: UTF8.self))

        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("own/config.toml").path))
    }

    func testARelativeSourceOfSpotAddIsReadFromTheWorkingFolderOfTheCaller() throws {
        let source = folder.appendingPathComponent("sources/tea")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try "#!/bin/sh\n".writeScript(to: source.appendingPathComponent("tea.sh"))
        let plugins = folder.appendingPathComponent("plugins").path
        let request: [String: Any] = ["jsonrpc": "2.0", "id": 1, "method": "ask", "params": ["argv": ["spot", "add", "tea"], "cwd": folder.appendingPathComponent("sources").path, "env": ["OPENSPOT_CONFIG": folder.path, "OPENSPOT_PLUGINS": plugins]]]

        let result = try XCTUnwrap(try send(String(decoding: JSONSerialization.data(withJSONObject: request), as: UTF8.self))["result"] as? [String: Any])

        XCTAssertEqual(result["code"] as? Int, 0, result["stderr"] as? String ?? "")
        XCTAssertTrue(FileManager.default.fileExists(atPath: plugins + "/tea/tea.sh"))
    }

    func testALineThatIsNoRequestGetsAnError() throws {
        XCTAssertEqual((try send("hello")["error"] as? [String: Any])?["code"] as? Int, -32700)
    }
}
