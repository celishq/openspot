import XCTest
@testable import OpenspotCore

/// Proves that each call that the running app now answers gives the same stdout, stderr and exit code through the socket
/// of the app as through the Core work of a process of its own, so that the router picks only the transport (S1, S2). A
/// fake Mac stands in for the clipboard, the windows, the screen, translation and the picks.
final class CallRouteTests: XCTestCase {
    /// A Mac that answers each call of the clipboard, the windows, the screen, translation and the picks the same way.
    private final class Host: Mac, @unchecked Sendable {
        func eventStore() -> any EventStore { FakeEventStore() }
        func reminderStore() -> any ReminderStore { FakeReminderStore() }
        func showCalendar(at time: Date) throws {}
        func open(_ link: URL) -> Bool { true }
        func copy(text: String) throws {}
        func copy(file: URL) throws { throw SpotError.fault("Openspot cannot copy \(file.lastPathComponent).") }
        func clipboardText() -> String { "kept text" }
        func paste() throws {}
        func windowFrame() async throws -> String { "10 20 300 400 0 33 1728 1084\n" }
        func moveWindow(_ move: WindowMove) async throws {}
        func screenSources() async -> String { "row=display:1\n" }
        func screenShot(_ capture: ScreenCapture, in folder: URL) async throws -> String { "\(folder.appendingPathComponent(capture.file ?? "shot.png").path)\n" }
        func startRecording(_ capture: ScreenCapture, in folder: URL) async throws -> String { "" }
        func stopRecording() async throws -> String { "/shots/a.mp4\n" }
        func recordingStatus() async throws -> String { "state=idle\n" }
        func translate(_ text: String, from: String?, to: String?) async throws -> String { "text=\(text.uppercased())\n" }
        func translationLanguages() async -> String { "preferred=en\n" }
        func pickColor() async -> String { "#FF8800\n" }
        func pickFolder() async -> String { "/Users/a/Repos\n" }
    }

    /// What a call printed and its exit code.
    private struct Answer: Equatable {
        let stdout: String
        let stderr: String
        let code: Int
    }

    private var folder: URL!
    private var socket: CommandSocket?
    private let host = Host()

    private var config: URL { folder.appendingPathComponent("config", isDirectory: true) }
    private var plugins: URL { config.appendingPathComponent("plugins", isDirectory: true) }
    private var variables: [String: String] { ["OPENSPOT_CONFIG": config.path, "OPENSPOT_PLUGINS": plugins.path, "TONE": "warm"] }

    override func setUp() async throws {
        let temp = try XCTUnwrap(realpath(FileManager.default.temporaryDirectory.path, nil))
        defer { free(temp) }
        folder = URL(fileURLWithPath: String(cString: temp), isDirectory: true).appendingPathComponent("cr-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        let runs = await SpotRuns()
        socket = CommandSocket(folder: folder, api: CommandAPI(mac: host, app: FakeRunningApp(), runs: runs))
    }

    override func tearDown() async throws {
        socket?.close()
        try? FileManager.default.removeItem(at: folder)
    }

    /// The answer of the work that a process of its own runs, with the variables and the working folder of the caller.
    private func alone(_ argv: [String], input: String?) async throws -> Answer {
        let environment = ProcessInfo.processInfo.environment.merging(variables) { _, new in new }.merging(["PWD": folder.path]) { _, new in new }
        let call = try XCTUnwrap(CommandLineCall(arguments: argv, environment: environment))
        let printed = Printed()
        let output = CommandOutput { text, isError in printed.add(text, isError: isError) }
        let work = try XCTUnwrap(CommandAPI(mac: host).work(for: call, input: { input ?? "" }, environment: environment, isPiped: input != nil, output: output))
        let answer = await work()
        output.print(answer.output)
        output.report(answer.errors)
        return Answer(stdout: printed.stdout, stderr: printed.stderr, code: Int(answer.code))
    }

    /// The answer of the app through its socket.
    private func app(_ argv: [String], input: String?) throws -> Answer {
        let connection = SocketConnection(path: folder.appendingPathComponent(CommandSocket.name).path)
        defer { connection.close() }
        try connection.send(["jsonrpc": "2.0", "id": 1, "method": "ask", "params": ["argv": argv, "cwd": folder.path, "env": variables, "piped": input != nil]])
        let exchange = try connection.exchange(input: input.map { [$0] } ?? [])
        return Answer(stdout: exchange.stdout, stderr: exchange.stderr, code: exchange.code ?? -1)
    }

    func testEachCallThatTheAppAnswersGivesTheSameAnswerAlone() async throws {
        try "#!/bin/sh\n# size=huge\necho\n".writeScript(to: plugins.appendingPathComponent("weather.sh"))
        try "#!/bin/sh\n# on=sheet.open\nprintf 'title=Notes\\n'\n".writeScript(to: plugins.appendingPathComponent("notes.sh"))
        try "#!/bin/sh\nprintf 'args=%s\\nfolder=%s\\ntone=%s\\n---\\n' \"$*\" \"$PWD\" \"$TONE\"; cat; echo 'said' >&2; exit 3\n".writeScript(to: plugins.appendingPathComponent("echo.sh"))
        let calls: [([String], String?)] = [
            (["check"], nil),
            (["check", "--json"], nil),
            (["check", "config/plugins"], nil),
            (["check", "--sheet"], "title=Hi\n"),
            (["spot", "run", "echo", "open", "home"], "note=hi\n"),
            (["spot", "run", "echo"], nil),
            (["spot", "run", "gone"], nil),
            (["clipboard", "copy"], "words"),
            (["clipboard", "copy", "missing.png"], nil),
            (["clipboard", "read"], nil),
            (["clipboard", "paste"], nil),
            (["window", "frame"], nil),
            (["window", "move", "0 0 1/2 1"], nil),
            (["screen", "sources"], nil),
            (["screen", "shot", "a.png"], nil),
            (["screen", "record", "start"], nil),
            (["screen", "record", "status"], nil),
            (["screen", "record", "stop"], nil),
            (["translate"], "hello"),
            (["translate", "languages"], nil),
            (["color", "pick"], nil),
            (["folder", "pick"], nil)
        ]

        for (argv, input) in calls {
            let alone = try await alone(argv, input: input)
            let app = try app(argv, input: input)

            XCTAssertEqual(app, alone, argv.joined(separator: " "))
        }
    }
}

/// What a call printed, which the thread of each print adds to.
private final class Printed: @unchecked Sendable {
    private let lock = NSLock()
    private var output = ""
    private var errors = ""

    var stdout: String { lock.withLock { output } }
    var stderr: String { lock.withLock { errors } }

    func add(_ text: String, isError: Bool) {
        lock.withLock {
            if isError { errors += text } else { output += text }
        }
    }
}
