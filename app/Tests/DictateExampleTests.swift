import AppKit
import XCTest
@testable import OpenspotCore

final class DictateExampleTests: SampleSpotsCase {
    private static let model = "ggml-large-v3-turbo.bin"
    private static let program = Task { () throws -> URL in
        let spot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("examples/dictate.spot")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-dictate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let main = folder.appendingPathComponent("main.swift")
        try FileManager.default.copyItem(at: spot.appendingPathComponent("dictate.swift"), to: main)
        let sources = try FileManager.default.contentsOfDirectory(atPath: spot.appendingPathComponent("dictate").path).filter { $0.hasSuffix(".swift") }
        let program = folder.appendingPathComponent("dictate")
        let paths = [main.path] + sources.map { spot.appendingPathComponent("dictate/\($0)").path }
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/swiftc"), arguments: ["-Onone", "-module-name", "Spot"] + paths + ["-o", program.path], limit: 600, base: TestEnvironment.values)
        return program
    }

    private var spotFile: URL {
        examples.appendingPathComponent("dictate.spot/dictate.swift")
    }

    private func tools(in folder: URL) throws -> URL {
        let tools = folder.appendingPathComponent("tools")
        try "#!/bin/sh\n\(SampleSpotsCase.fakeOpenspot(in: folder))\n".writeScript(to: tools.appendingPathComponent("openspot"))
        try """
        #!/bin/sh
        echo "$*" >> '\(folder.path)/curl-calls'
        out=; previous=
        for a; do [ "$previous" = -o ] && out=$a; previous=$a; done
        have=$(stat -f %z "$out" 2>/dev/null || echo 0)
        if [ -f '\(folder.path)/break' ]; then rm '\(folder.path)/break'; head -c 100000 '\(folder.path)/source' >> "$out"; exit 56; fi
        if [ -f '\(folder.path)/hold' ]; then head -c 50000 '\(folder.path)/source' >> "$out"; echo $$ > '\(folder.path)/curl.pid'; exec /bin/sleep 600; fi
        tail -c +$((have + 1)) '\(folder.path)/source' >> "$out"

        """.writeScript(to: tools.appendingPathComponent("curl"))
        return tools
    }

    private func staying(in folder: URL, size: Int = 300_000) async throws -> ScriptProcess {
        let program = try await Self.program.value
        let data = folder.appendingPathComponent("data")
        try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        let tools = try tools(in: folder)
        return ScriptProcess(url: program, name: spotFile.path, mode: .stays, variables: ["OPENSPOT_DATA": data.path, "DICTATE_SIZE": String(size)], base: ["PATH": "\(tools.path):/usr/bin:/bin", "HOME": folder.path])
    }

    private func source(in folder: URL) throws -> Data {
        let bytes = Data((0..<300_000).map { UInt8($0 % 251) })
        try bytes.write(to: folder.appendingPathComponent("source"))
        return bytes
    }

    private func frames(_ script: ScriptProcess, sending blocks: String, until ends: Set<String>) async throws -> [String] {
        var frames = script.start().makeAsyncIterator()
        script.send(text: blocks)
        return try await Self.collect(&frames, until: ends)
    }

    private static func collect(_ frames: inout AsyncThrowingStream<String, Error>.Iterator, until ends: Set<String>) async throws -> [String] {
        var seen: [String] = []
        var left = ends
        while !left.isEmpty, let frame = try await frames.next() {
            seen.append(frame)
            if let end = FrameRoot(text: frame).end { left.remove(end) }
        }
        return seen
    }

    private func helper(_ arguments: [String]) async throws -> String {
        try await ScriptProcess.output(url: try await Self.program.value, arguments: arguments, base: TestEnvironment.values)
    }

    private func rows(_ frames: [String]) -> [SpotItem] {
        frames.map { SpotOutput(text: $0) }.last { !$0.items.isEmpty }?.items ?? []
    }

    func testItIsAStayingSwiftSpotWithNoClockAndNoBuildOfItsOwn() throws {
        let spot = try example("Dictate")
        let files = try FileManager.default.contentsOfDirectory(atPath: examples.appendingPathComponent("dictate.spot").path)

        XCTAssertEqual(spot.mode, .stay)
        XCTAssertEqual(spot.sources, ["dictate"])
        XCTAssertEqual(spot.soleCommand, "dictate")
        XCTAssertEqual(spot.read?.moments, [.sheet])
        XCTAssertEqual(files.sorted(), ["dictate", "dictate.swift", "readme.md", "spot.toml"])
    }

    func testTheSheetListsPastTextsNewestFirstAndCopiesOrDeletesOne() async throws {
        let folder = try temporaryFolder()
        let script = try await staying(in: folder)
        defer { script.stop() }
        try Data().write(to: folder.appendingPathComponent("data/\(Self.model)"))
        try "1000\tFirst words\n2000\tSecond, with a back\\slash\n".write(to: folder.appendingPathComponent("data/history"), atomically: true, encoding: .utf8)

        let frames = try await frames(script, sending: "call=1\narg=show\n\ncall=2\narg=open\narg=1000\n\ncall=3\narg=delete\narg=2000\n\n", until: ["1", "2", "3"])

        let first = Array(frames.prefix { FrameRoot(text: $0).end != "1" })
        XCTAssertEqual(rows(first).map(\.run), ["2000", "1000"])
        XCTAssertEqual(rows(first).map(\.title), ["Second, with a back\\slash", "First words"])
        XCTAssertEqual(rows(frames).map(\.run), ["1000"])
        XCTAssertEqual(toasts(in: folder), ["Copied"])
        XCTAssertEqual(try read("clipboard", in: folder), "First words")
        XCTAssertEqual(try read("data/history", in: folder), "1000\tFirst words\n")
    }

    func testWithNoModelTheSheetOffersTheDownloadWhichLandsWholeWithItsProgressOnTheCard() async throws {
        let folder = try temporaryFolder()
        let bytes = try source(in: folder)
        let script = try await staying(in: folder)
        defer { script.stop() }

        let frames = try await frames(script, sending: "call=1\narg=show\n\ncall=2\narg=open\narg=whisper\n\n", until: ["1", "2"])
        let offer = rows(Array(frames.prefix(2))).first

        XCTAssertEqual(offer?.run, "whisper")
        XCTAssertEqual(offer?.title, "Download speech model")
        XCTAssertEqual(offer?.pin, .top)
        XCTAssertEqual(offer?.openTitle, "Download")
        XCTAssertEqual(offer?.staysOnPick, true)
        XCTAssertTrue(SpotOutput(text: frames[1]).hidesSearch)
        let head = try XCTUnwrap(frames.compactMap { SpotOutput(text: $0).summary }.first { $0.value("progress") != nil })
        XCTAssertEqual(head.value("detail"), "0% of 1.6 GB")
        XCTAssertTrue(toasts(in: folder).contains { $0.hasPrefix("Dictate is ready.") })
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("data/\(Self.model)")), bytes)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("data/\(Self.model).part").path))
        XCTAssertEqual(try read("curl-calls", in: folder).filter { $0 == "\n" }.count, 1)
    }

    func testABrokenDownloadKeepsItsBytesAndTheNextGoesOnFromThem() async throws {
        let folder = try temporaryFolder()
        let bytes = try source(in: folder)
        FileManager.default.createFile(atPath: folder.appendingPathComponent("break").path, contents: Data())
        let script = try await staying(in: folder)
        defer { script.stop() }
        try whisperServer(in: folder)
        let part = folder.appendingPathComponent("data/\(Self.model).part")

        var frames = script.start().makeAsyncIterator()
        script.send(text: "call=1\narg=open\narg=whisper\n\n")
        let broken = try await Self.collect(&frames, until: ["1"])
        let kept = try Data(contentsOf: part)
        script.send(text: "call=2\narg=dictate\n\n")
        let resumed = try await Self.collect(&frames, until: ["2"])

        XCTAssertTrue(toasts(in: folder).contains { $0.hasPrefix("Openspot cannot download the speech model.") })
        XCTAssertEqual(kept.count, 100_000)
        XCTAssertTrue(toasts(in: folder).contains("Dictate is downloading its speech model of 1.6 GB."))
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("data/\(Self.model)")), bytes)
        XCTAssertTrue(try read("curl-calls", in: folder).split(separator: "\n").allSatisfy { $0.contains("-C -") })
    }

    func testAStopOfTheDownloadEndsCurlAndLeavesNoPartFile() async throws {
        let folder = try temporaryFolder()
        _ = try source(in: folder)
        FileManager.default.createFile(atPath: folder.appendingPathComponent("hold").path, contents: Data())
        let script = try await staying(in: folder)
        defer { script.stop() }
        let pidFile = folder.appendingPathComponent("curl.pid")

        var frames = script.start().makeAsyncIterator()
        script.send(text: "call=1\narg=open\narg=whisper\n\n")
        try await wait("curl") { FileManager.default.fileExists(atPath: pidFile.path) }
        let curl = try XCTUnwrap(pid_t(try read("curl.pid", in: folder).trimmingCharacters(in: .whitespacesAndNewlines)))
        defer { kill(curl, SIGKILL) }
        script.send(text: "call=2\narg=show\n\n")
        let during = try await Self.collect(&frames, until: ["2"])
        script.send(text: "stop=1\n\n")
        _ = try await Self.collect(&frames, until: ["1"])
        script.send(text: "call=3\narg=show\n\n")
        let after = try await Self.collect(&frames, until: ["3"])

        XCTAssertNotEqual(kill(curl, 0), 0)
        XCTAssertEqual(rows(during).first?.title, "Downloading speech model")
        XCTAssertEqual(rows(after).first?.title, "Download speech model")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("data/\(Self.model).part").path))
    }

    private func whisperServer(in folder: URL) throws {
        try "#!/bin/sh\necho $$ > '\(folder.path)/server.new'\nmv '\(folder.path)/server.new' '\(folder.path)/server'\nexec /bin/sleep 600\n".writeScript(to: folder.appendingPathComponent("tools/whisper-server"))
    }

    private func server(in folder: URL) async throws -> pid_t {
        let file = folder.appendingPathComponent("server")
        try await wait("the server") { FileManager.default.fileExists(atPath: file.path) }
        return try XCTUnwrap(pid_t(try read("server", in: folder).trimmingCharacters(in: .whitespacesAndNewlines)))
    }

    func testADownloadOfTheWrongSizeLandsNothingAndSaysSo() async throws {
        let folder = try temporaryFolder()
        _ = try source(in: folder)
        let script = try await staying(in: folder, size: 250_000)
        defer { script.stop() }

        let frames = try await frames(script, sending: "call=1\narg=open\narg=whisper\n\n", until: ["1"])

        XCTAssertTrue(toasts(in: folder).contains { $0.hasPrefix("The speech model came in the wrong size") })
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("data/\(Self.model)").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("data/\(Self.model).part").path))
    }

    func testTheDownloadRowStopsADownloadThatTheKeyStarted() async throws {
        let folder = try temporaryFolder()
        _ = try source(in: folder)
        FileManager.default.createFile(atPath: folder.appendingPathComponent("hold").path, contents: Data())
        let script = try await staying(in: folder)
        defer { script.stop() }
        try whisperServer(in: folder)
        let pidFile = folder.appendingPathComponent("curl.pid")

        var frames = script.start().makeAsyncIterator()
        script.send(text: "call=1\narg=dictate\n\n")
        try await wait("curl") { FileManager.default.fileExists(atPath: pidFile.path) }
        let curl = try XCTUnwrap(pid_t(try read("curl.pid", in: folder).trimmingCharacters(in: .whitespacesAndNewlines)))
        defer { kill(curl, SIGKILL) }
        script.send(text: "call=2\narg=open\narg=whisper\n\n")
        _ = try await Self.collect(&frames, until: ["1", "2"])

        XCTAssertNotEqual(kill(curl, 0), 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("data/\(Self.model).part").path))
    }

    private static func paste(_ text: String, on board: String, in folder: URL) async throws -> String {
        let tools = folder.appendingPathComponent("tools")
        try """
        #!/bin/sh
        [ "$1 $2" = "clipboard paste" ] || exit 0
        touch '\(folder.path)/pasting'
        n=0; while [ ! -f '\(folder.path)/go' ] && [ $n -lt 1500 ]; do sleep 0.02; n=$((n + 1)); done
        """.writeScript(to: tools.appendingPathComponent("openspot"))
        var base = TestEnvironment.values
        base["PATH"] = "\(tools.path):/usr/bin:/bin"
        return try await ScriptProcess.output(url: try await Self.program.value, arguments: ["paste", board, text], base: base)
    }

    func testAPastePutsBackEachItemThatTheClipboardHeld() async throws {
        let folder = try temporaryFolder()
        let board = NSPasteboard(name: .init("openspot-test-\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        let picture = NSPasteboardItem()
        picture.setData(Data([1, 2, 3]), forType: .png)
        let words = NSPasteboardItem()
        words.setString("Before", forType: .string)
        board.clearContents()
        board.writeObjects([picture, words])
        FileManager.default.createFile(atPath: folder.appendingPathComponent("go").path, contents: Data())

        let fault = try await Self.paste("Spoken words", on: board.name.rawValue, in: folder)

        XCTAssertEqual(fault, "\n")
        XCTAssertEqual(board.pasteboardItems?.count, 2)
        XCTAssertEqual(board.pasteboardItems?.first?.data(forType: .png), Data([1, 2, 3]))
        XCTAssertEqual(board.pasteboardItems?.last?.string(forType: .string), "Before")
    }

    func testAPasteLeavesACopyThatThePersonMadeDuringIt() async throws {
        let folder = try temporaryFolder()
        let board = NSPasteboard(name: .init("openspot-test-\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        board.clearContents()
        board.setString("Before", forType: .string)

        let name = board.name.rawValue
        async let fault = Self.paste("Spoken words", on: name, in: folder)
        try await wait("the paste") { FileManager.default.fileExists(atPath: folder.appendingPathComponent("pasting").path) }
        let pasted = board.string(forType: .string)
        board.clearContents()
        board.setString("Mine", forType: .string)
        FileManager.default.createFile(atPath: folder.appendingPathComponent("go").path, contents: Data())
        _ = try await fault

        XCTAssertEqual(pasted, "Spoken words")
        XCTAssertEqual(board.string(forType: .string), "Mine")
    }

    func testTheEndOfStdinEndsTheSpotAndItsWhisperServer() async throws {
        let folder = try temporaryFolder()
        let script = try await staying(in: folder)
        defer { script.stop() }
        try whisperServer(in: folder)

        _ = try await frames(script, sending: "call=1\narg=serve\n\n", until: ["1"])
        let server = try await server(in: folder)
        defer { kill(server, SIGKILL) }
        script.end()

        try await wait("the end of the spot and its server") { !script.isRunning && kill(server, 0) != 0 }
    }

    func testThePillShowsTheKeyOfTheCommandAsTheMacWritesIt() async throws {
        let option = try await helper(["key", "option"])
        let chord = try await helper(["key", "ctrl+option+d"])
        let none = try await helper(["key", ""])

        XCTAssertEqual(option, "⌥\n")
        XCTAssertEqual(chord, "⌃⌥D\n")
        XCTAssertEqual(none, "\n")
    }

    func testItKeepsTheWordsAndDropsTheTagsOfSounds() async throws {
        let folder = try temporaryFolder()
        let program = try await Self.program.value
        let input = folder.appendingPathComponent("heard")
        try " [BLANK_AUDIO]\n Привіт, світе.\n (soft music)\n  Second   line [Music] here.\n *laughs*\n".write(to: input, atomically: true, encoding: .utf8)

        let text = try await ScriptProcess.output(url: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "'\(program.path)' clean < '\(input.path)'"], base: TestEnvironment.values)
        let silence = try await ScriptProcess.output(url: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "printf ' [BLANK_AUDIO]\\n' | '\(program.path)' clean"], base: TestEnvironment.values)
        let dot = try await ScriptProcess.output(url: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "printf ' .\\n' | '\(program.path)' clean"], base: TestEnvironment.values)

        XCTAssertEqual(text, "Привіт, світе. Second line here.\n")
        XCTAssertEqual(silence, "\n")
        XCTAssertEqual(dot, "\n")
    }

    func testItSendsSixteenBitMonoSoundAtSixteenKilohertz() async throws {
        let folder = try temporaryFolder()
        let program = try await Self.program.value
        let file = folder.appendingPathComponent("speech.wav")

        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "'\(program.path)' wave 0 1 -1 2 > '\(file.path)'"], base: TestEnvironment.values)
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

    func testThePillRidesTheEdgeNearestThePointerAndStandsUpOnTheSides() async throws {
        func place(_ kept: String, droppedAt x: Int, _ y: Int) async throws -> String {
            try await helper(["place", kept, String(x), String(y)])
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

    func testTheHistoryKeepsTheLastTenTexts() async throws {
        let folder = try temporaryFolder()
        let file = folder.appendingPathComponent("history")

        for index in 0..<13 {
            _ = try await helper(["remember", file.path, String(1_000 + index), "Text \(index)"])
        }
        let lines = try String(contentsOf: file, encoding: .utf8).split(separator: "\n")

        XCTAssertEqual(lines.count, 10)
        XCTAssertEqual(lines.first, "1003000\tText 3")
        XCTAssertEqual(lines.last, "1012000\tText 12")
    }
}
