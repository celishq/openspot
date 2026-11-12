import XCTest
@testable import OpenspotCore

/// Proves that a spot's call of a use that its header does not name still runs, and shows one toast for each spot, use
/// and day, while a named use and the person's call show none (protocol: Trust).
@MainActor
final class SpotUsesTests: SpotRunsCase {
    private final class NoHost: Mac {
        func eventStore() -> any EventStore { FakeEventStore() }
        func reminderStore() -> any ReminderStore { FakeReminderStore() }
        func showCalendar(at time: Date) throws {}
        func open(_ link: URL) -> Bool { false }
    }

    private var config: URL!
    private var client: URL!
    private var socket: CommandSocket?
    private var toasts: [String] = []

    override func setUp() async throws {
        try await super.setUp()
        config = FileManager.default.temporaryDirectory.appendingPathComponent("ou-\(UUID().uuidString.prefix(8))", isDirectory: true)
        client = folder.appendingPathComponent("A.app/Contents/Helpers/openspot")
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: client)
        let api = CommandAPI(mac: NoHost(), runs: runs)
        runs.api = api
        socket = try XCTUnwrap(CommandSocket(folder: config, api: api))
        runs.onReport = { [unowned self] _, report in
            if case .toast(let text) = report { toasts.append(text) }
        }
    }

    override func tearDown() async throws {
        socket?.close()
        try? FileManager.default.removeItem(at: config)
        try await super.tearDown()
    }

    /// A spot that lists the settings of each spot once for each press, with these header lines.
    private func lister(header: String = "") throws {
        try script(header: header, "OPENSPOT_CONFIG='\(config.path)' '\(client.path)' setting list > /dev/null && echo done >> '\(path("done"))'")
    }

    private func press() async throws {
        let count = log("done").count
        let sheet = try XCTUnwrap(runs.sheets["script"])
        sheet.pressCard()
        try await wait("the call") { self.log("done").count == count + 1 }
        try await allEnded()
        try await wait("the end of the call in the sheet") { sheet.calls.isEmpty }
    }

    func testAnUndeclaredUseRunsAndShowsOneToastADay() async throws {
        try lister()
        _ = try scanned()

        try await press()
        try await wait("the toast") { !self.toasts.isEmpty }
        try await press()
        try await pause()

        XCTAssertEqual(toasts, ["Script read the settings of each spot without `uses=spots` in its header. Add it to stop this note."])
        time += 24 * 60 * 60
        try await press()
        try await wait("the toast of the next day") { self.toasts.count == 2 }
    }

    func testADeclaredUseShowsNoToast() async throws {
        try lister(header: "uses=spots")
        _ = try scanned()

        try await press()
        try await pause()

        XCTAssertEqual(toasts, [])
    }

    func testThePersonsCallShowsNoToast() async throws {
        _ = try scanned()
        let shell = Process()
        shell.executableURL = client
        shell.arguments = ["setting", "list"]
        shell.environment = ["OPENSPOT_CONFIG": config.path, "PATH": "/usr/bin:/bin"]
        shell.standardOutput = FileHandle.nullDevice

        try shell.run()
        try await wait("the end of the call") { !shell.isRunning }
        try await pause()

        XCTAssertEqual(toasts, [])
    }

    /// A spot that runs the client with these words, and writes its code and its stderr.
    private func caller(header: String = "", _ words: String) throws {
        try script(header: header, "OPENSPOT_CONFIG='\(config.path)' '\(client.path)' \(words) > /dev/null 2> '\(path("errors"))'; echo $? >> '\(path("done"))'")
    }

    private func pressed() async throws -> (code: String, errors: String) {
        try await press()
        return (log("done").last ?? "", (try? String(contentsOfFile: path("errors"), encoding: .utf8)) ?? "")
    }

    func testASpotCannotChangeCarefulMode() async throws {
        try caller(header: "uses=app", "setting set --spot openspot careful false")
        _ = try scanned()

        let (code, errors) = try await pressed()

        XCTAssertEqual(code, "1")
        XCTAssertEqual(errors, "Script cannot change Careful mode. Only you can, in Settings or with `openspot setting set --spot openspot careful true` in Terminal.\n")
        XCTAssertFalse(FileManager.default.fileExists(atPath: config.appendingPathComponent("config.toml").path))
    }

    func testInCarefulModeAnUndeclaredUseIsRefused() async throws {
        runs.isCareful = true
        try caller("setting list")
        _ = try scanned()

        let (code, errors) = try await pressed()

        XCTAssertEqual(code, "1")
        XCTAssertEqual(errors, "Careful mode stopped Script, because it read the settings of each spot without `uses=spots` in its header. Add it, or turn Careful mode off.\n")
        XCTAssertEqual(toasts, [])
    }

    func testInCarefulModeASandboxedProcessOutsideEachSpotCannotChangeCarefulModeOrUseAnything() async throws {
        runs.isCareful = true
        _ = try scanned()
        let errors = folder.appendingPathComponent("errors")
        FileManager.default.createFile(atPath: errors.path, contents: nil)
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/usr/bin/sandbox-exec")
        shell.arguments = ["-p", "(version 1)(allow default)", client.path, "setting", "set", "--spot", "openspot", "careful", "false"]
        shell.environment = ["OPENSPOT_CONFIG": config.path, "PATH": "/usr/bin:/bin"]
        shell.standardOutput = FileHandle.nullDevice
        shell.standardError = try FileHandle(forWritingTo: errors)

        try shell.run()
        try await wait("the end of the call") { !shell.isRunning }

        XCTAssertEqual(shell.terminationStatus, 1)
        XCTAssertEqual(try String(contentsOf: errors, encoding: .utf8), "A sandboxed process cannot change Careful mode. Only you can, in Settings or with `openspot setting set --spot openspot careful true` in Terminal.\n")
        XCTAssertFalse(FileManager.default.fileExists(atPath: config.appendingPathComponent("config.toml").path))
    }

    func testInCarefulModeADeclaredUseRuns() async throws {
        runs.isCareful = true
        try caller(header: "uses=spots", "setting list")
        _ = try scanned()

        let (code, _) = try await pressed()

        XCTAssertEqual(code, "0")
    }

    func testASpotThatDropsItsTokenIsStillKnownByItsProcessGroup() async throws {
        try script(header: "", "OPENSPOT_CONFIG='\(config.path)' /usr/bin/env -u OPENSPOT_TOKEN '\(client.path)' setting list > /dev/null && echo done >> '\(path("done"))'")
        _ = try scanned()

        try await press()

        try await wait("the toast") { !self.toasts.isEmpty }
        XCTAssertEqual(toasts, ["Script read the settings of each spot without `uses=spots` in its header. Add it to stop this note."])
    }

    func testAChildThatOutlivesItsSpotsProcessIsStillTheSpot() async throws {
        try script(header: "", "( \(untilRelease); OPENSPOT_CONFIG='\(config.path)' /usr/bin/env -u OPENSPOT_TOKEN '\(client.path)' setting list > /dev/null; echo done >> '\(path("done"))' ) > /dev/null 2>&1 &")
        _ = try scanned()
        try XCTUnwrap(runs.sheets["script"]).pressCard()
        try await wait("the start of the call") { self.log().count == 1 }
        try await allEnded()

        openGate()

        try await wait("the call of the child") { self.log("done").count == 1 }
        try await wait("the toast") { !self.toasts.isEmpty }
    }

    func testAReadIsKnownFromTheAppsRecordAndNotFromTheVariables() async throws {
        try script(header: "on=sheet.open", "OPENSPOT_CONFIG='\(config.path)' /usr/bin/env -u OPENSPOT_REASON '\(client.path)' spot remove other > /dev/null 2> '\(path("errors"))'; echo $? >> '\(path("done"))'")
        let sheet = try sheet()
        runs.panelOpened()

        sheet.open {}

        try await wait("the read") { self.log("done").count == 1 }
        XCTAssertEqual(try String(contentsOfFile: path("errors"), encoding: .utf8), "`openspot spot remove` changes your plugins folder, so it cannot run in a read. Run it from a pick or an action.\n")
    }

    func testAnUnknownUseRefusesThePlugin() throws {
        try script(header: "uses=camera")

        XCTAssertEqual(try SpotFolder(url: folder).scan().refused.map(\.reason), [
            "Script has an unknown use in its uses: camera. Use app, spots, screen, clipboard, calendar, network or files"
        ])
    }

    func testEachPowerCallNamesItsUse() {
        let cases: [([String], String?)] = [
            (["app", "quit"], "app"), (["setting", "set", "--spot", "openspot", "login", "true"], "app"), (["setting", "set", "--spot", "openspot", "panel-key", "cmd+k"], "app"),
            (["setting", "set", "--spot", "a", "menubar", "true"], "app"), (["update", "check"], "app"), (["spot", "add", "x"], "spots"),
            (["setting", "set", "--spot", "a", "enabled", "true"], "spots"), (["spot", "run", "a"], "spots"), (["spot", "log", "a"], "spots"),
            (["setting", "list"], "spots"), (["setting", "get", "--spot", "other", "k"], "spots"),
            (["setting", "get", "k"], nil), (["setting", "set", "k", "v"], nil), (["screen", "sources"], "screen"),
            (["window", "move", "0 0 1 1"], "screen"), (["clipboard", "copy"], "clipboard"), (["clipboard", "paste"], "clipboard"),
            (["clipboard", "read"], "clipboard"),
            (["calendar", "events"], "calendar"), (["reminders", "lists"], "calendar"), (["calc", "solve", "2+2"], nil),
            (["spot", "stats"], nil), (["spot", "list"], nil), (["event", "emit", "a.b"], nil)
        ]
        for (arguments, use) in cases {
            XCTAssertEqual(SpotUseCall(arguments: arguments, of: "own")?.use.rawValue, use, arguments.joined(separator: " "))
        }
        XCTAssertNil(SpotUseCall(arguments: ["setting", "get", "--spot", "record/inputs", "k"], of: "record"), "a script of the same folder is the same plugin")
        XCTAssertNotNil(SpotUseCall(arguments: ["setting", "get", "--spot", "notes", "k"], of: "record"))
    }
}
