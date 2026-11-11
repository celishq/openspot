import XCTest
@testable import OpenspotCore

final class ScriptProcessTests: XCTestCase {
    private static let stopPause: TimeInterval = 0.2

    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("openspot-run-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func writePlugin(_ name: String, _ body: String) throws -> Spot {
        let url = folder.appendingPathComponent(name)
        try body.writeScript(to: url)
        return Spot(id: name, name: name, url: url)
    }

    func testRunningScriptsHoldNoThreadEach() async throws {
        let plugin = try writePlugin("stays.sh", "#!/bin/sh\nprintf 'title=A\\n---\\n'\nexec sleep 30\n")
        let before = Self.threadCount()
        var processes: [ScriptProcess] = []
        for _ in 0..<16 {
            let process = ScriptProcess(url: plugin.url, mode: .stays, stopPause: Self.stopPause)
            var frames = process.start().makeAsyncIterator()
            _ = try await frames.next()
            processes.append(process)
        }

        let during = Self.threadCount()
        processes.forEach { $0.stop() }
        for process in processes { process.finish(by: Date().addingTimeInterval(5)) }

        XCTAssertLessThan(during - before, 16)
    }

    private static func threadCount() -> Int {
        var list: thread_act_array_t?
        var count: mach_msg_type_number_t = 0
        guard task_threads(mach_task_self_, &list, &count) == KERN_SUCCESS, let list else { return 0 }
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: list), vm_size_t(Int(count) * MemoryLayout<thread_t>.stride))
        return Int(count)
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

    func testARunNamesTheConfigFolderOfTheApp() {
        let environment = ScriptProcess.environment(base: ["HOME": folder.path], app: "")

        XCTAssertEqual(environment["OPENSPOT_CONFIG"], folder.appendingPathComponent(".config/openspot").path)
    }

    func testASpotHasADataFolderOfItsOwn() {
        let environment = ScriptProcess.environment(base: ["HOME": folder.path], app: "", dataName: "links")

        XCTAssertEqual(environment["OPENSPOT_DATA"], folder.appendingPathComponent(".config/openspot/data/links").path)
        var isFolder: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: environment["OPENSPOT_DATA"] ?? "", isDirectory: &isFolder))
        XCTAssertTrue(isFolder.boolValue)
    }

    func testADataFolderStaysInsideTheDataOfTheApp() {
        let environment = ScriptProcess.environment(base: ["HOME": folder.path], app: "", dataName: "../../up")

        XCTAssertEqual(environment["OPENSPOT_DATA"], folder.appendingPathComponent(".config/openspot/data/up").path)
    }

    private func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path)
    }

    private func path(_ name: String) -> String {
        folder.appendingPathComponent(name).path
    }

    func testAProcessKeepsOnlyTheEndOfALongStderr() async throws {
        let plugin = try writePlugin("loud.sh", "#!/bin/sh\ni=0\nwhile [ $i -lt 5000 ]; do echo \"line $i of a log that runs long\" >&2; i=$((i+1)); done\necho 'the end' >&2\n")
        let process = ScriptProcess(url: plugin.url, limit: 10)

        for try await _ in process.start() {}

        XCTAssertLessThanOrEqual(process.errors.utf8.count, 2 * 64 * 1024)
        XCTAssertGreaterThan(process.errors.utf8.count, 60 * 1024)
        XCTAssertTrue(process.errors.hasSuffix("line 4999 of a log that runs long\nthe end\n"))
    }

    func testAStopEndsTheStreamAtOnceWithNoError() async throws {
        let plugin = try writePlugin("slow.sh", "#!/bin/sh\nsleep 30\n")
        let process = ScriptProcess(url: plugin.url)
        let frames = process.start()
        let started = Date()

        process.stop()
        for try await _ in frames { XCTFail("no frame") }

        XCTAssertLessThan(Date().timeIntervalSince(started), 1)
        XCTAssertTrue(process.isStopped)
    }

    func testAScriptThatCannotStartEndsItsFramesWithTheReason() async throws {
        let process = ScriptProcess(url: folder.appendingPathComponent("missing.sh"), limit: 5)
        let frames = process.start()

        do {
            for try await _ in frames { XCTFail("no frame") }
            XCTFail("no failure")
        } catch {
            XCTAssertFalse(process.isRunning)
        }
    }

    func testAScriptThatCannotStartClosesItsPipesAndEnds() async throws {
        let before = Self.openFileCount()
        var processes: [ScriptProcess] = []
        var times = 0
        for _ in 0..<20 {
            let process = ScriptProcess(url: folder.appendingPathComponent("missing.sh"))
            let ended = expectation(description: "the end")
            process.onExit { _ in ended.fulfill() }
            do { for try await _ in process.start() {} } catch {}
            await fulfillment(of: [ended], timeout: 5)
            times += 1
            processes.append(process)
        }

        XCTAssertEqual(times, 20)
        XCTAssertLessThan(Self.openFileCount() - before, 6)
    }

    func testAMissingScriptFailsAsAMissingFile() async throws {
        let url = folder.appendingPathComponent("missing.sh")

        do {
            _ = try await ScriptProcess.output(url: url)
            XCTFail("no failure")
        } catch let error as CocoaError {
            XCTAssertEqual(error.code, .fileNoSuchFile)
            XCTAssertEqual(error.userInfo[NSFilePathErrorKey] as? String, url.path)
        }
    }

    private static func openFileCount() -> Int {
        (try? FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count) ?? 0
    }

    func testAStopRightAfterTheStartLeavesNoScriptRunning() async throws {
        let plugin = try writePlugin("slow.sh", "#!/bin/sh\n\(writesPid("script"))\nsleep 30\n")
        let process = ScriptProcess(url: plugin.url, stopPause: Self.stopPause)
        let frames = process.start()

        process.stop()
        for try await _ in frames { XCTFail("no frame") }
        try await Task.sleep(for: .seconds(Self.stopPause * 3))

        if exists("script") {
            let script = try await pid("script")
            XCTAssertFalse(runs(script))
        }
    }

    func testAStopReachesEachChildOfTheScript() async throws {
        let plugin = try writePlugin("child.sh", "#!/bin/sh\n(sleep 0.3; touch '\(path("child"))') &\nprintf 'a=1\\n---\\n'\nwait\n")
        let process = ScriptProcess(url: plugin.url)
        var frames = process.start().makeAsyncIterator()
        _ = try await frames.next()

        process.stop()
        try await Task.sleep(for: .seconds(0.5))

        XCTAssertFalse(exists("child"))
    }

    func testAStopGivesTheScriptTheTerminateSignalAndTimeToEnd() async throws {
        let plugin = try writePlugin("term.sh", "#!/bin/sh\ntrap 'sleep 0.1; touch \"\(path("cleaned"))\"; exit 0' TERM\nprintf 'a=1\\n---\\n'\n\(String.longLoop)\n")
        let process = ScriptProcess(url: plugin.url)
        var frames = process.start().makeAsyncIterator()
        _ = try await frames.next()

        process.stop()

        try await wait { self.exists("cleaned") && !process.isRunning }
    }

    func testAScriptThatIgnoresTheTerminateSignalEndsAfterTwoSeconds() async throws {
        let plugin = try writePlugin("deaf.sh", "#!/bin/sh\ntrap '' TERM\nprintf 'a=1\\n---\\n'\n\(String.longLoop)\n")
        let process = ScriptProcess(url: plugin.url)
        var frames = process.start().makeAsyncIterator()
        _ = try await frames.next()

        let started = Date()
        process.stop()
        try await wait(seconds: 10) { !process.isRunning }

        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), 2)
    }

    /// A line that writes the pid of its shell to the file `name` whole, so that a reader never sees it half written.
    private func writesPid(_ name: String) -> String {
        "echo $$ > '\(path(name)).new' && mv '\(path(name)).new' '\(path(name))'"
    }

    /// A child that ignores the terminate signal, with its output somewhere else, so that its end does not close the call.
    private func deafChild() -> String {
        "sh -c \"trap '' TERM; \(writesPid("child").replacingOccurrences(of: "$$", with: "\\$\\$")); exec sleep 30\" >/dev/null 2>&1 &\n"
    }

    private func pid(_ name: String) async throws -> Int32 {
        for _ in 0..<500 where !exists(name) { try await Task.sleep(for: .milliseconds(10)) }
        return try XCTUnwrap(Int32(try String(contentsOfFile: path(name), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)))
    }

    private func runs(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0
    }

    private func wait(seconds: Int = 5, until fact: () -> Bool) async throws {
        for _ in 0..<(seconds * 100) {
            if fact() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited too long")
    }

    func testAScriptAndAChildThatIgnoreTheTerminateSignalAreGoneOnePauseAfterAStop() async throws {
        let plugin = try writePlugin("deaf.sh", "#!/bin/sh\ntrap '' TERM\n\(writesPid("script"))\n\(deafChild())printf 'a=1\\n---\\n'\n\(String.longLoop)\n")
        let process = ScriptProcess(url: plugin.url, stopPause: Self.stopPause)
        var frames = process.start().makeAsyncIterator()
        _ = try await frames.next()
        let script = try await pid("script")
        let child = try await pid("child")
        let started = Date()

        process.stop()
        try await wait { !self.runs(script) && !self.runs(child) }

        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), Self.stopPause)
    }

    func testAChildThatIgnoresTheTerminateSignalIsGoneAfterItsScriptEndedAtTheStop() async throws {
        let plugin = try writePlugin("parent.sh", "#!/bin/sh\n\(deafChild())printf 'a=1\\n---\\n'\nsleep 30\n")
        let process = ScriptProcess(url: plugin.url, stopPause: Self.stopPause)
        var frames = process.start().makeAsyncIterator()
        _ = try await frames.next()
        let child = try await pid("child")
        let started = Date()

        process.stop()
        try await wait { !self.runs(child) }

        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), Self.stopPause)
        XCTAssertFalse(process.isRunning)
    }

    func testAStopLeavesAChildAloneAfterItsCallEndedByItself() async throws {
        let plugin = try writePlugin("away.sh", "#!/bin/sh\n\(deafChild())\n")
        let process = ScriptProcess(url: plugin.url, stopPause: Self.stopPause)
        for try await _ in process.start() {}
        let child = try await pid("child")
        defer { kill(child, SIGKILL) }

        process.stop()
        try await Task.sleep(for: .seconds(Self.stopPause + 0.2))

        XCTAssertTrue(runs(child))
    }

    func testAnEndClosesTheInputThenStopsThenKillsTheGroupOfAStayingScript() async throws {
        let plugin = try writePlugin("stay.sh", "#!/bin/sh\ntrap '' TERM\n\(writesPid("script"))\n\(deafChild())printf 'a=1\\n---\\n'\n\(String.longLoop)\n")
        let live = ScriptProcess(url: plugin.url, mode: .stays, stopPause: Self.stopPause)
        var frames = live.start().makeAsyncIterator()
        _ = try await frames.next()
        let script = try await pid("script")
        let child = try await pid("child")
        let started = Date()

        live.end()
        try await wait { !self.runs(script) && !self.runs(child) }

        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), Self.stopPause * 2)
    }

    func testAnEndReachesAChildAfterAStayingScriptEndedWithItsInput() async throws {
        let plugin = try writePlugin("stay.sh", "#!/bin/sh\n\(deafChild())printf 'a=1\\n---\\n'\ncat >/dev/null\n")
        let live = ScriptProcess(url: plugin.url, mode: .stays, stopPause: Self.stopPause)
        var frames = live.start().makeAsyncIterator()
        _ = try await frames.next()
        let child = try await pid("child")
        let started = Date()

        live.end()
        try await wait { !self.runs(child) }

        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), Self.stopPause * 2)
        XCTAssertFalse(live.isRunning)
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

    func testAFailureNamesTheLastLineOfALongStderr() async throws {
        let body = "i=0\nwhile [ $i -lt 5000 ]; do echo \"line $i of the log\" >&2; i=$((i+1)); done\nprintf 'the last\\n\\n' >&2\nprintf 'cut' >&2\nprintf ' short\\n' >&2\nexit 3\n"
        let plugin = try writePlugin("noisy.sh", "#!/bin/sh\n\(body)")

        do {
            _ = try await ScriptProcess.output(url: plugin.url, limit: 5)
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(error as? SpotError, .failed(3, "cut short"))
        }
    }

    func testAFailureNamesItsLastWordsAfterManyBlankLines() async throws {
        let plugin = try writePlugin("blank.sh", "#!/bin/sh\necho boom >&2\ni=0\nwhile [ $i -lt 80000 ]; do echo >&2; i=$((i+1)); done\nexit 3\n")

        do {
            _ = try await ScriptProcess.output(url: plugin.url, limit: 10)
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(error as? SpotError, .failed(3, "boom"))
        }
    }

    func testAFailureNamesTheLastLineOfAStderrWithWindowsLineEnds() async throws {
        let plugin = try writePlugin("crlf.sh", "#!/bin/sh\nprintf 'first\\r\\nboom\\r\\n\\r\\n' >&2\nexit 3\n")

        do {
            _ = try await ScriptProcess.output(url: plugin.url, limit: 10)
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(error as? SpotError, .failed(3, "boom"))
        }
    }

    func testAScriptKilledBySomethingElseIsAFailure() async throws {
        let plugin = try writePlugin("killed.sh", "#!/bin/sh\nkill -KILL $$\n")

        do {
            _ = try await ScriptProcess.output(url: plugin.url, limit: 5)
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(error as? SpotError, .failed(9, ""))
        }
    }

    func testAOutOfTimeFirstFrameStopsTheScript() async throws {
        let plugin = try writePlugin("late.sh", "#!/bin/sh\n\(writesPid("script"))\nsleep 30\ntouch '\(path("went-on"))'\n")

        do {
            _ = try await ScriptProcess.output(url: plugin.url, limit: 1)
            XCTFail("expected a timeout")
        } catch SpotError.timedOut {
        }
        let script = try await pid("script")
        try await wait { !self.runs(script) }

        XCTAssertFalse(exists("went-on"))
    }
}
