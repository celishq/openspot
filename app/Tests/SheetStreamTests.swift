import XCTest
@testable import OpenspotCore

final class SheetStreamTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-stream-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func script(_ body: String, name: String = "script", toml: String = "") throws -> URL {
        let url = folder.spotFile(name)
        try "#!/bin/sh\n\(body)\n".writeScript(to: url, toml: toml)
        return url
    }

    func testAMarkEndsAFrameWhereverAChunkStops() {
        var reader = SheetFrames()

        XCTAssertEqual(reader.read(Data("text=a\n-".utf8)), [])
        XCTAssertEqual(reader.read(Data("--\ntext=".utf8)), ["text=a\n"])
        XCTAssertEqual(reader.read(Data("b".utf8)), [])
        XCTAssertEqual(reader.finish(), "text=b")
        XCTAssertNil(reader.finish())
    }

    func testAFrameOverTheLimitIsDroppedAndMarksTheReader() {
        var reader = SheetFrames(limit: 8)

        XCTAssertEqual(reader.read(Data("text=a\n---\n".utf8)), ["text=a\n"])
        XCTAssertFalse(reader.isOverLimit)
        XCTAssertEqual(reader.read(Data("text=abcdef\n---\n".utf8)), [])
        XCTAssertTrue(reader.isOverLimit)
    }

    func testALineWithNoEndOverTheLimitMarksTheReader() {
        var reader = SheetFrames(limit: 8)

        _ = reader.read(Data("abcdefghijk".utf8))

        XCTAssertTrue(reader.isOverLimit)
        XCTAssertNil(reader.finish())
    }

    func testATerminalProgressCodeIsAFrameWithItsValue() {
        var reader = SheetFrames()

        XCTAssertEqual(reader.read(Data("Copying\u{1b}]9;4;1;42\u{07}".utf8)), ["frame=\nprogress=0.42\n"])
        XCTAssertEqual(reader.read(Data("\u{1b}]9;4;1".utf8)), [])
        XCTAssertEqual(reader.read(Data(";50\u{1b}\\\n".utf8)), ["frame=\nprogress=0.5\n"])
        XCTAssertEqual(reader.read(Data("\u{1b}]9;4;3;0\u{07}\u{1b}]9;4;0;0\u{07}".utf8)), [])
    }

    func testATerminalNotificationCodeIsAFrameWithItsToast() {
        var reader = SheetFrames()

        XCTAssertEqual(reader.read(Data("\u{1b}]9;Build done\u{07}".utf8)), [TextBlock(fields: [.init(key: SheetFrames.notice, value: "Build done")]).text])
    }

    func testEachOtherEscapeCodeLeavesTheText() {
        var reader = SheetFrames()

        XCTAssertEqual(reader.read(Data("title=\u{1b}[1;31mRed\u{1b}[0m\n\u{1b}]8;;https://a.b\u{07}link\u{1b}]8;;\u{07}\u{1b}=".utf8)), [])
        XCTAssertEqual(reader.finish(), "title=Red\nlink")
    }

    func testAScriptWithNoMarkGivesOneFrameWhenItEnds() async throws {
        let url = try script("printf 'text=a\\ntitle=A\\n'")
        var frames: [String] = []

        for try await frame in ScriptProcess(url: url, limit: 60).start() { frames.append(frame) }

        XCTAssertEqual(frames, ["text=a\ntitle=A\n"])
    }

    func testAFrameArrivesWhileTheScriptRuns() async throws {
        let url = try script("printf 'text=a\\n---\\n'\nsleep 30")
        let started = Date()

        for try await frame in ScriptProcess(url: url, limit: 60).start() {
            XCTAssertEqual(frame, "text=a\n")
            break
        }

        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
    }

    func testEndingTheStreamStopsTheScript() async throws {
        let marker = folder.appendingPathComponent("alive")
        let url = try script("printf 'text=a\\n---\\n'\nsleep 0.3\ntouch '\(marker.path)'")

        for try await _ in ScriptProcess(url: url, limit: 60).start() { break }
        try await Task.sleep(for: .seconds(0.5))

        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    func testOnlyTheFirstFrameHasATimeLimit() async throws {
        let release = folder.appendingPathComponent("release").path
        let gate = "n=0; while [ ! -f '\(release)' ] && [ $n -lt 1500 ]; do sleep 0.02; n=$((n + 1)); done"
        let silent = try script("sleep 30", name: "silent")
        let slow = try script("printf 'text=a\\n---\\n'\n\(gate)\nprintf 'text=b\\n---\\n'", name: "slow")
        var frames = ScriptProcess(url: slow, limit: 1.5).start().makeAsyncIterator()
        let first = try await frames.next()

        do {
            for try await _ in ScriptProcess(url: silent, limit: 1.5).start() {}
            XCTFail("It should time out.")
        } catch {
            XCTAssertEqual(error as? SpotError, .timedOut)
        }
        FileManager.default.createFile(atPath: release, contents: Data())
        let second = try await frames.next()

        XCTAssertEqual([first, second], ["text=a\n", "text=b\n"])
    }

    func testAFrameReplacesTheWholeSheet() throws {
        var panel = try XCTUnwrap(SheetParts(output: SpotOutput(text: "frame=\ngrid=a b\n\ntext=a\ntitle=A\n\ntext=b\ntitle=B\n")))

        panel.take(SpotOutput(text: "frame=\ngrid.large=c\n\ntext=c\ntitle=C\n"), answering: panel.generation)

        XCTAssertEqual(panel.parts.map(\.id), ["c"])
        XCTAssertNil(panel.layout)
    }

    func testAFrameKeepsTheTextThePersonIsTyping() throws {
        var panel = try XCTUnwrap(SheetParts(output: SpotOutput(text: "frame=\ngrid=a\n\nfield=a\nvalue=typed\n")))

        panel.take(SpotOutput(text: "frame=\ngrid=a\n\nfield=a\nvalue=old\n"), answering: panel.generation, keeping: "a")

        XCTAssertEqual(panel.parts.first?.value, "typed")
    }

    func testACallOfAStayingScriptIsOneBlock() {
        XCTAssertEqual(Message(.show).block(id: 1), "call=1\narg=show\n\n")
        XCTAssertEqual(Message(.show, event: .clock(60)).block(id: 5), "call=5\narg=show\nevent=clock.60\n\n")
        XCTAssertEqual(Message(.press("swap")).block(id: 2), "call=2\narg=swap\n\n")
        XCTAssertEqual(Message(.set("input", to: "one\ntwo")).block(id: 3), "call=3\narg=input\narg=one\\ntwo\n\n")
        XCTAssertEqual(Message(.drop(paths: ["/a b.mov", "-rf.mov"])).block(id: 4), "call=4\narg=drop\narg=/a b.mov\narg=-rf.mov\n\n")
    }

    func testTheBlockHoldsEachLineOfTheStdinOfTheCall() {
        let values = "input.input=one\\ntwo\ninput.source=auto\n"

        XCTAssertEqual(
            Message(.set("source", to: "auto"), given: values).block(id: 7),
            "call=7\narg=source\narg=auto\ninput.input=one\\ntwo\ninput.source=auto\n\n"
        )
    }

    func testALiveScriptAnswersEachEventAndKeepsItsState() async throws {
        let url = try script("""
        count=0
        while IFS= read -r line; do
          [ -n "$line" ] || { count=$((count + 1)); printf 'part=a\\ntitle=%s\\n---\\n' "$count"; }
        done
        """)
        let live = ScriptProcess(url: url, mode: .stays, limit: 60)
        var frames = live.start().makeAsyncIterator()

        live.send(Message(.show), id: 1)
        let first = try await frames.next()
        live.send(Message(.press("a")), id: 2)
        let second = try await frames.next()

        XCTAssertEqual(first, "part=a\ntitle=1\n")
        XCTAssertEqual(second, "part=a\ntitle=2\n")
        live.end()
    }

    func testAScriptThatIgnoresTheEndOfItsInputIsStopped() async throws {
        let url = try script("trap '' HUP\n\(String.longLoop)")
        let live = ScriptProcess(url: url, mode: .stays, limit: 60, stopPause: 0.2)
        _ = live.start()

        live.end()
        try await wait("the end of the live process") { !live.isRunning }
    }

    func testAScriptThatStaysIsAList() throws {
        let url = try script("", toml: "mode = 'stay'\non = ['panel.open']")
        let command = try XCTUnwrap(try SpotFile(file: url, id: "script")).spots.first

        XCTAssertEqual(command?.mode, .stay)
        XCTAssertEqual(command?.kind, .list)
        XCTAssertEqual(command?.showsState, false)
    }

    func testAPlainFirstReadOfAStayingScriptGivesItsFirstFrame() async throws {
        let url = try script("while IFS= read -r line; do case \"$line\" in call=*) call=${line#call=} ;; esac; [ -n \"$line\" ] || printf 'end=%s\\n\\nframe=\\ngrid=a\\n\\ntext=a\\ntitle=A\\n---\\n' \"$call\"; done")
        let command = Spot(id: "a", name: "A", url: url, kind: .list, mode: .stay)

        let output = try await command.items(timeout: 60)

        XCTAssertEqual(output.parts.map(\.id), ["a"])
    }
}
