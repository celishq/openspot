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
        runs.api = CommandAPI(mac: Mac(), places: .test(["OPENSPOT_CONFIG": config.path]), app: FakeRunningApp(), runs: runs, rates: .offline)
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
        try XCTUnwrap(runs.sheets["script"]).pressCard()
        try await wait("the end of the call") { self.log("done").count == 1 }
    }

    func testACallOfASpotReachesTheAppThatRanItWhateverItsConfigVariableNames() async throws {
        try script(header: "", "\(call("setting set tone warm")) 2> '\(path("errors"))'; echo $? >> '\(path("done"))'")

        try await press()

        XCTAssertEqual(log("done"), ["0"], log("errors").joined(separator: "\n"))
        XCTAssertEqual(tone, "warm")
    }

    func testTwoCallsAtOnceInOneRunEachGetTheirOwnAnswer() async throws {
        try script(header: "", "\(call("calc solve 1+1")) > '\(path("one"))' & \(call("calc solve 20+22")) > '\(path("two"))'; wait; echo 0 >> '\(path("done"))'")

        try await press()

        XCTAssertTrue(log("one").contains("title=2"), log("one").joined(separator: "\n"))
        XCTAssertTrue(log("two").contains("title=42"), log("two").joined(separator: "\n"))
    }

    func testEachShellPassesTheChannelOnToItsChildren() async throws {
        for shell in ["/bin/bash", "/bin/zsh", "/bin/sh"] {
            try? FileManager.default.removeItem(atPath: path("done"))
            try? FileManager.default.removeItem(at: config.appendingPathComponent("config.toml"))
            try script(header: "", "\(shell) -c \"\(call("setting set tone \(URL(fileURLWithPath: shell).lastPathComponent)").replacingOccurrences(of: "\"", with: "\\\""))\"; echo $? >> '\(path("done"))'")

            try await press()

            XCTAssertEqual(log("done"), ["0"], shell)
            XCTAssertEqual(tone, URL(fileURLWithPath: shell).lastPathComponent)
        }
    }

    func testInCarefulModeACallOfASpotStillReachesItsApp() async throws {
        runs.isCareful = true
        try script(header: "uses=spots", "\(call("setting set tone careful")) 2> '\(path("errors"))'; echo $? >> '\(path("done"))'")

        try await press()

        XCTAssertEqual(log("done"), ["0"], log("errors").joined(separator: "\n"))
        XCTAssertEqual(tone, "careful")
    }

    func testAProcessOutsideTheRunWithTheRunsWholeEnvironmentIsNotTheSpot() async throws {
        let socket = try XCTUnwrap(CommandSocket(folder: config, api: try XCTUnwrap(runs.api)))
        defer { socket.close() }
        try script(header: "", "env > '\(path("env"))'; echo 0 >> '\(path("done"))'; \(untilRelease)")
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
        try script(header: "", "( \(untilRelease); \(call("setting set tone late")); echo $? >> '\(path("late"))' ) > /dev/null 2>&1 & echo 0 >> '\(path("done"))'")
        try await press()
        try await allEnded()

        openGate()

        try await wait("the late call") { self.log("late").count == 1 }
        XCTAssertNotEqual(log("late"), ["0"])
        XCTAssertNil(tone)
    }

    func testEachRunIsKnownAsItsOwnSpot() async throws {
        try script("one", header: "on=panel.open", "\(call("setting set tone one")); echo 0 >> '\(path("done"))'")
        try script("two", header: "on=panel.open", "\(call("setting set tone two")); echo 0 >> '\(path("done"))'")
        _ = try scanned()

        runs.panelOpened()

        try await wait("both calls") { self.log("done").count == 2 }
        let kept = ConfigFile(url: config.appendingPathComponent("config.toml")).read()
        XCTAssertEqual(kept.setting("tone", of: "one"), "one")
        XCTAssertEqual(kept.setting("tone", of: "two"), "two")
    }

    func testAStayingSpotIsKnownInEachCall() async throws {
        try script(header: "mode=stay\non=sheet.open\noffers=card\noffers=menubar", """
        while IFS= read -r line; do
          case "$line" in call=*) call=${line#call=} ;; esac
          [ -n "$line" ] || { \(call("setting set tone stay$call")); printf 'end=%s\\n\\nrow=a\\n---\\n' "$call"; }
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
        try "// on=sheet.open\nfunction main(args, env) { openspot.call(['setting', 'set', 'tone', 'inline']); return 'text=t\\ntitle=done\\n' }\n"
            .write(to: script, atomically: true, encoding: .utf8)
        let sheet = try sheet()
        runs.panelOpened()

        sheet.open {}

        try await wait("the frame") { sheet.reading.value?.title == "done" }
        XCTAssertEqual(tone, "inline")
    }
}
