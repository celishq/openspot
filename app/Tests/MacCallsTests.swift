import XCTest
@testable import OpenspotCore

/// Proves that the running app answers the calls of the clipboard, the windows, the screen, translation and the picks
/// through its socket, with its own Mac, so that the command starts no second app for them (S1).
final class MacCallsTests: XCTestCase {
    /// A Mac that keeps each act that a call asks of it, as a line.
    private final class Host: Mac, @unchecked Sendable {
        private let lock = NSLock()
        private var kept: [String] = []

        var acts: [String] { lock.withLock { kept } }

        func keep(_ act: String) {
            lock.withLock { kept.append(act) }
        }

        func eventStore() -> any EventStore { FakeEventStore() }
        func reminderStore() -> any ReminderStore { FakeReminderStore() }
        func showCalendar(at time: Date) throws {}
        func open(_ link: URL) -> Bool { true }

        func copy(text: String) throws { keep("copy \(text)") }
        func copy(file: URL) throws { keep("copy file \(file.path)") }
        func clipboardText() -> String { "kept text" }
        func paste() throws { keep("paste") }
        func windowFrame() async throws -> String { "10 20 300 400 0 33 1728 1084\n" }

        func moveWindow(_ move: WindowMove) async throws {
            keep(move == WindowMove(words: ["0 0 1/2 1", "1/2 0 1/2 1"]) ? "move halves" : "move other")
        }

        func screenSources() async -> String { "row=display:1\n" }

        func screenShot(_ capture: ScreenCapture, in folder: URL) async throws -> String {
            keep("shot \(capture.file ?? "-") in \(folder.lastPathComponent)")
            return "/shots/a.png\n"
        }

        func startRecording(_ capture: ScreenCapture, in folder: URL) async throws -> String {
            keep("record \(capture.file ?? "-") in \(folder.lastPathComponent)")
            return ""
        }

        func stopRecording() async throws -> String { "/shots/a.mp4\n" }
        func recordingStatus() async throws -> String { "state=idle\n" }

        func translate(_ text: String, from: String?, to: String?) async throws -> String {
            keep("translate \(text) from \(from ?? "-") to \(to ?? "-")")
            return "text=hello\n"
        }

        func translationLanguages() async -> String { "preferred=en\n" }
        func pickColor() async -> String { "#FF8800\n" }
        func pickFolder() async -> String { "/Users/a/Repos\n" }
    }

    private var folder: URL!
    private var socket: CommandSocket?
    private let host = Host()

    private var config: URL { folder.appendingPathComponent("config") }
    private var client: URL { folder.appendingPathComponent("A.app/Contents/Helpers/openspot") }

    override func setUpWithError() throws {
        let temp = try XCTUnwrap(realpath(FileManager.default.temporaryDirectory.path, nil))
        defer { free(temp) }
        folder = URL(fileURLWithPath: String(cString: temp), isDirectory: true).appendingPathComponent("mc-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("A.app/Contents/MacOS"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        let built = Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot")
        try FileManager.default.copyItem(at: built, to: client)
        try "#!/bin/sh\necho \"alone: $*\"\n".writeScript(to: folder.appendingPathComponent("A.app/Contents/MacOS/Openspot"))
        socket = CommandSocket(folder: config, api: CommandAPI(mac: host))
    }

    override func tearDownWithError() throws {
        socket?.close()
        try? FileManager.default.removeItem(at: folder)
    }

    /// Runs the command with the arguments and stdin in a folder, and returns what it prints and its exit code.
    private func run(_ arguments: [String], input: String = "", in place: URL? = nil) throws -> (output: String, errors: String, code: Int32) {
        try Self.run(client, config: config, arguments, input: input, in: place ?? folder)
    }

    private static func run(_ client: URL, config: URL, _ arguments: [String], input: String, in place: URL) throws -> (output: String, errors: String, code: Int32) {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        let stdin = Pipe()
        process.executableURL = client
        process.arguments = arguments
        process.environment = ["OPENSPOT_CONFIG": config.path, "PATH": "/usr/bin:/bin"]
        process.currentDirectoryURL = place
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

    func testTheAppAnswersThroughItsSocketWhenTheConfigFolderHasALongPath() throws {
        let deep = folder.appendingPathComponent(String(repeating: "deep-folder-", count: 10), isDirectory: true)
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        XCTAssertGreaterThan(deep.appendingPathComponent(CommandSocket.name).path.utf8.count, 103)
        let socket = try XCTUnwrap(CommandSocket(folder: deep, api: CommandAPI(mac: host)))
        defer { socket.close() }

        let answer = try Self.run(client, config: deep, ["clipboard", "read"], input: "", in: folder)

        XCTAssertEqual(answer.output, "kept text")
        XCTAssertEqual(answer.code, 0)
    }

    func testTheAppCopiesStdinAndAFileOfTheCallersFolderReadsAndPastes() throws {
        let place = folder.appendingPathComponent("notes", isDirectory: true)
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)

        let copied = try run(["clipboard", "copy"], input: "hello")
        let file = try run(["clipboard", "copy", "list.txt"], in: place)
        let read = try run(["clipboard", "read"])
        let pasted = try run(["clipboard", "paste"])

        XCTAssertEqual([copied.code, file.code, read.code, pasted.code], [0, 0, 0, 0], copied.output + file.output + pasted.output)
        XCTAssertEqual(read.output, "kept text")
        XCTAssertEqual(host.acts, ["copy hello", "copy file \(place.path)/list.txt", "paste"])
    }

    func testTheAppReadsAndMovesTheWindowInFront() throws {
        let frame = try run(["window", "frame"])
        let moved = try run(["window", "move", "0 0 1/2 1", "1/2 0 1/2 1"])

        XCTAssertEqual(frame.output, "10 20 300 400 0 33 1728 1084\n")
        XCTAssertEqual([frame.code, moved.code], [0, 0], moved.output)
        XCTAssertEqual(host.acts, ["move halves"])
    }

    func testTheAppListsSourcesTakesAShotAndRecordsInTheCallersFolder() throws {
        let place = folder.appendingPathComponent("talks", isDirectory: true)
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)

        let sources = try run(["screen", "sources"])
        let shot = try run(["screen", "shot", "display:1", "a.png"], in: place)
        let start = try run(["screen", "record", "start", "display:1", "b.mp4"], in: place)
        let stop = try run(["screen", "record", "stop"])
        let status = try run(["screen", "record", "status"])

        XCTAssertEqual([sources.output, shot.output, stop.output, status.output], ["row=display:1\n", "/shots/a.png\n", "/shots/a.mp4\n", "state=idle\n"])
        XCTAssertEqual(start.code, 0, start.output)
        XCTAssertEqual(host.acts, ["shot a.png in talks", "record b.mp4 in talks"])
    }

    /// In Careful mode, a spot with no `files` use takes a capture only into a file of its data folder, a temp folder or a
    /// folder of its `screen` use, as its own process could write, and a capture into any other file is refused with no ask
    /// of the screen (Z8).
    @MainActor
    func testInCarefulModeASpotsCaptureIntoAFileOutsideItsFoldersIsRefused() async throws {
        let runs = SpotRuns()
        runs.isCareful = true
        let fenced = runs.tokens.issue(for: Spot(id: "shots", name: "Shots", url: folder.appendingPathComponent("shots.sh"), dataName: "shots", uses: [.screen]))
        let free = runs.tokens.issue(for: Spot(id: "files", name: "Files", url: folder.appendingPathComponent("files.sh"), dataName: "files", uses: [.screen, .files]))
        let api = CommandAPI(mac: host, runs: runs)
        let home = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["HOME"], "the test scheme gives a private home"), isDirectory: true).standardizedFileURL
        let data = URL(fileURLWithPath: try XCTUnwrap(ScriptProcess.environment(base: ProcessInfo.processInfo.environment, app: "", dataName: "shots")["OPENSPOT_DATA"]), isDirectory: true)
        let outside = home.appendingPathComponent("Documents/mc-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }
        try? FileManager.default.removeItem(at: data.appendingPathComponent("away"))
        try FileManager.default.createSymbolicLink(at: data.appendingPathComponent("away"), withDestinationURL: outside)
        func answer(_ arguments: [String], _ token: String, in place: URL) async throws -> CommandAnswer {
            let environment = [CallerTokens.variable: token, "PWD": place.path]
            let work = try XCTUnwrap(api.work(for: try XCTUnwrap(CommandLineCall(arguments: arguments, environment: environment)), input: { "" }, environment: environment))
            return await work()
        }

        let shot = try await answer(["screen", "shot", "display:1", "a.png"], fenced, in: outside)
        let events = try await answer(["screen", "record", "start", "display:1", "--events", outside.appendingPathComponent("e.json").path], fenced, in: data)
        let linked = try await answer(["screen", "shot", "display:1", "away/b.png"], fenced, in: data)
        let climbed = try await answer(["screen", "shot", "display:1", "away/../g.png"], fenced, in: data)
        let own = try await answer(["screen", "shot", "display:1", "c.png"], fenced, in: data)
        let temp = try await answer(["screen", "shot", "display:1", "d.png"], fenced, in: FileManager.default.temporaryDirectory)
        let desktop = try await answer(["screen", "shot", "display:1", "e.png"], fenced, in: home.appendingPathComponent("Desktop"))
        let anywhere = try await answer(["screen", "shot", "display:1", "f.png"], free, in: outside)

        XCTAssertEqual(shot.errors, "Careful mode keeps Shots from writing \(outside.appendingPathComponent("a.png").path). Name a file in its data folder or a temp folder, or add `uses=files` to its header.\n")
        XCTAssertEqual([shot.code, events.code, linked.code, climbed.code], [1, 1, 1, 1])
        XCTAssertEqual([own.code, temp.code, desktop.code, anywhere.code], [0, 0, 0, 0], own.errors + temp.errors + desktop.errors)
        XCTAssertEqual(host.acts, ["shot c.png in shots", "shot d.png in \(FileManager.default.temporaryDirectory.lastPathComponent)", "shot e.png in Desktop", "shot f.png in \(outside.lastPathComponent)"])
    }

    func testTheAppTranslatesStdinAndListsItsLanguages() throws {
        let translated = try run(["translate", "--to", "en"], input: "hola")
        let languages = try run(["translate", "languages"])

        XCTAssertEqual([translated.output, languages.output], ["text=hello\n", "preferred=en\n"])
        XCTAssertEqual(host.acts, ["translate hola from - to en"])
    }

    /// A pick runs on the main thread of the app, so the test waits for the command off it.
    func testTheAppAsksForAColourAndAFolder() async throws {
        let (client, config, folder) = (client, config, folder!)
        let colour = try await Task.detached { try Self.run(client, config: config, ["color", "pick"], input: "", in: folder) }.value
        let picked = try await Task.detached { try Self.run(client, config: config, ["folder", "pick"], input: "", in: folder) }.value

        XCTAssertEqual(colour.output, "#FF8800\n")
        XCTAssertEqual(picked.output, "/Users/a/Repos\n")
    }
}
