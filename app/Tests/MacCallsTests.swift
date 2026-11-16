import XCTest
@testable import OpenspotCore

final class MacCallsTests: XCTestCase {
    private final class Acts: @unchecked Sendable {
        private let lock = NSLock()
        private var kept: [String] = []

        var all: [String] { lock.withLock { kept } }

        func keep(_ act: String) {
            lock.withLock { kept.append(act) }
        }
    }

    private struct Clipboard: MacClipboard {
        let acts: Acts

        func copy(text: String) throws { acts.keep("copy \(text)") }
        func copy(file: URL) throws { acts.keep("copy file \(file.path)") }
        func text() -> String { "kept text" }
        func paste() throws { acts.keep("paste") }
    }

    private struct Windows: MacWindows {
        let acts: Acts

        func frame() async throws -> WindowFrame { WindowFrame(window: CGRect(x: 10, y: 20, width: 300, height: 400), area: CGRect(x: 0, y: 33, width: 1728, height: 1084)) }

        func move(_ move: WindowMove) async throws {
            acts.keep(move == WindowMove(words: ["0 0 1/2 1", "1/2 0 1/2 1"]) ? "move halves" : "move other")
        }
    }

    private struct Screen: MacScreen {
        let acts: Acts

        func devices() async -> [ScreenDevice] {
            [
                ScreenDevice(kind: .display, id: "1", name: "Built-in", detail: "1728×1117"),
                ScreenDevice(kind: .window, id: "42", name: "Notes", detail: "Notes", app: "/Applications/Notes.app"),
                ScreenDevice(kind: .mic, id: "m1", name: "MacBook Microphone"),
                ScreenDevice(kind: .camera, id: "c1", name: "FaceTime Camera")
            ]
        }

        func shot(_ capture: ScreenCapture, in folder: URL) async throws -> URL? {
            acts.keep("shot \(capture.file ?? "-") in \(folder.lastPathComponent)")
            return URL(fileURLWithPath: "/shots/a.png")
        }

        func startRecording(_ capture: ScreenCapture, in folder: URL) async throws {
            acts.keep("record \(capture.file ?? "-") in \(folder.lastPathComponent)")
        }

        func stopRecording() async throws -> ScreenRecording { ScreenRecording(file: "/shots/a.mp4", camera: "/shots/a.camera.mov") }
        func recording() async throws -> ScreenRecording? { nil }
    }

    private struct FakeTranslation: MacTranslation {
        let acts: Acts

        func translate(_ text: String, from: String?, to: String?) async throws -> TranslatedText {
            acts.keep("translate \(text) from \(from ?? "-") to \(to ?? "-")")
            return TranslatedText(text: "hello")
        }

        func languages() async throws -> [String] { ["uk", "en"] }
    }

    private var folder: URL!
    private var socket: CommandSocket?
    private let acts = Acts()

    private var host: Mac {
        Mac(
            clipboard: Clipboard(acts: acts), windows: Windows(acts: acts), screen: Screen(acts: acts), translation: FakeTranslation(acts: acts),
            pickColor: { HexColor(red: 1, green: 0x88 / 255.0, blue: 0) }, pickFolder: { URL(fileURLWithPath: "/Users/a/Repos") }
        )
    }

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
        socket = CommandSocket(folder: config, api: CommandAPI(mac: host, places: .test(["OPENSPOT_CONFIG": config.path]), rates: .offline))
    }

    override func tearDownWithError() throws {
        socket?.close()
        try? FileManager.default.removeItem(at: folder)
    }

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
        let socket = try XCTUnwrap(CommandSocket(folder: deep, api: CommandAPI(mac: host, places: .test(["OPENSPOT_CONFIG": deep.path]), rates: .offline)))
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
        XCTAssertEqual(acts.all, ["copy hello", "copy file \(place.path)/list.txt", "paste"])
    }

    func testTheAppReadsAndMovesTheWindowInFront() throws {
        let frame = try run(["window", "frame"])
        let moved = try run(["window", "move", "0 0 1/2 1", "1/2 0 1/2 1"])

        XCTAssertEqual(frame.output, "10 20 300 400 0 33 1728 1084\n")
        XCTAssertEqual([frame.code, moved.code], [0, 0], moved.output)
        XCTAssertEqual(acts.all, ["move halves"])
    }

    func testTheAppListsSourcesTakesAShotAndRecordsInTheCallersFolder() throws {
        let place = folder.appendingPathComponent("talks", isDirectory: true)
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)

        let sources = try run(["screen", "sources"])
        let shot = try run(["screen", "shot", "display:1", "a.png"], in: place)
        let start = try run(["screen", "record", "start", "display:1", "b.mp4"], in: place)
        let stop = try run(["screen", "record", "stop"])
        let status = try run(["screen", "record", "status"])

        XCTAssertEqual(sources.output, """
        row=display:1
        title=Built-in
        detail=Display · 1728×1117
        icon=display

        row=window:42
        title=Notes
        detail=Notes
        icon=/Applications/Notes.app

        row=system
        title=Sound of the Mac
        detail=Sound
        icon=speaker.wave.2

        row=mic:m1
        title=MacBook Microphone
        detail=Microphone
        icon=mic

        row=camera:c1
        title=FaceTime Camera
        detail=Camera
        icon=camera


        """)
        XCTAssertEqual([shot.output, stop.output, status.output], ["/shots/a.png\n", "/shots/a.mp4\n/shots/a.camera.mov\n", "state=idle\n"])
        XCTAssertEqual(start.code, 0, start.output)
        XCTAssertEqual(acts.all, ["shot a.png in talks", "record b.mp4 in talks"])
    }

    @MainActor
    func testInCarefulModeASpotsCaptureIntoAFileOutsideItsFoldersIsRefused() async throws {
        let runs = SpotRuns()
        runs.isCareful = true
        let fenced = runs.tokens.issue(for: Spot(id: "shots", name: "Shots", url: folder.appendingPathComponent("shots.sh"), dataName: "shots", uses: [.screen]))
        let free = runs.tokens.issue(for: Spot(id: "files", name: "Files", url: folder.appendingPathComponent("files.sh"), dataName: "files", uses: [.screen, .files]))
        let api = CommandAPI(mac: host, places: .test(["OPENSPOT_CONFIG": config.path]), runs: runs, rates: .offline)
        let home = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["HOME"], "the test scheme gives a private home"), isDirectory: true).standardizedFileURL
        let data = URL(fileURLWithPath: try XCTUnwrap(ScriptProcess.environment(base: ProcessInfo.processInfo.environment, app: "", dataName: "shots")["OPENSPOT_DATA"]), isDirectory: true)
        let outside = home.appendingPathComponent("Documents/mc-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }
        try? FileManager.default.removeItem(at: data.appendingPathComponent("away"))
        try FileManager.default.createSymbolicLink(at: data.appendingPathComponent("away"), withDestinationURL: outside)
        func answer(_ arguments: [String], _ token: String, in place: URL) async throws -> CommandAnswer {
            let request = CommandRequest(arguments: arguments, folder: place.path, token: token)
            let work = try XCTUnwrap(api.work(for: try XCTUnwrap(api.call(of: request)), request: request, input: { "" }))
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
        XCTAssertEqual(acts.all, ["shot c.png in shots", "shot d.png in \(FileManager.default.temporaryDirectory.lastPathComponent)", "shot e.png in Desktop", "shot f.png in \(outside.lastPathComponent)"])
    }

    func testTheAppTranslatesStdinAndListsItsLanguages() throws {
        let translated = try run(["translate", "text", "--to", "en"], input: "hola")
        let languages = try run(["translate", "languages"])

        XCTAssertEqual(translated.output, "text=hello\n")
        XCTAssertEqual(TextBlock.blocks(in: languages.output).compactMap { $0.value("language") }.sorted(), ["en", "uk"])
        XCTAssertEqual(acts.all, ["translate hola from - to en"])
    }

    func testCoreWritesTheBlocksOfARecordingATranslationAndTheLanguages() {
        XCTAssertEqual(ScreenRecording.status(of: ScreenRecording(file: "/a.mp4", events: "/e.json", seconds: 7)), "state=recording\nfile=/a.mp4\nevents=/e.json\nseconds=7\n")
        XCTAssertEqual(ScreenRecording(block: ScreenRecording(file: "/a.mp4", camera: "/a.camera.mov", seconds: 7).block), ScreenRecording(file: "/a.mp4", camera: "/a.camera.mov", seconds: 7))
        XCTAssertNil(ScreenRecording(block: TextBlock(fields: [.init(key: "state", value: "idle")])))
        XCTAssertEqual(TranslatedText(status: .missing, from: "es", to: "uk").block.text, "status=missing\nfrom=es\nto=uk\n")
        XCTAssertEqual(TranslatedText(block: TranslatedText(text: "hello", from: "es", to: "en").block), TranslatedText(text: "hello", from: "es", to: "en"))
        XCTAssertEqual(TranslatedText().block.text, "")
        XCTAssertEqual(
            TranslatedText.languages(["uk", "en"], preferred: ["de-DE", "en"], locale: Locale(identifier: "en")),
            "preferred=de\npreferred=en\n\nlanguage=en\nname=English\n\nlanguage=uk\nname=Ukrainian\n"
        )
    }

    func testAMacWithNoPartSaysSoAndAFakeStubsOneNoun() async throws {
        let api = CommandAPI(mac: Mac(windows: Windows(acts: acts)), places: .test(["OPENSPOT_CONFIG": config.path]), rates: .offline)
        func answer(_ arguments: [String]) async throws -> CommandAnswer {
            try await XCTUnwrap(api.work(for: .test(arguments), input: { "" }))()
        }

        let frame = try await answer(["window", "frame"])
        let copied = try await answer(["clipboard", "copy", "a.txt"])
        let sources = try await answer(["screen", "sources"])
        let translated = try await answer(["translate", "text"])
        let events = try await answer(["calendar", "events"])
        let colour = try await answer(["color", "pick"])

        XCTAssertEqual(frame.output, "10 20 300 400 0 33 1728 1084\n")
        XCTAssertEqual([copied.errors, sources.errors, translated.errors, events.errors], ["This Mac has no clipboard.\n", "This Mac has no screen.\n", "This Mac cannot translate.\n", "This Mac has no calendar.\n"])
        XCTAssertEqual([colour.output, colour.errors], ["", ""])
    }

    func testTheAppAsksForAColourAndAFolder() async throws {
        let (client, config, folder) = (client, config, folder!)
        let colour = try await Task.detached { try Self.run(client, config: config, ["color", "pick"], input: "", in: folder) }.value
        let picked = try await Task.detached { try Self.run(client, config: config, ["folder", "pick"], input: "", in: folder) }.value

        XCTAssertEqual(colour.output, "#FF8800\n")
        XCTAssertEqual(picked.output, "/Users/a/Repos\n")
    }
}
