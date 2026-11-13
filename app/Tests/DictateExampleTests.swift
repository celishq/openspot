import XCTest
@testable import OpenspotCore

/// Proves the Dictate example: the words it keeps from Whisper, the sound it sends, and how its script wakes the helper.
final class DictateExampleTests: SampleSpotsCase {
    private static let model = "ggml-large-v3-turbo.bin"

    /// The data folder of the spot, with a stand-in Whisper server on the `PATH` and a stand-in helper that runs this
    /// body. The helper's file is newer than the source, so the script does not build it.
    private func fakeHelper(_ body: String, model: Bool = true, in folder: URL) throws -> URL {
        try "#!/bin/sh\nexit 0\n".writeScript(to: folder.appendingPathComponent("tools/whisper-server"))
        let data = folder.appendingPathComponent(".config/openspot/data/dictate")
        try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        try "#!/bin/sh\n\(body)\n".writeScript(to: data.appendingPathComponent("dictate"))
        if model { try Data().write(to: data.appendingPathComponent(Self.model)) }
        return data
    }

    private func helper() async throws -> (URL, URL) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-dictate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let helper = folder.appendingPathComponent("dictate")
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/swiftc"), arguments: ["-o", helper.path, examples.appendingPathComponent("dictate.spot/dictate.swift").path])
        return (folder, helper)
    }

    private func waitFor(_ url: URL) async throws {
        for _ in 0..<100 where !FileManager.default.fileExists(atPath: url.path) {
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    /// Waits up to ten seconds for a fact.
    private func waitUntil(_ fact: () -> Bool) async throws {
        for _ in 0..<200 where !fact() {
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    /// A process that only sleeps, which stands in for the app that a helper watches.
    private func sleeping() throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["600"]
        try process.run()
        return process
    }

    /// The helper in `folder`, waiting as the script starts it, with a stand-in Whisper server on its `PATH` that writes
    /// its process ID to `server` in the folder and sleeps.
    private func stay(_ helper: URL, watching parent: Process, action: String? = nil, rest: String = "600", in folder: URL) throws -> Process {
        try "#!/bin/sh\necho $$ > '\(folder.path)/server.new'\nmv '\(folder.path)/server.new' '\(folder.path)/server'\nexec /bin/sleep 600\n".writeScript(to: folder.appendingPathComponent("tools/whisper-server"))
        let process = Process()
        process.executableURL = helper
        process.arguments = ["stay", String(parent.processIdentifier), folder.appendingPathComponent(Self.model).path] + (action.map { [$0] } ?? [])
        process.environment = ["PATH": "\(folder.path)/tools:/usr/bin:/bin", "HOME": folder.path, "DICTATE_REST": rest]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        return process
    }

    /// The process ID of the stand-in Whisper server, once it runs.
    private func server(in folder: URL) async throws -> pid_t {
        let file = folder.appendingPathComponent("server")
        try await waitUntil { FileManager.default.fileExists(atPath: file.path) }
        return try XCTUnwrap(pid_t(try String(contentsOf: file, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)))
    }

    func testAHelperEndedByForceTakesItsWhisperServerWithIt() async throws {
        let (folder, helper) = try await helper()
        defer { try? FileManager.default.removeItem(at: folder) }
        let parent = try sleeping()
        defer { parent.terminate() }
        let staying = try stay(helper, watching: parent, action: "serve", in: folder)
        defer { kill(staying.processIdentifier, SIGKILL) }
        let server = try await server(in: folder)
        defer { kill(server, SIGKILL) }

        kill(staying.processIdentifier, SIGKILL)
        try await waitUntil { kill(server, 0) != 0 }

        XCTAssertNotEqual(kill(server, 0), 0)
    }

    func testTheEndOfTheAppEndsTheHelperAndItsWhisperServer() async throws {
        let (folder, helper) = try await helper()
        defer { try? FileManager.default.removeItem(at: folder) }
        let parent = try sleeping()
        defer { parent.terminate() }
        let staying = try stay(helper, watching: parent, action: "serve", in: folder)
        defer { kill(staying.processIdentifier, SIGKILL) }
        let server = try await server(in: folder)
        defer { kill(server, SIGKILL) }

        parent.terminate()
        try await waitUntil { !staying.isRunning && kill(server, 0) != 0 }

        XCTAssertFalse(staying.isRunning)
        XCTAssertNotEqual(kill(server, 0), 0)
    }

    func testAWhisperServerThatHeardNoRecordingStopsAfterItsRest() async throws {
        let (folder, helper) = try await helper()
        defer { try? FileManager.default.removeItem(at: folder) }
        let parent = try sleeping()
        defer { parent.terminate() }
        let staying = try stay(helper, watching: parent, action: "serve", rest: "0.3", in: folder)
        defer { kill(staying.processIdentifier, SIGKILL) }
        let server = try await server(in: folder)
        defer { kill(server, SIGKILL) }

        try await waitUntil { kill(server, 0) != 0 }

        XCTAssertNotEqual(kill(server, 0), 0)
        XCTAssertTrue(staying.isRunning)
    }

    func testTheHelperKeepsItsProcessIDInThePidFile() async throws {
        let (folder, helper) = try await helper()
        defer { try? FileManager.default.removeItem(at: folder) }
        let parent = try sleeping()
        defer { parent.terminate() }
        let pidfile = folder.appendingPathComponent("dictate.pid")

        let staying = try stay(helper, watching: parent, in: folder)
        defer { kill(staying.processIdentifier, SIGKILL) }
        try await waitUntil { (try? String(contentsOf: pidfile, encoding: .utf8)) == String(staying.processIdentifier) }

        XCTAssertEqual(try String(contentsOf: pidfile, encoding: .utf8), String(staying.processIdentifier))
    }

    func testASecondHelperHandsItsActionToTheOneThatWaitsAndEnds() async throws {
        let (folder, helper) = try await helper()
        defer { try? FileManager.default.removeItem(at: folder) }
        let parent = try sleeping()
        defer { parent.terminate() }
        let fetched = folder.appendingPathComponent("fetched")
        try Data().write(to: folder.appendingPathComponent(Self.model))
        let waiting = Process()
        waiting.executableURL = URL(fileURLWithPath: "/bin/sh")
        waiting.arguments = ["-c", "trap 'touch \(fetched.path)' USR2; while true; do sleep 0.05; done"]
        try waiting.run()
        defer { waiting.terminate() }
        let pidfile = folder.appendingPathComponent("dictate.pid")
        try String(waiting.processIdentifier).write(to: pidfile, atomically: true, encoding: .utf8)
        let held = open(pidfile.path, O_RDONLY)
        defer { close(held) }
        XCTAssertEqual(flock(held, LOCK_EX), 0)

        let second = try stay(helper, watching: parent, action: "fetch", in: folder)
        defer { kill(second.processIdentifier, SIGKILL) }
        try await waitUntil { !second.isRunning && FileManager.default.fileExists(atPath: fetched.path) }

        XCTAssertFalse(second.isRunning)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fetched.path))
    }

    func testTheHelperKeepsTheWordsAndDropsTheTagsOfSounds() async throws {
        let (folder, helper) = try await helper()
        defer { try? FileManager.default.removeItem(at: folder) }
        let input = folder.appendingPathComponent("heard")
        try " [BLANK_AUDIO]\n Привіт, світе.\n (soft music)\n  Second   line [Music] here.\n *laughs*\n".write(to: input, atomically: true, encoding: .utf8)

        let text = try await ScriptProcess.output(url: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "'\(helper.path)' clean < '\(input.path)'"])
        let silence = try await ScriptProcess.output(url: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "printf ' [BLANK_AUDIO]\\n' | '\(helper.path)' clean"])
        let dot = try await ScriptProcess.output(url: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "printf ' .\\n' | '\(helper.path)' clean"])

        XCTAssertEqual(text, "Привіт, світе. Second line here.\n")
        XCTAssertEqual(silence, "\n")
        XCTAssertEqual(dot, "\n")
    }

    func testTheHelperSendsSixteenBitMonoSoundAtSixteenKilohertz() async throws {
        let (folder, helper) = try await helper()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("speech.wav")

        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "'\(helper.path)' wave 0 1 -1 2 > '\(file.path)'"])
        let wave = try Data(contentsOf: file)

        func number(_ at: Int, _ size: Int) -> Int { wave[at..<at + size].reversed().reduce(0) { $0 << 8 | Int($1) } }
        XCTAssertEqual(String(decoding: wave[0..<4], as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: wave[8..<16], as: UTF8.self), "WAVEfmt ")
        XCTAssertEqual(number(22, 2), 1)
        XCTAssertEqual(number(24, 4), 16_000)
        XCTAssertEqual(number(34, 2), 16)
        XCTAssertEqual(number(40, 4), 8)
        XCTAssertEqual([number(44, 2), number(46, 2), number(48, 2), number(50, 2)], [0, 32_767, 32_769, 32_767])
    }

    func testAPressWakesTheHelperThatWaitsAndStartsNoOther() async throws {
        let dictate = try example("Dictate")
        try await withPrivateHome { folder in
            let pressed = folder.appendingPathComponent("pressed")
            let started = folder.appendingPathComponent("started")
            let data = try self.fakeHelper("touch '\(started.path)'", in: folder)
            let waiting = try TestChild("/bin/sh", ["-c", "trap 'touch \(pressed.path)' USR1; while [ ! -f \(pressed.path) ]; do sleep 0.05; done"])
            defer { waiting.stop() }
            try String(waiting.processIdentifier).write(to: data.appendingPathComponent("dictate.pid"), atomically: true, encoding: .utf8)

            _ = try await dictate.perform(.press("dictate"), timeout: 5)
            try await self.waitFor(pressed)

            XCTAssertTrue(FileManager.default.fileExists(atPath: pressed.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: started.path))
        }
    }

    func testAPressWithNoHelperStartsOneThatRecordsAtOnce() async throws {
        let dictate = try example("Dictate")
        try await withPrivateHome { folder in
            let started = folder.appendingPathComponent("started")
            _ = try self.fakeHelper("echo \"$1 $4\" > '\(started.path)'", in: folder)

            _ = try await dictate.perform(.press("dictate"), timeout: 5)
            try await self.waitFor(started)

            XCTAssertEqual(try self.read("started", in: folder), "stay start\n")
        }
    }

    func testAPressWithNoModelStartsTheHelperThatDownloadsIt() async throws {
        let dictate = try example("Dictate")
        try await withPrivateHome { folder in
            let started = folder.appendingPathComponent("started")
            _ = try self.fakeHelper("echo \"$1 $4\" > '\(started.path)'", model: false, in: folder)

            _ = try await dictate.perform(.press("dictate"), timeout: 5)
            try await self.waitFor(started)

            XCTAssertEqual(try self.read("started", in: folder), "stay start\n")
            XCTAssertNil(try? self.read("fetched", in: folder))
        }
    }

    func testTheModelLandsWholeOrNotAtAll() async throws {
        let (folder, helper) = try await helper()
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("model.bin")
        let target = folder.appendingPathComponent("data/ggml.bin")
        try Data((0..<200_000).map { UInt8($0 % 251) }).write(to: source)

        let landed = try await ScriptProcess.output(url: helper, arguments: ["fetch", source.absoluteString, target.path])
        let failed = try? await ScriptProcess.output(url: helper, arguments: ["fetch", folder.appendingPathComponent("gone.bin").absoluteString, folder.appendingPathComponent("none.bin").path])

        XCTAssertEqual(landed, "from 0\nlanded\n")
        XCTAssertEqual(try Data(contentsOf: target), try Data(contentsOf: source))
        XCTAssertNotEqual(failed, "landed\n")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("none.bin").path))
    }

    func testThePillRidesTheEdgeNearestThePointerAndStandsUpOnTheSides() async throws {
        let (folder, helper) = try await helper()
        defer { try? FileManager.default.removeItem(at: folder) }

        func place(_ kept: String, droppedAt x: Int, _ y: Int) async throws -> String {
            try await ScriptProcess.output(url: helper, arguments: ["place", kept, String(x), String(y)])
        }

        let standard = try await place("", droppedAt: 500, 20)
        let side = try await place("bottom 0.5", droppedAt: 5, 300)
        let corner = try await place("top 0.99", droppedAt: 990, 690)
        let middle = try await place("left 0.5", droppedAt: 600, 650)
        let old = try await place("0.49 10", droppedAt: 500, 350)

        XCTAssertEqual(standard, "bottom 0.5000 425 8 150 32 | bottom 0.5000 425 8 150 32\n")
        XCTAssertEqual(side, "bottom 0.5000 425 8 150 32 | left 0.4286 8 225 32 150\n")
        XCTAssertEqual(corner, "top 0.9900 842 660 150 32 | top 0.9900 842 660 150 32\n")
        XCTAssertEqual(middle, "left 0.5000 8 275 32 150 | top 0.6000 525 660 150 32\n")
        XCTAssertEqual(old, "bottom 0.5000 425 8 150 32 | bottom 0.5000 425 8 150 32\n")
    }

    func testTheHistoryListsTheNewestTextFirstAndKeepsTheLastTen() async throws {
        let (folder, helper) = try await helper()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("history")

        for index in 0..<13 {
            _ = try await ScriptProcess.output(url: helper, arguments: ["remember", file.path, String(1_000 + index), "Text \(index)"])
        }
        let lines = try String(contentsOf: file, encoding: .utf8).split(separator: "\n")

        XCTAssertEqual(lines.count, 10)
        XCTAssertEqual(lines.first, "1003000\tText 3")
        XCTAssertEqual(lines.last, "1012000\tText 12")
    }

    func testTheSheetListsPastTextsAndCopiesOrDeletesOne() async throws {
        let dictate = try example("Dictate")
        try await withPrivateHome { folder in
            let data = try self.fakeHelper("true", in: folder)
            try "1000\tFirst words\n2000\tSecond, with a back\\slash\n".write(to: data.appendingPathComponent("history"), atomically: true, encoding: .utf8)

            let rows = try await dictate.items(timeout: 5).items.filter { !$0.run.hasPrefix("key:") }
            let toast = try await dictate.perform(.item(SpotItem(title: "First words", run: "1000")), timeout: 5)
            _ = try await dictate.perform(SpotAction(arguments: ["delete", "2000"]), timeout: 5)

            XCTAssertEqual(rows.map(\.run), ["2000", "1000"])
            XCTAssertEqual(rows.map(\.title), ["Second, with a back\\slash", "First words"])
            XCTAssertEqual(toast, "Copied")
            XCTAssertEqual(try self.read("clipboard", in: folder), "First words")
            XCTAssertEqual(try String(contentsOf: data.appendingPathComponent("history"), encoding: .utf8), "1000\tFirst words\n")
        }
    }

    func testWithNoModelTheSheetOffersTheDownloadAndThenShowsItsPercent() async throws {
        let dictate = try example("Dictate")
        try await withPrivateHome { folder in
            let fetched = folder.appendingPathComponent("fetch")
            let data = try self.fakeHelper("true", model: false, in: folder)
            let first = try await dictate.items(timeout: 5)
            let offer = first.items.first { $0.run == "whisper" }

            let waiting = try TestChild("/bin/sh", ["-c", "trap 'touch \(fetched.path)' USR2; while true; do sleep 0.05; done"])
            defer { waiting.stop() }
            try String(waiting.processIdentifier).write(to: data.appendingPathComponent("dictate.pid"), atomically: true, encoding: .utf8)
            try "42".write(to: data.appendingPathComponent("download"), atomically: true, encoding: .utf8)
            let progress = try await dictate.items(timeout: 5).items.first { $0.run == "whisper" }
            _ = try await dictate.perform(.item(try XCTUnwrap(offer)), timeout: 5)
            try await self.waitFor(fetched)

            XCTAssertEqual(offer?.title, "Download speech model")
            XCTAssertEqual(offer?.pin, .top)
            XCTAssertTrue(first.hidesSearch)
            XCTAssertEqual(offer?.openTitle, "Download")
            XCTAssertEqual(offer?.staysOnPick, true)
            XCTAssertEqual(progress?.title, "Downloading speech model")
            XCTAssertEqual(progress?.subtitle, "42% of 1.6 GB")
            XCTAssertTrue(FileManager.default.fileExists(atPath: fetched.path))
        }
    }

    func testABrokenDownloadGoesOnFromTheBytesItHas() async throws {
        let (folder, helper) = try await helper()
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("model.bin")
        let target = folder.appendingPathComponent("ggml.bin")
        let bytes = Data((0..<300_000).map { UInt8($0 % 251) })
        try bytes.write(to: source)
        try bytes.prefix(100_000).write(to: target.appendingPathExtension("part"))
        let server = folder.appendingPathComponent("serve.py")
        try """
        import http.server, re, sys
        data = open(sys.argv[1], 'rb').read()
        class H(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                m = re.match(r'bytes=(\\d+)-', self.headers.get('Range', ''))
                start = int(m.group(1)) if m else 0
                open(sys.argv[2], 'a').write(str(start) + '\\n')
                self.send_response(206 if m else 200)
                self.send_header('Content-Length', str(len(data) - start))
                self.end_headers()
                self.wfile.write(data[start:])
            def log_message(self, *a): pass
        s = http.server.HTTPServer(('127.0.0.1', 0), H)
        print(s.server_address[1], flush=True)
        s.serve_forever()
        """.write(to: server, atomically: true, encoding: .utf8)
        let out = Pipe()
        let served = folder.appendingPathComponent("served")
        let serving = try TestChild("/usr/bin/python3", [server.path, source.path, served.path], output: out)
        defer { serving.stop() }
        let port = String(decoding: out.fileHandleForReading.availableData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        let resumed = try await ScriptProcess.output(url: helper, arguments: ["fetch", "http://127.0.0.1:\(port)/model", target.path])

        XCTAssertEqual(resumed, "from 100000\nlanded\n")
        XCTAssertEqual(try String(contentsOf: served, encoding: .utf8), "100000\n")
        XCTAssertEqual(try Data(contentsOf: target), bytes)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.appendingPathExtension("part").path))
    }

    func testADownloadThatCannotResumeStartsOver() async throws {
        let (folder, helper) = try await helper()
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("model.bin")
        let target = folder.appendingPathComponent("ggml.bin")
        let bytes = Data((0..<200_000).map { UInt8($0 % 251) })
        try bytes.write(to: source)
        try Data(repeating: 7, count: 50_000).write(to: target.appendingPathExtension("part"))

        let fetched = try await ScriptProcess.output(url: helper, arguments: ["fetch", source.absoluteString, target.path])

        XCTAssertEqual(fetched, "from 50000\nlanded\n")
        XCTAssertEqual(try Data(contentsOf: target), bytes)
    }
}
