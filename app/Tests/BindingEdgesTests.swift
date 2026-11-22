import XCTest
@testable import OpenspotCore

@MainActor
final class BindingEdgesTests: SpotRunsCase {
    private var client: URL!

    override func setUp() async throws {
        try await super.setUp()
        client = folder.appendingPathComponent("A.app/Contents/Helpers/openspot")
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: client)
        takeCalls()
    }

    private func shortLimit() {
        runs.quit()
        runs = SpotRuns(environment: ProcessInfo.processInfo.environment, showLimit: 0.5, clock: clock.value, stopPause: 0.2)
        takeCalls()
    }

    private func picker() throws {
        try script("picker", toml: "[actions.pick]\ninputs.when = 'text'\noutputs.until = 'text'\n[actions.choose]\noutputs.until = 'text'", log: "picker-log", """
        case "$1" in
          pick) w=$(sed -n 's/^input.when=//p'); printf 'out.until=%s-later\\n' "$w" ;;
          choose) printf 'frame=\\n\\ntext=morning\\ntitle=Morning\\n' ;;
        esac
        """)
    }

    func testAnActionThatWouldPushAViewFromAHandlerThePersonDidNotPressExits2() async throws {
        try picker()
        try script("bell", toml: "\(TestSpot.command)\n[events.rang]", log: "bell-log", "'\(client.path)' emit rang")
        try script("asker", toml: "[bindings]\npicker = { spot = 'picker' }\nbell = { spot = 'bell' }\n[on]\n\"bell.rang\" = true", log: "asker-log", """
        '\(client.path)' run picker.choose 2> '\(path("errors"))'; echo $? >> '\(path("done"))'
        """)
        _ = try scanned()

        try XCTUnwrap(runs.sheets["bell"]).pressCard()

        try await wait("the end of the run") { self.log("done").count == 1 }
        XCTAssertEqual(log("done"), ["2"])
        XCTAssertEqual(log("errors"), ["picker.choose answers with a view, which needs the person, and Asker runs bell.rang with no press. Show a toast or open a float instead."])
    }

    func testARunToASpotThatIsAlreadyInItsChainExits2AndNamesTheChain() async throws {
        try script("asker", toml: "\(TestSpot.command)\n[bindings]\npicker = { spot = 'picker' }\n[actions.back]\noutputs.v = 'text'", log: "asker-log", """
        case "$1" in
          back) echo out.v=1 ;;
          *) '\(client.path)' run picker.pick > /dev/null 2>&1; echo $? >> '\(path("done"))' ;;
        esac
        """)
        try script("picker", toml: "[bindings]\nasker = { spot = 'asker' }\n[actions.pick]", log: "picker-log", """
        '\(client.path)' run asker.back 2> '\(path("errors"))'; echo $? >> '\(path("inner"))'
        """)
        _ = try scanned()

        try XCTUnwrap(runs.sheets["asker"]).pressCard()

        try await wait("the end of the run") { self.log("done").count == 1 }
        XCTAssertEqual(log("inner"), ["2"])
        XCTAssertEqual(log("errors"), ["asker.back would run asker again in the chain asker → picker → asker, so Openspot did not run it."])
        XCTAssertEqual(log("asker-log").filter { $0 == "back" }, [])
    }

    func testAChainDeeperThanFourRunsExits2() async throws {
        for index in 1...6 {
            try script("s\(index)", toml: "\(index == 1 ? "[actions.start]\ntitle = 'Start'" : "")\n[bindings]\nnext = { spot = 's\(index + 1)' }\n[actions.go]", log: "s\(index)-log", """
            '\(client.path)' run next.go 2>> '\(path("errors"))'; echo "s\(index) $?" >> '\(path("codes"))'
            """)
        }
        _ = try scanned()

        try XCTUnwrap(runs.sheets["s1"]).pressCard()

        try await wait("the end of the chain") { self.log("codes").count == 5 }
        XCTAssertEqual(log("codes"), ["s5 2", "s4 0", "s3 0", "s2 0", "s1 0"])
        XCTAssertEqual(log("errors"), ["next.go would make the chain s1 → s2 → s3 → s4 → s5 → s6 deeper than 4 runs, so Openspot did not run it."])
        XCTAssertEqual(log("s6-log"), [])
    }

    func testAStayingSpotThatWaitsInARunTakesNoOtherCallAndKeepsItsLastAnswer() async throws {
        shortLimit()
        try script("picker", toml: "[actions.slow]\noutputs.v = 'text'", log: "picker-log", "[ \"$1\" = slow ] && { \(untilRelease); echo out.v=1; }")
        try script("asker", toml: "stay = true\n[on]\nsearch = '.'\n[actions.go]\n[bindings]\npicker = { spot = 'picker' }", log: "asker-log", """
        while IFS= read -r line; do
          printf '%s\\n' "$line" >> '\(path("blocks"))'
          case "$line" in call=*) call=${line#call=} ;; arg=*) arg=${line#arg=} ;; esac
          [ -n "$line" ] && continue
          case "$arg" in
            go) '\(client.path)' run picker.slow > /dev/null 2>> '\(path("errors"))'; echo $? >> '\(path("done"))'; printf 'end=%s\\n\\n---\\n' "$call" ;;
            search) printf 'end=%s\\n\\ntext=a\\ntitle=Answer\\n---\\n' "$call" ;;
            *) printf 'end=%s\\n\\ntext=s\\ntitle=S\\n---\\n' "$call" ;;
          esac
        done
        """)
        let sheet = try sheet("asker")
        runs.panelOpened()
        sheet.answer("x")
        try await wait("the first answer") { sheet.answers.map(\.title) == ["Answer"] }

        sheet.pressKey("go")
        try await wait("the wait in the run") { self.log("picker-log") == ["slow"] }
        sheet.answer("y")
        try await pause(1)

        XCTAssertEqual(sheet.answers.map(\.title), ["Answer"])
        XCTAssertFalse(sheet.isAnswering)
        openGate()
        try await wait("the end of the run") { self.log("done").count == 1 }
        XCTAssertEqual(log("done"), ["0"], log("errors").joined(separator: "\n"))
        XCTAssertFalse(log("blocks").contains("input.text=y"))
    }

    func testSpotRunCallsOneHandlerWithItsInputsAndItsBindingsLive() async throws {
        try picker()
        try script("asker", toml: "[actions.go]\ninputs.when = 'text'\noutputs.said = 'text'\n[bindings]\npicker = { spot = 'picker' }", log: "asker-log", """
        w=$(sed -n 's/^input.when=//p')
        printf 'out.said=%s\\n' "$('\(client.path)' run picker.pick when="$w" --out until)"
        """)
        _ = try scanned()
        let api = CommandAPI(mac: Mac(), places: .test(["OPENSPOT_CONFIG": folder.path, "OPENSPOT_SPOTS": folder.path]), app: FakeRunningApp(), runs: runs, rates: .offline)
        runs.api = api

        let work = try XCTUnwrap(api.work(for: CommandRequest(arguments: ["spot", "run", "asker", "go", "when=now"], folder: folder.path), input: { "" }))
        let answer = await work()

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(answer.output, "out.said=now-later\n")
        let refused = try XCTUnwrap(api.work(for: CommandRequest(arguments: ["spot", "run", "asker", "go", "count=3"], folder: folder.path), input: { "" }))
        let wrong = await refused()
        XCTAssertEqual(wrong.code, 2)
        XCTAssertEqual(wrong.errors, "go has no input count. Its inputs are: when.\n")
    }

    func testSpotRunSendsTheSettingsOfTheSpotAsACallFromThePanelDoes() async throws {
        try script("noter", toml: "[settings]\ntone = { type = 'text', default = 'soft' }\nsize = 'number'\n[actions.go]", log: "noter-log", """
        grep '^setting\\.' >> '\(path("settings"))' || true
        """)
        _ = try scanned()
        let places = AppPlaces.test(["OPENSPOT_CONFIG": folder.path, "OPENSPOT_SPOTS": folder.path])
        _ = try places.config.change { $0.set(setting: "size", of: "noter", to: "3") }
        let api = CommandAPI(mac: Mac(), places: places, app: FakeRunningApp(), runs: runs, rates: .offline)
        runs.api = api

        let work = try XCTUnwrap(api.work(for: CommandRequest(arguments: ["spot", "run", "noter", "go"], folder: folder.path), input: { "" }))
        let answer = await work()

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(log("settings"), ["setting.tone=soft", "setting.size=3"])
    }

    func testASwiftSpotRunsABoundSpotThroughPosixSpawn() async throws {
        try picker()
        let source = folder.appendingPathComponent("asker.swift")
        try """
        import Darwin

        var input = ""
        while let line = readLine() { input += line + "\\n" }
        guard CommandLine.arguments.count > 1, CommandLine.arguments[1] == "go" else { exit(0) }
        let when = input.split(separator: "\\n").first { $0.hasPrefix("input.when=") }.map { String($0.dropFirst(11)) } ?? ""
        var pipe: [Int32] = [0, 0]
        _ = Darwin.pipe(&pipe)
        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        posix_spawn_file_actions_adddup2(&actions, pipe[1], 1)
        posix_spawn_file_actions_addclose(&actions, pipe[0])
        let words = ["\(client.path)", "run", "picker.pick", "when=\\(when)", "--out", "until"]
        let argv = words.map { strdup($0) } + [nil]
        var child: pid_t = 0
        guard posix_spawn(&child, words[0], &actions, nil, argv, environ) == 0 else { exit(1) }
        close(pipe[1])
        var bytes: [UInt8] = []
        var buffer = [UInt8](repeating: 0, count: 4096)
        while case let count = read(pipe[0], &buffer, buffer.count), count > 0 { bytes += buffer[..<count] }
        var status: Int32 = 0
        waitpid(child, &status, 0)
        let said = String(decoding: bytes, as: UTF8.self).split(separator: "\\n").first.map(String.init) ?? ""
        print("out.said=\\(said)")
        """.write(to: source, atomically: true, encoding: .utf8)
        let program = folder.appendingPathComponent("asker.spot/asker")
        try FileManager.default.createDirectory(at: program.deletingLastPathComponent(), withIntermediateDirectories: true)
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/swiftc"), arguments: ["-Onone", source.path, "-o", program.path], limit: 300, base: TestEnvironment.values)
        try "[actions.go]\ninputs.when = 'text'\noutputs.said = 'text'\n[bindings]\npicker = { spot = 'picker' }\n".write(to: program.deletingLastPathComponent().appendingPathComponent(Manifest.fileName), atomically: true, encoding: .utf8)
        _ = try scanned()

        let said = try await XCTUnwrap(runs.sheets["asker"]).call("go", inputs: [.init(key: "when", value: "now")])

        XCTAssertEqual(said, [.init(key: "said", value: "now-later")])
    }
}
