import XCTest
@testable import OpenspotCore

final class CapabilityTests: XCTestCase {
    private var folder: URL!
    private var label = ""
    private var environment: [String: String] = [:]

    private var tool: URL {
        Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("OpenspotStandIn")
    }

    private var socket: String {
        folder.appendingPathComponent("openspot-\(label).socket").path
    }

    override func setUpWithError() throws {
        let tag = String(UUID().uuidString.prefix(8))
        label = "standin-\(tag)"
        folder = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("os-\(tag)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        environment = ProcessInfo.processInfo.environment.merging(["STANDIN_FOLDER": folder.path, "STANDIN_IDLE": "30"]) { _, new in new }
    }

    override func tearDown() async throws {
        for id in await helpers() { kill(id, SIGKILL) }
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
        try? FileManager.default.removeItem(at: folder)
    }

    private func call(_ request: String = "count") async throws -> String {
        try await ScriptProcess.output(url: tool, arguments: ["call", label], input: request, limit: 30, base: environment)
    }

    private func script(after: String = "") throws -> URL {
        let url = folder.appendingPathComponent("script-\(UUID().uuidString.prefix(8))")
        try "#!/bin/sh\nprintf count | '\(tool.path)' call \(label)\n\(after)\n".writeScript(to: url)
        return url
    }

    private func helpers() async -> [pid_t] {
        let found = (try? await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/pgrep"), arguments: ["-f", "helper \(label)"], limit: 30)) ?? ""
        return found.split(separator: "\n").compactMap { pid_t($0) }
    }

    private func field(_ key: String, in answer: String) throws -> Int {
        try XCTUnwrap(TextBlock.blocks(in: answer).first?.number(key).map { Int($0) })
    }

    private func isAlive(_ id: pid_t) -> Bool {
        kill(id, 0) == 0
    }

    private func wait(seconds: TimeInterval, for fact: () async -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if await fact() { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return await fact()
    }

    func testStateStaysAcrossTwoSeparateRunsOfAScriptAndACallFromATerminal() async throws {
        let url = try script()

        let first = try await ScriptProcess.output(url: url, limit: 30, base: environment)
        let second = try await ScriptProcess.output(url: url, limit: 30, base: environment)
        let terminal = try await call()

        XCTAssertEqual(try field("count", in: first), 1)
        XCTAssertEqual(try field("count", in: second), 2)
        XCTAssertEqual(try field("count", in: terminal), 3)
        XCTAssertEqual(try field("pid", in: first), try field("pid", in: second))
        XCTAssertEqual(try field("pid", in: first), try field("pid", in: terminal))
    }

    func testCallsThatRaceToStartItEndWithOneHelper() async throws {
        let url = try script()
        let total = 12
        let environment = environment

        let answers = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<total {
                group.addTask { try await ScriptProcess.output(url: url, limit: 30, base: environment) }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }

        XCTAssertEqual(Set(try answers.map { try field("pid", in: $0) }).count, 1)
        XCTAssertEqual(Set(try answers.map { try field("count", in: $0) }), Set(1...total))
        let settled = await wait(seconds: 10) { await self.helpers().count == 1 }
        XCTAssertTrue(settled)
    }

    func testTheHelperIsGoneAfterItsIdleTimeAndTheNextCallStartsANewOne() async throws {
        environment["STANDIN_IDLE"] = "1"

        let id = pid_t(try field("pid", in: try await call()))
        XCTAssertTrue(isAlive(id))
        XCTAssertTrue(FileManager.default.fileExists(atPath: socket))

        let gone = await wait(seconds: 15) { !self.isAlive(id) }
        XCTAssertTrue(gone)
        XCTAssertFalse(FileManager.default.fileExists(atPath: socket))

        let next = try await call()
        XCTAssertNotEqual(pid_t(try field("pid", in: next)), id)
        XCTAssertEqual(try field("count", in: next), 1)
    }

    func testAHelperWithWorkOutlivesItsIdleTimeAndEndsAfterTheWork() async throws {
        environment["STANDIN_IDLE"] = "1"
        let id = pid_t(try field("pid", in: try await call("hold")))

        try await Task.sleep(for: .seconds(3))
        XCTAssertTrue(isAlive(id))
        let freed = try await call("free")
        XCTAssertEqual(pid_t(try field("pid", in: freed)), id)

        let gone = await wait(seconds: 15) { !self.isAlive(id) }
        XCTAssertTrue(gone)
    }

    func testACallPutsOffTheIdleExit() async throws {
        environment["STANDIN_IDLE"] = "2"
        let id = try field("pid", in: try await call())

        for _ in 0..<4 {
            try await Task.sleep(for: .seconds(0.8))
            let next = try await call()
            XCTAssertEqual(try field("pid", in: next), id)
        }
    }

    func testAHelperLeftByACrashDoesNotBlockANewOne() async throws {
        let id = pid_t(try field("pid", in: try await call()))

        kill(id, SIGKILL)
        let gone = await wait(seconds: 10) { !self.isAlive(id) }
        XCTAssertTrue(gone)
        XCTAssertTrue(FileManager.default.fileExists(atPath: socket))

        let next = try await call()
        XCTAssertNotEqual(pid_t(try field("pid", in: next)), id)
        XCTAssertEqual(try field("count", in: next), 1)
    }

    func testAStopOfAScriptLeavesTheHelper() async throws {
        let url = try script(after: "printf -- '---\\n'\nsleep 30")
        let process = ScriptProcess(url: url, limit: 30, base: environment)
        var frames = process.start().makeAsyncIterator()
        let first = try await frames.next()
        let id = pid_t(try field("pid", in: try XCTUnwrap(first)))

        process.stop()
        let stopped = await wait(seconds: 10) { !process.isRunning }

        XCTAssertTrue(stopped)
        XCTAssertTrue(isAlive(id))
        let next = try await call()
        XCTAssertEqual(try field("count", in: next), 2)
    }

    func testACallerStoppedDuringACallLeavesTheHelperAlive() async throws {
        let id = pid_t(try field("pid", in: try await call()))
        let process = ScriptProcess(url: tool, arguments: ["call", label], mode: .once(input: "slow"), base: environment)
        _ = process.start()
        try await Task.sleep(for: .milliseconds(500))

        process.stop()
        let stopped = await wait(seconds: 10) { !process.isRunning }

        XCTAssertTrue(stopped)
        let next = try await call()
        XCTAssertEqual(pid_t(try field("pid", in: next)), id)
    }

    func testAHelperThatEndsBeforeItAnswersIsAFailureAndNotAnEmptyAnswer() async throws {
        do {
            let answer = try await call("die")
            XCTFail("It answered: \(answer)")
        } catch SpotError.failed(let code, let line) {
            XCTAssertEqual(code, 1)
            XCTAssertTrue(line.contains("ended before it answered"), line)
        }

        let next = try await call()
        XCTAssertEqual(try field("count", in: next), 1)
    }

    func testAnEmptyAnswerIsAnAnswer() async throws {
        let answer = try await call("empty")

        XCTAssertEqual(answer, "")
    }

    func testALargeRequestAndAnswerArriveWhole() async throws {
        let text = String(repeating: "line \\ one\n", count: 100_000)

        let answer = try await call("echo \(text)")

        XCTAssertEqual(answer, text)
    }

    func testACallToAHelperThatNeverAnswersEndsAtItsLimit() async throws {
        let listener = try fakeHelper { _ in }
        defer { Darwin.close(listener) }
        let capability = Capability(name: label, folder: folder, limit: 0.3)

        let outcome = Outcome()
        Thread.detachNewThread { outcome.set(Result { try capability.call(Data("count".utf8)) }) }

        try await wait("the end of the call") { outcome.value != nil }
        XCTAssertEqual(outcome.failure, .noAnswerInTime(name: label, seconds: 0.3))
    }

    func testAnAnswerOverTheLimitFailsAtItsLength() async throws {
        let listener = try fakeHelper { connection in
            var length = UInt64(Capability.messageLimit + 1).littleEndian
            _ = withUnsafeBytes(of: &length) { Darwin.write(connection, $0.baseAddress, $0.count) }
        }
        defer { Darwin.close(listener) }
        let capability = Capability(name: label, folder: folder, limit: 30)

        let outcome = Outcome()
        Thread.detachNewThread { outcome.set(Result { try capability.call(Data("count".utf8)) }) }

        try await wait("the end of the call") { outcome.value != nil }
        XCTAssertEqual(outcome.failure, .tooLarge(name: label))
    }

    func testARequestOverTheLimitLeavesTheHelperAnswering() async throws {
        let id = try field("pid", in: try await call())
        let connection = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        defer { Darwin.close(connection) }
        var address = Self.address(of: socket)
        let connected = withUnsafePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(connection, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
        XCTAssertEqual(connected, 0)

        var length = UInt64.max
        _ = withUnsafeBytes(of: &length) { Darwin.write(connection, $0.baseAddress, $0.count) }
        var byte: UInt8 = 0
        XCTAssertEqual(Darwin.read(connection, &byte, 1), 0)

        let next = try await call()
        XCTAssertEqual(try field("pid", in: next), id)
    }

    private final class Outcome: @unchecked Sendable {
        private let lock = NSLock()
        private var result: Result<Data, Error>?

        var value: Result<Data, Error>? {
            lock.withLock { result }
        }

        var failure: Capability.Failure? {
            guard case .failure(let error) = value else { return nil }
            return error as? Capability.Failure
        }

        func set(_ result: Result<Data, Error>) {
            lock.withLock { self.result = result }
        }
    }

    private static func address(of path: String) -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: Array(path.utf8)) }
        return address
    }

    private func fakeHelper(answer: @escaping @Sendable (Int32) -> Void) throws -> Int32 {
        let listener = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        var address = Self.address(of: socket)
        let bound = withUnsafePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(listener, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
        XCTAssertEqual(bound, 0)
        XCTAssertEqual(Darwin.listen(listener, 4), 0)
        Thread.detachNewThread {
            let connection = Darwin.accept(listener, nil, nil)
            guard connection >= 0 else { return }
            var head = [UInt8](repeating: 0, count: 8)
            _ = Darwin.read(connection, &head, 8)
            answer(connection)
        }
        return listener
    }

    func testAFailedStartFailsWithOneLineThatNamesTheCauseAndTheFix() async throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: folder.path)

        do {
            let answer = try await call()
            XCTFail("It answered: \(answer)")
        } catch SpotError.failed(let code, let line) {
            XCTAssertEqual(code, 1)
            XCTAssertTrue(line.contains("could not start its \(label) helper"), line)
            XCTAssertTrue(line.contains("Permission denied"), line)
            XCTAssertTrue(line.contains("Make sure that you can write to \(folder.path)"), line)
        }
    }

    func testAPathTooLongForASocketFailsWithItsFix() async throws {
        let long = folder.appendingPathComponent(String(repeating: "a", count: 110), isDirectory: true)
        environment["STANDIN_FOLDER"] = long.path

        do {
            let answer = try await call()
            XCTFail("It answered: \(answer)")
        } catch SpotError.failed(_, let line) {
            XCTAssertTrue(line.contains("too long"), line)
            XCTAssertTrue(line.contains("Use a shorter folder"), line)
        }
    }
}
