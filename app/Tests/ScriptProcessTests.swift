import XCTest
@testable import OpenspotCore

final class ScriptProcessTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("openspot-run-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func writePlugin(_ name: String, _ body: String) throws -> PluginCommand {
        let url = folder.appendingPathComponent(name)
        try body.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return PluginCommand(id: name, name: name, url: url)
    }

    func testReturnsWhatThePluginPrintsForTheArguments() async throws {
        let plugin = try writePlugin("echo.sh", "#!/bin/sh\necho \"$1\"\n")

        let output = try await ScriptProcess.output(url: plugin.url, arguments: ["hello"], limit: 5)

        XCTAssertEqual(output, "hello\n")
    }

    func testGivesTheInputToThePlugin() async throws {
        let plugin = try writePlugin("cat.sh", "#!/bin/sh\ncat\n")

        let output = try await ScriptProcess.output(url: plugin.url, input: "line \"one\"\nline two", limit: 5)

        XCTAssertEqual(output, "line \"one\"\nline two")
    }

    func testAPluginThatIgnoresALargeInputStillFinishes() async throws {
        let plugin = try writePlugin("quiet.sh", "#!/bin/sh\necho done\n")

        let output = try await ScriptProcess.output(url: plugin.url, input: String(repeating: "x", count: 500_000), limit: 5)

        XCTAssertEqual(output, "done\n")
    }

    func testARunGetsTheDataFolderAndOpenspotCreatesIt() async throws {
        let config = folder.appendingPathComponent("config")
        setenv("OPENSPOT_CONFIG", config.path, 1)
        defer { unsetenv("OPENSPOT_CONFIG") }
        let plugin = try writePlugin("data.sh", "#!/bin/sh\nprintf %s \"$OPENSPOT_DATA\"\n")
        let data = config.appendingPathComponent("data").path

        let output = try await ScriptProcess.output(url: plugin.url, limit: 5)

        XCTAssertEqual(output, data)
        var isFolder: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: data, isDirectory: &isFolder))
        XCTAssertTrue(isFolder.boolValue)
    }

    func testTheDataFolderIsInTheHomeOfTheRunWithNoConfigPath() {
        let environment = ScriptProcess.environment(base: ["HOME": folder.path], app: "")

        XCTAssertEqual(environment["OPENSPOT_DATA"], folder.appendingPathComponent(".config/openspot/data").path)
    }

    private func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path)
    }

    private func path(_ name: String) -> String {
        folder.appendingPathComponent(name).path
    }

    func testAStopEndsTheStreamAtOnceWithNoError() async throws {
        let plugin = try writePlugin("slow.sh", "#!/bin/sh\nsleep 30\n")
        let process = ScriptProcess(url: plugin.url)
        let frames = try process.start()
        let started = Date()

        process.stop()
        for try await _ in frames { XCTFail("no frame") }

        XCTAssertLessThan(Date().timeIntervalSince(started), 1)
        XCTAssertTrue(process.isStopped)
    }

    func testAStopReachesEachChildOfTheScript() async throws {
        let plugin = try writePlugin("child.sh", "#!/bin/sh\n(sleep 0.8; touch '\(path("child"))') &\nprintf 'a=1\\n---\\n'\nwait\n")
        let process = ScriptProcess(url: plugin.url)
        var frames = try process.start().makeAsyncIterator()
        _ = try await frames.next()

        process.stop()
        try await Task.sleep(for: .seconds(1.2))

        XCTAssertFalse(exists("child"))
    }

    func testAStopGivesTheScriptTheTerminateSignalAndTimeToEnd() async throws {
        let plugin = try writePlugin("term.sh", "#!/bin/sh\ntrap 'sleep 0.5; touch \"\(path("cleaned"))\"; exit 0' TERM\nprintf 'a=1\\n---\\n'\nwhile :; do sleep 0.1; done\n")
        let process = ScriptProcess(url: plugin.url)
        var frames = try process.start().makeAsyncIterator()
        _ = try await frames.next()

        process.stop()
        try await Task.sleep(for: .seconds(1.5))

        XCTAssertTrue(exists("cleaned"))
        XCTAssertFalse(process.isRunning)
    }

    func testAScriptThatIgnoresTheTerminateSignalEndsAfterTwoSeconds() async throws {
        let plugin = try writePlugin("deaf.sh", "#!/bin/sh\ntrap '' TERM\nprintf 'a=1\\n---\\n'\nwhile :; do sleep 0.1; done\n")
        let process = ScriptProcess(url: plugin.url)
        var frames = try process.start().makeAsyncIterator()
        _ = try await frames.next()

        process.stop()
        try await Task.sleep(for: .seconds(1))
        XCTAssertTrue(process.isRunning)
        try await Task.sleep(for: .seconds(1.5))

        XCTAssertFalse(process.isRunning)
    }

    func testACallGoesOnWhileAChildHoldsItsOutput() async throws {
        let plugin = try writePlugin("child.sh", "#!/bin/sh\n(sleep 0.3; printf 'late=1\\n') &\nexit 0\n")

        let output = try await ScriptProcess.output(url: plugin.url, limit: 5)

        XCTAssertEqual(output, "late=1\n")
    }

    func testACallEndsWhenItsOutputCloses() async throws {
        let plugin = try writePlugin("away.sh", "#!/bin/sh\nsleep 30 >/dev/null 2>&1 &\nprintf 'a=1\\n'\nexit 0\n")
        let started = Date()

        let output = try await ScriptProcess.output(url: plugin.url, limit: 5)

        XCTAssertEqual(output, "a=1\n")
        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
    }

    func testAScriptKilledBySomethingElseIsAFailure() async throws {
        let plugin = try writePlugin("killed.sh", "#!/bin/sh\nkill -KILL $$\n")

        do {
            _ = try await ScriptProcess.output(url: plugin.url, limit: 5)
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(error as? PluginError, .failed(9, ""))
        }
    }

    func testAOutOfTimeFirstFrameStopsTheScript() async throws {
        let plugin = try writePlugin("late.sh", "#!/bin/sh\nsleep 0.8\ntouch '\(path("went-on"))'\n")

        do {
            _ = try await ScriptProcess.output(url: plugin.url, limit: 0.2)
            XCTFail("expected a timeout")
        } catch PluginError.timedOut {
        }
        try await Task.sleep(for: .seconds(1))

        XCTAssertFalse(exists("went-on"))
    }

    func testTimesOutASlowPlugin() async throws {
        let plugin = try writePlugin("slow.sh", "#!/bin/sh\nsleep 5\n")

        do {
            _ = try await ScriptProcess.output(url: plugin.url, limit: 0.5)
            XCTFail("expected a timeout")
        } catch PluginError.timedOut {
        }
    }
}
