import XCTest
@testable import OpenspotCore

final class CallRouteTests: XCTestCase {
    private struct Clipboard: MacClipboard {
        func copy(text: String) throws {}
        func copy(file: URL) throws { throw SpotError.fault("Openspot cannot copy \(file.lastPathComponent).") }
        func text() -> String { "kept text" }
        func paste() throws {}
    }

    private struct Windows: MacWindows {
        func frame() async throws -> WindowFrame { WindowFrame(window: CGRect(x: 10, y: 20, width: 300, height: 400), area: CGRect(x: 0, y: 33, width: 1728, height: 1084)) }
        func move(_ move: WindowMove) async throws {}
    }

    private struct Screen: MacScreen {
        func devices() async -> [ScreenDevice] { [ScreenDevice(kind: .display, id: "1", name: "Built-in", detail: "1728×1117")] }
        func shot(_ capture: ScreenCapture, in folder: URL) async throws -> URL? { folder.appendingPathComponent(capture.file ?? "shot.png") }
        func startRecording(_ capture: ScreenCapture, in folder: URL) async throws {}
        func stopRecording() async throws -> ScreenRecording { ScreenRecording(file: "/shots/a.mp4") }
        func recording() async throws -> ScreenRecording? { nil }
    }

    private struct FakeTranslation: MacTranslation {
        func translate(_ text: String, from: String?, to: String?) async throws -> TranslatedText { TranslatedText(text: text.uppercased()) }
        func languages() async throws -> [String] { ["en"] }
    }

    private struct Answer: Equatable {
        let stdout: String
        let stderr: String
        let code: Int
    }

    private var folder: URL!
    private var socket: CommandSocket?
    private let host = Mac(
        calendar: FakeCalendar(), reminders: FakeReminders(), clipboard: Clipboard(), windows: Windows(), screen: Screen(), translation: FakeTranslation(),
        pickColor: { HexColor(red: 1, green: 0x88 / 255.0, blue: 0) }, pickFolder: { URL(fileURLWithPath: "/Users/a/Repos") }
    )

    private var config: URL { folder.appendingPathComponent("config", isDirectory: true) }
    private var spots: URL { config.appendingPathComponent("spots", isDirectory: true) }
    private var variables: [String: String] { ["OPENSPOT_CONFIG": config.path, "OPENSPOT_SPOTS": spots.path, "TONE": "warm"] }

    override func setUp() async throws {
        let temp = try XCTUnwrap(realpath(FileManager.default.temporaryDirectory.path, nil))
        defer { free(temp) }
        folder = URL(fileURLWithPath: String(cString: temp), isDirectory: true).appendingPathComponent("cr-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        let runs = await SpotRuns()
        socket = CommandSocket(folder: folder, api: CommandAPI(mac: host, places: .test(ProcessInfo.processInfo.environment.merging(variables) { _, new in new }), app: FakeRunningApp(), runs: runs))
    }

    override func tearDown() async throws {
        socket?.close()
        try? FileManager.default.removeItem(at: folder)
    }

    private func alone(_ argv: [String], input: String?) async throws -> Answer {
        let environment = ProcessInfo.processInfo.environment.merging(variables) { _, new in new }.merging(["PWD": folder.path]) { _, new in new }
        let call = try XCTUnwrap(CommandLineCall(arguments: argv, environment: environment))
        let printed = Printed()
        let output = CommandOutput { text, isError in printed.add(text, isError: isError) }
        let request = CommandRequest(arguments: argv, folder: folder.path, isPiped: input != nil)
        let work = try XCTUnwrap(CommandAPI(mac: host, places: .test(environment)).work(for: call, request: request, input: { input ?? "" }, output: output))
        let answer = await work()
        output.print(answer.output)
        output.report(answer.errors)
        return Answer(stdout: printed.stdout, stderr: printed.stderr, code: Int(answer.code))
    }

    private func app(_ argv: [String], input: String?) throws -> Answer {
        let connection = SocketConnection(path: folder.appendingPathComponent(CommandSocket.name).path)
        defer { connection.close() }
        try connection.send(["jsonrpc": "2.0", "id": 1, "method": "ask", "params": ["argv": argv, "cwd": folder.path, "piped": input != nil]])
        let exchange = try connection.exchange(input: input.map { [$0] } ?? [])
        return Answer(stdout: exchange.stdout, stderr: exchange.stderr, code: exchange.code ?? -1)
    }

    func testEachCallThatTheAppAnswersGivesTheSameAnswerAlone() async throws {
        try "#!/bin/sh\necho\n".writeScript(to: spots.spotFile("weather"), toml: "mode = 'huge'")
        try "#!/bin/sh\nprintf 'frame=\\ntitle=Notes\\n'\n".writeScript(to: spots.spotFile("notes"), toml: "")
        try "#!/bin/sh\nprintf 'args=%s\\nfolder=%s\\ntone=%s\\n---\\n' \"$*\" \"$PWD\" \"$TONE\"; cat; echo 'said' >&2; exit 3\n".writeScript(to: spots.spotFile("echo"))
        let calls: [([String], String?)] = [
            (["check", "spots"], nil),
            (["check", "spots", "--json"], nil),
            (["check", "spots", "config/spots"], nil),
            (["check", "sheet"], "frame=\ntitle=Hi\n"),
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
            (["translate", "text"], "hello"),
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
