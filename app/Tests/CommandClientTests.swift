import XCTest
@testable import OpenspotCore

final class CommandClientTests: XCTestCase {
    private struct SlowApp: RunningApp {
        let folder: URL

        func configChanged(_ change: ConfigChange, to config: KeptConfig) async {}
        func spotsChanged() async {}
        func status() async -> (update: String?, calls: Int, isFirstLaunch: Bool) { (nil, 0, false) }
        func checkUpdate() async -> Bool { true }
        func installUpdate() async -> Bool { true }
        func allows(_ reason: String) async -> Bool { false }
        func quit() async {}
        func apply(_ theme: Theme) async {}
        func open(_ id: String) async -> Bool { true }
        func push(_ id: String, page: String?, title: String?, replace: Bool) async -> Bool { true }
        func pop(_ id: String, all: Bool) async -> Bool { true }
        func review(_ id: String) async -> Bool { true }
        func act(_ act: CardAct, on id: String) async -> Bool { true }
        func choose(for id: String) async -> Bool { true }
        func editGrid() async {}
        func publish(_ id: String) async -> SpotPublish { .notOwn }
        func reveal(_ id: String) async -> Bool { true }
        func playground(_ file: URL?) async {}

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

    private var folder: URL!
    private var socket: CommandSocket?

    private var config: URL { folder.appendingPathComponent("config") }
    private var client: URL { folder.appendingPathComponent("A.app/Contents/Helpers/openspot") }

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("oc-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("A.app/Contents/MacOS"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        let built = Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot")
        try FileManager.default.copyItem(at: built, to: client)
        try "#!/bin/sh\necho \"app: $*\"\n".writeScript(to: folder.appendingPathComponent("A.app/Contents/MacOS/Openspot"))
    }

    override func tearDownWithError() throws {
        socket?.close()
        try? FileManager.default.removeItem(at: folder)
    }

    private func listen() {
        socket = CommandSocket(folder: config, api: CommandAPI(mac: Mac(), places: .test(["OPENSPOT_CONFIG": config.path]), rates: .offline))
    }

    private func run(_ program: URL, _ arguments: [String], input: String = "", variables: [String: String] = [:]) throws -> (output: String, errors: String, code: Int32) {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        let stdin = Pipe()
        process.executableURL = program
        process.arguments = arguments
        process.environment = ["OPENSPOT_CONFIG": config.path, "PATH": "/usr/bin:/bin"].merging(variables) { _, new in new }
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = stdin
        try process.run()
        stdin.fileHandleForWriting.write(Data(input.utf8))
        try stdin.fileHandleForWriting.close()
        let printed = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let said = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        return (printed, said, process.terminationStatus)
    }

    func testTheTokenOfACallerNamesItsSpotAndNoOtherVariableDoes() async throws {
        let runs = await SpotRuns()
        socket = CommandSocket(folder: config, api: CommandAPI(mac: Mac(), places: .test(["OPENSPOT_CONFIG": config.path]), runs: runs, rates: .offline))
        let token = runs.tokens.issue(for: Spot(id: "home/coffee", name: "Coffee", url: folder.appendingPathComponent("coffee.sh")))

        let named = try run(client, ["setting", "set", "tone", "warm"], variables: [CallerTokens.variable: token])
        let claimed = try run(client, ["setting", "set", "tone", "cold"], variables: ["OPENSPOT_ID": "home/tea"])

        XCTAssertEqual(named.code, 0, named.errors)
        XCTAssertNotEqual(claimed.code, 0)
        let kept = ConfigFile(url: config.appendingPathComponent("config.toml")).read()
        XCTAssertEqual(kept.setting("tone", of: "home/coffee"), "warm")
        XCTAssertNil(kept.setting("tone", of: "home/tea"))
    }

    func testAPersonInTerminalAndACopiedTokenOfABuiltInReachNoKey() async throws {
        let runs = await SpotRuns()
        let app = FakeRunningApp()
        socket = CommandSocket(folder: config, api: CommandAPI(mac: Mac(), places: .test(["OPENSPOT_CONFIG": config.path]), app: app, runs: runs, rates: .offline))
        let account = Spot(id: "openspot/account", name: "Account", url: folder.appendingPathComponent("account.sh"), uses: [.account]).builtIn()
        let copied = [CallerTokens.variable: runs.tokens.issue(for: account)]
        let refused = "Only Openspot's Store can reach your account key.\n"

        XCTAssertEqual(try run(client, ["store", "publish", "mine"]).errors, refused)
        XCTAssertEqual(try run(client, ["store", "publish", "mine"], variables: copied).errors, refused)
        for verb in ["new", "sign-out", "sync"] {
            XCTAssertEqual(try run(client, ["account", verb], variables: copied).code, 2, verb)
        }

        let opened = await app.opened
        XCTAssertEqual(opened, [])
        XCTAssertNil(try AccountStore.standard(environment: ["OPENSPOT_CONFIG": config.path], home: folder, devState: nil).key())
    }

    func testTheRunningAppAnswersACalcSum() throws {
        listen()

        let answer = try run(client, ["calc", "solve", "2+2"])

        XCTAssertEqual(TextBlock.blocks(in: answer.output).first?.value("title"), "4")
        XCTAssertEqual(answer.code, 0)
    }

    func testStdinStderrAndTheCodeComeThroughTheSocket() throws {
        listen()

        XCTAssertEqual(try run(client, ["check", "sheet"], input: "title=Hi\n").output, "the sheet has no parts\n1 faults.\n")
        XCTAssertEqual(try run(client, ["check", "sheet"], input: "title=Hi\n").code, 1)
        let unknown = try run(client, ["calc", "2+2"])
        XCTAssertTrue(unknown.errors.hasPrefix("openspot cannot do this: calc 2+2\n"))
        XCTAssertEqual(unknown.code, 2)
    }

    func testACallThatTakesNoStdinLeavesItForTheNextReader() throws {
        listen()
        let file = folder.appendingPathComponent("calls")
        try "call=next\n".write(to: file, atomically: true, encoding: .utf8)
        let stdin = try FileHandle(forReadingFrom: file)
        defer { try? stdin.close() }
        let process = Process()
        process.executableURL = client
        process.arguments = ["calc", "solve", "2+2"]
        process.environment = ["OPENSPOT_CONFIG": config.path, "PATH": "/usr/bin:/bin"]
        process.standardOutput = FileHandle.nullDevice
        process.standardInput = stdin
        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(try stdin.offset(), 0)
    }

    func testAPipedStdinThatComesInPartsReachesTheCall() throws {
        listen()
        let process = Process()
        let output = Pipe()
        let stdin = Pipe()
        process.executableURL = client
        process.arguments = ["check", "sheet"]
        process.environment = ["OPENSPOT_CONFIG": config.path, "PATH": "/usr/bin:/bin"]
        process.standardOutput = output
        process.standardInput = stdin
        try process.run()
        stdin.fileHandleForWriting.write(Data("title=Hi\n".utf8))
        stdin.fileHandleForWriting.write(Data("text=Привіт\n".utf8))
        try stdin.fileHandleForWriting.close()
        let printed = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()

        XCTAssertEqual(printed, "the sheet has no parts\nthe head has an unknown key: text\n2 faults.\n")
    }

    func testWithNoSocketItStartsTheAppWithTheSameArguments() throws {
        XCTAssertEqual(try run(client, ["guide"]).output, "app: guide\n")
    }

    func testWithNoWordsItAsksForHelp() throws {
        XCTAssertEqual(try run(client, []).output, "app: help\n")
    }

    func testACallThatRunsAloneStartsTheApp() throws {
        listen()

        XCTAssertEqual(try run(client, ["render", "sheet", "x.png"]).output, "app: render sheet x.png\n")
    }

    private func start(_ arguments: [String], variables: [String: String] = [:]) throws -> (process: Process, output: Pipe, errors: Pipe) {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = client
        process.arguments = arguments
        process.environment = ["OPENSPOT_CONFIG": config.path, "PATH": "/usr/bin:/bin"].merging(variables) { _, new in new }
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = FileHandle.nullDevice
        try process.run()
        return (process, output, errors)
    }

    private func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path)
    }

    func testALiveCallWithNoAppStartsItInTheBackgroundAndAsksItsSocket() async throws {
        try "#!/bin/sh\nif [ $# -gt 0 ]; then echo \"app: $*\"; else touch '\(folder.appendingPathComponent("started").path)'; fi\n".writeScript(to: folder.appendingPathComponent("A.app/Contents/MacOS/Openspot"))
        let run = try start(["app", "status"])

        try await wait("the start of the app") { exists("started") }
        listen()
        try await wait("the end of the call") { !run.process.isRunning }

        let printed = String(decoding: run.output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        XCTAssertTrue(printed.hasPrefix("version="), printed)
        XCTAssertEqual(run.process.terminationStatus, 0)
    }

    func testALiveCallFailsAndSaysSoWhenTheAppDoesNotStartInTime() async throws {
        let run = try start(["event", "emit", "music.track"], variables: ["OPENSPOT_START_WAIT": "0.3"])

        try await wait("the end of the call") { !run.process.isRunning }

        let said = String(decoding: run.errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        XCTAssertEqual(said, "Openspot did not start within 0.3 seconds, so this call did not run. Open Openspot, then run it again.\n")
        XCTAssertEqual(String(decoding: run.output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self), "")
        XCTAssertEqual(run.process.terminationStatus, 3)
    }

    func testAQuitOrTheStatsOfAClosedAppStartNoApp() async throws {
        for call in [["app", "quit"], ["spot", "stats"]] {
            let run = try start(call, variables: ["OPENSPOT_START_WAIT": "5"])

            try await wait("the end of the call") { !run.process.isRunning }

            XCTAssertEqual(String(decoding: run.output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self), "app: \(call.joined(separator: " "))\n")
        }
    }

    func testCtrlCStopsTheWorkOfTheCallInTheAppAndItChangesNothing() async throws {
        socket = CommandSocket(folder: config, api: CommandAPI(mac: Mac(), places: .test(["OPENSPOT_CONFIG": config.path]), app: SlowApp(folder: folder), rates: .offline))
        let run = try start(["setting", "change", "--spot", "repos", "folder"])
        try await wait("the start of the work") { exists("started") }

        run.process.interrupt()

        try await wait("the end of the work") { exists("ended") }
        try await wait("the end of the command") { !run.process.isRunning }
        XCTAssertFalse(exists("far"))
        XCTAssertEqual(run.process.terminationStatus, 130)
    }

    func testOnlyACallThatNeedsTheStateOfTheAppIsLive() {
        for live in [["app", "status"], ["spot", "open", "x"], ["setting", "change", "k"], ["event", "emit", "a.b"], ["update", "check"], ["batch"]] {
            XCTAssertTrue(CommandKind.needsApp(live), live.joined(separator: " "))
        }
        for files in [["spot", "list"], ["setting", "get", "k"], ["calc", "solve", "1"], ["setting", "set", "--spot", "openspot", "login", "true"], ["app", "quit"], ["spot", "stats"], ["guide"], ["screen", "shot"], []] {
            XCTAssertFalse(CommandKind.needsApp(files), files.joined(separator: " "))
        }
    }

    func testTheHelpFlagsOfTheClientAreThoseOfTheHelpNoun() {
        XCTAssertEqual(CommandKind.help, Set(HelpCall.noun.flags))
    }

    func testHelpOfALiveCallNeedsNoApp() {
        XCTAssertFalse(CommandKind.needsApp(["spot", "open", "--help"]))
        XCTAssertFalse(CommandKind.needsApp(["app", "status", "-h"]))
    }

    func testTheListsOfTheClientAreTheFlagsOfTheVerbTable() {
        var live: Set<String> = []
        var pure: Set<String> = []
        for noun in CommandNoun.all {
            for verb in noun.verbs {
                let words = [noun.name] + verb.words
                if verb.rule.flags.contains(.needsApp) { live.insert(words.joined(separator: " ")) }
                if verb.rule.flags.contains(.pure) { pure.insert(words.joined(separator: " ")) }
                XCTAssertEqual(CommandKind.needsApp(words + ["x"]), verb.rule.flags.contains(.needsApp), words.joined(separator: " "))
                XCTAssertEqual(CommandKind.isPure(words + ["x"]), verb.rule.flags.contains(.pure), words.joined(separator: " "))
            }
        }

        XCTAssertEqual(CommandKind.live, live)
        XCTAssertEqual(CommandKind.pure, pure)
    }

    func testAPureCallOpensNoSocketAndRunsInItsOwnProcess() throws {
        listen()

        for call in [["emoji", "list", "--tone", "dark"], ["symbols", "list"]] {
            XCTAssertEqual(try run(client, call).output, "app: \(call.joined(separator: " "))\n")
        }
    }

    func testThroughALinkItStartsTheAppOfItsResolvedPath() throws {
        let link = folder.appendingPathComponent("openspot")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: client)

        XCTAssertEqual(try run(link, ["spot", "new", "x"]).output, "app: spot new x\n")
    }
}
