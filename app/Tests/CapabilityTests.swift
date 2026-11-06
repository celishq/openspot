import XCTest
@testable import OpenspotCore

/// Proves K1 to K3 with real processes, through a stand-in capability: a small program that uses the same `Capability`.
final class CapabilityTests: XCTestCase {
    private var folder: URL!
    private var label = ""

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
        setenv("STANDIN_FOLDER", folder.path, 1)
        setenv("STANDIN_IDLE", "30", 1)
    }

    override func tearDown() async throws {
        for id in await helpers() { kill(id, SIGKILL) }
        unsetenv("STANDIN_FOLDER")
        unsetenv("STANDIN_IDLE")
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
        try? FileManager.default.removeItem(at: folder)
    }

    /// One call, as a terminal makes it.
    private func call(_ request: String = "count") async throws -> String {
        try await ScriptProcess.output(url: tool, arguments: ["call", label], input: request, limit: 30)
    }

    /// A script that makes one call, and prints its answer.
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

    /// Waits for a fact, for at most the seconds given.
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

        let first = try await ScriptProcess.output(url: url, limit: 30)
        let second = try await ScriptProcess.output(url: url, limit: 30)
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

        let answers = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<total {
                group.addTask { try await ScriptProcess.output(url: url, limit: 30) }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }

        XCTAssertEqual(Set(try answers.map { try field("pid", in: $0) }).count, 1)
        XCTAssertEqual(Set(try answers.map { try field("count", in: $0) }), Set(1...total))
        let settled = await wait(seconds: 10) { await self.helpers().count == 1 }
        XCTAssertTrue(settled)
    }

    func testTheHelperIsGoneAfterItsIdleTimeAndTheNextCallStartsANewOne() async throws {
        setenv("STANDIN_IDLE", "0.5", 1)

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

    func testACallPutsOffTheIdleExit() async throws {
        setenv("STANDIN_IDLE", "1", 1)
        let id = try field("pid", in: try await call())

        for _ in 0..<4 {
            try await Task.sleep(for: .seconds(0.4))
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
        let process = ScriptProcess(url: url, limit: 30)
        var frames = try process.start().makeAsyncIterator()
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
        let process = ScriptProcess(url: tool, arguments: ["call", label], mode: .once(input: "slow"))
        _ = try process.start()
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
        } catch PluginError.failed(let code, let line) {
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

    func testAFailedStartFailsWithOneLineThatNamesTheCauseAndTheFix() async throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: folder.path)

        do {
            let answer = try await call()
            XCTFail("It answered: \(answer)")
        } catch PluginError.failed(let code, let line) {
            XCTAssertEqual(code, 1)
            XCTAssertTrue(line.contains("could not start its \(label) helper"), line)
            XCTAssertTrue(line.contains("Permission denied"), line)
            XCTAssertTrue(line.contains("Make sure that you can write to \(folder.path)"), line)
        }
    }

    func testAPathTooLongForASocketFailsWithItsFix() async throws {
        let long = folder.appendingPathComponent(String(repeating: "a", count: 110), isDirectory: true)
        setenv("STANDIN_FOLDER", long.path, 1)

        do {
            let answer = try await call()
            XCTFail("It answered: \(answer)")
        } catch PluginError.failed(_, let line) {
            XCTAssertTrue(line.contains("too long"), line)
            XCTAssertTrue(line.contains("Use a shorter folder"), line)
        }
    }
}
