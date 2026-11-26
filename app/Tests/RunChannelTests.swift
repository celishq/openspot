import XCTest
@testable import OpenspotCore

@MainActor
final class RunChannelTests: SpotRunsCase {
    private var config: URL!
    private var elsewhere: URL!
    private var client: URL!

    override func setUp() async throws {
        try await super.setUp()
        config = FileManager.default.temporaryDirectory.appendingPathComponent("rc-\(UUID().uuidString.prefix(8))", isDirectory: true)
        elsewhere = FileManager.default.temporaryDirectory.appendingPathComponent("rc-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        client = folder.appendingPathComponent("A.app/Contents/Helpers/openspot")
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: client)
        runs.api = CommandAPI(mac: Mac(), places: .test(["OPENSPOT_CONFIG": config.path]), app: FakeRunningApp(), runs: runs)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: config)
        try? FileManager.default.removeItem(at: elsewhere)
        try await super.tearDown()
    }

    private var tone: String? {
        ConfigFile(url: config.appendingPathComponent("config.toml")).read().setting("tone", of: "script")
    }

    private func call(_ words: String) -> String {
        "OPENSPOT_CONFIG='\(elsewhere.path)' '\(client.path)' \(words)"
    }

    private func press() async throws {
        _ = try scanned()
        let sheet = try XCTUnwrap(runs.sheets["script"])
        sheet.pressCard()
        try await wait("the end of the call") { self.log("done").count == 1 }
        try await allEnded()
        try await wait("the end of the call in the sheet") { sheet.calls.isEmpty }
    }

    func testACallOfASpotReachesTheAppThatRanItWhateverItsConfigVariableNames() async throws {
        try script(toml: TestSpot.command, "\(call("setting set tone warm")) 2> '\(path("errors"))'; echo $? >> '\(path("done"))'")

        try await press()

        XCTAssertEqual(log("done"), ["0"], log("errors").joined(separator: "\n"))
        XCTAssertEqual(tone, "warm")
    }

    func testTwoCallsAtOnceInOneRunEachGetTheirOwnAnswer() async throws {
        try script(toml: TestSpot.command, "printf '2\\n' | \(call("cache set one")) 2>> '\(path("errors"))'; printf '42\\n' | \(call("cache set two")) 2>> '\(path("errors"))'; \(call("cache get one")) > '\(path("one"))' & \(call("cache get two")) > '\(path("two"))'; wait; echo 0 >> '\(path("done"))'")

        try await press()

        XCTAssertEqual(log("one"), ["2"], log("errors").joined(separator: "\n"))
        XCTAssertEqual(log("two"), ["42"])
    }

    func testEachShellPassesTheChannelOnToItsChildren() async throws {
        for shell in ["/bin/bash", "/bin/zsh", "/bin/sh"] {
            try? FileManager.default.removeItem(atPath: path("done"))
            try? FileManager.default.removeItem(at: config.appendingPathComponent("config.toml"))
            try script(toml: TestSpot.command, "\(shell) -c \"\(call("setting set tone \(URL(fileURLWithPath: shell).lastPathComponent)").replacingOccurrences(of: "\"", with: "\\\""))\"; echo $? >> '\(path("done"))'")

            try await press()

            XCTAssertEqual(log("done"), ["0"], shell)
            XCTAssertEqual(tone, URL(fileURLWithPath: shell).lastPathComponent)
        }
    }

    func testACallOfASandboxedSpotStillReachesItsApp() async throws {
        try script(toml: "uses = ['spots']\n\(TestSpot.command)", "\(call("setting set tone careful")) 2> '\(path("errors"))'; echo $? >> '\(path("done"))'")

        try await press()

        XCTAssertEqual(log("done"), ["0"], log("errors").joined(separator: "\n"))
        XCTAssertEqual(tone, "careful")
    }

    func testAProcessOutsideTheRunWithTheRunsWholeEnvironmentIsNotTheSpot() async throws {
        let socket = try XCTUnwrap(CommandSocket(folder: config, api: try XCTUnwrap(runs.api)))
        defer { socket.close() }
        try script(toml: TestSpot.command, "env > '\(path("env"))'; echo 0 >> '\(path("done"))'; \(untilRelease)")
        _ = try scanned()
        try XCTUnwrap(runs.sheets["script"]).pressCard()
        try await wait("the environment of the run") { self.log("done").count == 1 }
        var environment = Dictionary(uniqueKeysWithValues: log("env").compactMap { line -> (String, String)? in
            guard let equals = line.firstIndex(of: "=") else { return nil }
            return (String(line[..<equals]), String(line[line.index(after: equals)...]))
        })
        environment["OPENSPOT_CONFIG"] = config.path

        let outside = Process()
        outside.executableURL = client
        outside.arguments = ["setting", "set", "tone", "stolen"]
        outside.environment = environment
        outside.standardOutput = FileHandle.nullDevice
        outside.standardError = FileHandle.nullDevice
        try outside.run()
        try await wait("the end of the outside call") { !outside.isRunning }
        openGate()
        try await allEnded()

        XCTAssertNotEqual(tone, "stolen")
    }

    func testTheChannelEndsWithTheRun() async throws {
        try script(toml: TestSpot.command, "( \(untilRelease); \(call("setting set tone late")); echo $? >> '\(path("late"))' ) > /dev/null 2>&1 & echo 0 >> '\(path("done"))'")
        try await press()
        try await allEnded()

        openGate()

        try await wait("the late call") { self.log("late").count == 1 }
        XCTAssertNotEqual(log("late"), ["0"])
        XCTAssertNil(tone)
    }

    func testEachRunIsKnownAsItsOwnSpot() async throws {
        try script("one", toml: "[on]\n'panel.open' = true", "\(call("setting set tone one")); echo 0 >> '\(path("done"))'")
        try script("two", toml: "[on]\n'panel.open' = true", "\(call("setting set tone two")); echo 0 >> '\(path("done"))'")
        _ = try scanned()

        runs.panelOpened()

        try await wait("both calls") { self.log("done").count == 2 }
        let kept = ConfigFile(url: config.appendingPathComponent("config.toml")).read()
        XCTAssertEqual(kept.setting("tone", of: "one"), "one")
        XCTAssertEqual(kept.setting("tone", of: "two"), "two")
    }

    func testAStayingSpotIsKnownInEachCall() async throws {
        try script(toml: "stay = true", """
        while IFS= read -r line; do
          case "$line" in call=*) call=${line#call=} ;; esac
          [ -n "$line" ] || { \(call("setting set tone stay$call")); printf 'end=%s\\n\\nitem=a\\n---\\n' "$call"; }
        done
        """)
        let sheet = try sheet()
        runs.panelOpened()

        sheet.open {}

        try await wait("the first frame") { !sheet.rows.all.isEmpty }
        XCTAssertEqual(tone?.hasPrefix("stay"), true)
    }

    func testAnInlineCallIsKnownAsItsSpot() async throws {
        let script = folder.spotFile("script", extension: "js")
        try FileManager.default.createDirectory(at: script.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "export default { async show(input, env) { openspot.call(['setting', 'set', 'tone', 'inline']); return 'text=t\\ntitle=done\\n' } }\n"
            .writeInline(to: script, toml: "")
        let sheet = try sheet()
        runs.panelOpened()

        sheet.open {}

        try await wait("the frame") { sheet.reading.value?.title == "done" }
        XCTAssertEqual(tone, "inline")
    }

    func testAnInlineCallThatRunsInAProcessOfItsOwnIsStillItsSpot() async throws {
        runs.quit()
        let home = try XCTUnwrap(ProcessInfo.processInfo.environment["HOME"], "the test scheme gives a private home")
        let outside = URL(fileURLWithPath: home, isDirectory: true).appendingPathComponent("rc-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }
        let products = Bundle(for: Self.self).bundleURL.deletingLastPathComponent().path
        runs = runs(environment: ["PATH": "\(products):/usr/bin:/bin", "HOME": home, "OPENSPOT_CONFIG": config.path])
        runs.api = CommandAPI(mac: Mac(), places: .test(["OPENSPOT_CONFIG": config.path]), app: FakeRunningApp(), runs: runs)
        let socket = try XCTUnwrap(CommandSocket(folder: config, api: try XCTUnwrap(runs.api)))
        defer { socket.close() }
        try script("writer", toml: "uses = ['files']", "echo a > '\(outside.path)/'\"$1\"")
        let script = folder.spotFile("script", extension: "js")
        try FileManager.default.createDirectory(at: script.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "export default { async show(input, env) { openspot.call(['spot', 'run', 'writer', 'inline']); return 'text=t\\ntitle=done\\n' } }\n"
            .writeInline(to: script, toml: "uses = ['spots']")
        let sheet = try sheet()
        runs.panelOpened()

        sheet.open {}

        try await wait("the frame") { sheet.reading.value?.title == "done" }
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside.appendingPathComponent("inline").path))
    }

    func testACallThatTheRunSendsAsItEndsStillReachesItsAppAsTheSpot() async throws {
        let socket = try XCTUnwrap(CommandSocket(folder: elsewhere, api: try XCTUnwrap(runs.api)))
        defer { socket.close() }
        try script(toml: TestSpot.command, "( \(call("setting set tone late")); echo $? >> '\(path("done"))' ) > /dev/null 2>&1 &")

        _ = try scanned()
        try XCTUnwrap(runs.sheets["script"]).pressCard()

        try await wait("the late call") { self.log("done").count == 1 }
        XCTAssertEqual(log("done"), ["0"])
        XCTAssertEqual(tone, "late")
    }

    func testABurstOfCallsFromOneRunAllReachItsApp() async throws {
        try script(toml: TestSpot.command, "for i in $(seq 64); do ( \(call("setting set tone burst")) 2>> '\(path("errors"))'; echo $? >> '\(path("codes"))' ) & done; wait; echo 0 >> '\(path("done"))'")

        try await press()

        XCTAssertEqual(log("codes").count, 64)
        XCTAssertEqual(Set(log("codes")), ["0"], log("errors").joined(separator: "\n"))
    }

    func testExtraDescriptorsSentOnTheChannelAreClosed() async throws {
        let caller = runs.callers.issue(for: Spot(id: "script", name: "Script", url: folder.appendingPathComponent("script.sh")))
        let channel = try XCTUnwrap(runs.callers.channel(for: caller))
        defer { runs.callers.release(caller) }
        let before = try FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count
        for _ in 0..<20 {
            var pair: [Int32] = [-1, -1]
            XCTAssertEqual(socketpair(AF_UNIX, SOCK_STREAM, 0, &pair), 0)
            XCTAssertTrue(Self.send([pair[1], pair[1], pair[1]], over: try XCTUnwrap(channel.childEnd)))
            Darwin.close(pair[0])
            Darwin.close(pair[1])
        }

        try await wait("the extra descriptors to close") { ((try? FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count) ?? .max) <= before }
    }

    func testAnotherDatagramSocketAtTheChannelsNumberIsNotTrusted() async throws {
        let socket = try XCTUnwrap(CommandSocket(folder: config, api: try XCTUnwrap(runs.api)))
        defer { socket.close() }
        var foreign: [Int32] = [-1, -1]
        XCTAssertEqual(socketpair(AF_UNIX, SOCK_DGRAM, 0, &foreign), 0)
        defer { foreign.forEach { Darwin.close($0) } }
        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_adddup2(&actions, foreign[1], 11)
        posix_spawn_file_actions_addopen(&actions, 1, "/dev/null", O_WRONLY, 0)
        posix_spawn_file_actions_addopen(&actions, 2, "/dev/null", O_WRONLY, 0)
        let words = [client.path, "setting", "set", "--spot", "home/tea", "tone", "warm"].map { (text: String) -> UnsafeMutablePointer<CChar>? in strdup(text) } + [nil]
        let pairs = ["OPENSPOT_CONFIG=\(config.path)", "PATH=/usr/bin:/bin", "OPENSPOT_START_WAIT=0.5"].map { (text: String) -> UnsafeMutablePointer<CChar>? in strdup(text) } + [nil]
        defer { (words + pairs).forEach { free($0) } }
        var started: pid_t = 0
        XCTAssertEqual(posix_spawn(&started, client.path, &actions, nil, words, pairs), 0)
        var status: Int32 = 0

        try await wait("the end of the call", seconds: 20) { waitpid(started, &status, WNOHANG) == started }

        XCTAssertEqual(status, 0)
        XCTAssertEqual(ConfigFile(url: config.appendingPathComponent("config.toml")).read().setting("tone", of: "home/tea"), "warm")
    }

    private static func send(_ descriptors: [Int32], over socket: Int32) -> Bool {
        let header = (MemoryLayout<cmsghdr>.size + 3) & ~3
        let length = header + descriptors.count * MemoryLayout<Int32>.size
        var control = [UInt8](repeating: 0, count: length)
        control.withUnsafeMutableBytes { bytes in
            bytes.baseAddress!.assumingMemoryBound(to: cmsghdr.self).pointee = cmsghdr(cmsg_len: socklen_t(length), cmsg_level: SOL_SOCKET, cmsg_type: SCM_RIGHTS)
            for (index, descriptor) in descriptors.enumerated() {
                bytes.storeBytes(of: descriptor, toByteOffset: header + index * MemoryLayout<Int32>.size, as: Int32.self)
            }
        }
        var byte: UInt8 = 0
        return withUnsafeMutablePointer(to: &byte) { pointer in
            var vector = iovec(iov_base: pointer, iov_len: 1)
            return control.withUnsafeMutableBytes { bytes in
                withUnsafeMutablePointer(to: &vector) { vectors in
                    var message = msghdr(msg_name: nil, msg_namelen: 0, msg_iov: vectors, msg_iovlen: 1, msg_control: bytes.baseAddress, msg_controllen: socklen_t(length), msg_flags: 0)
                    return sendmsg(socket, &message, 0) == 1
                }
            }
        }
    }
}
