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

    private func script(_ body: String, name: String = "script") throws -> URL {
        let url = folder.appendingPathComponent("\(name).sh")
        try "#!/bin/sh\n\(body)\n".writeScript(to: url)
        return url
    }

    private func wait(until fact: () -> Bool) async throws {
        for _ in 0..<500 {
            if fact() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited too long")
    }

    func testAMarkEndsAFrameWhereverAChunkStops() {
        var reader = SheetFrameReader()

        XCTAssertEqual(reader.read(Data("part=a\n-".utf8)), [])
        XCTAssertEqual(reader.read(Data("--\npart=".utf8)), ["part=a\n"])
        XCTAssertEqual(reader.read(Data("b".utf8)), [])
        XCTAssertEqual(reader.finish(), "part=b")
        XCTAssertNil(reader.finish())
    }

    // MARK: R12

    func testATerminalProgressCodeIsAFrameWithItsValue() {
        var reader = SheetFrameReader()

        XCTAssertEqual(reader.read(Data("Copying\u{1b}]9;4;1;42\u{07}".utf8)), ["value=0.42\n"])
        XCTAssertEqual(reader.read(Data("\u{1b}]9;4;1".utf8)), [])
        XCTAssertEqual(reader.read(Data(";50\u{1b}\\\n".utf8)), ["value=0.5\n"])
        XCTAssertEqual(reader.read(Data("\u{1b}]9;4;3;0\u{07}\u{1b}]9;4;0;0\u{07}".utf8)), [])
    }

    func testATerminalNotificationCodeIsAFrameWithItsToast() {
        var reader = SheetFrameReader()

        XCTAssertEqual(reader.read(Data("\u{1b}]9;Build done\u{07}".utf8)), ["toast=Build done\n"])
    }

    func testEachOtherEscapeCodeLeavesTheText() {
        var reader = SheetFrameReader()

        XCTAssertEqual(reader.read(Data("title=\u{1b}[1;31mRed\u{1b}[0m\n\u{1b}]8;;https://a.b\u{07}link\u{1b}]8;;\u{07}\u{1b}=".utf8)), [])
        XCTAssertEqual(reader.finish(), "title=Red\nlink")
    }

    func testAScriptWithNoMarkGivesOneFrameWhenItEnds() async throws {
        let url = try script("printf 'part=a\\ntitle=A\\n'")
        var frames: [String] = []

        for try await frame in try ScriptProcess(url: url, limit: 5).start() { frames.append(frame) }

        XCTAssertEqual(frames, ["part=a\ntitle=A\n"])
    }

    func testAFrameArrivesWhileTheScriptRuns() async throws {
        let url = try script("printf 'part=a\\n---\\n'\nsleep 30")
        let started = Date()

        for try await frame in try ScriptProcess(url: url, limit: 5).start() {
            XCTAssertEqual(frame, "part=a\n")
            break
        }

        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
    }

    func testEndingTheStreamStopsTheScript() async throws {
        let marker = folder.appendingPathComponent("alive")
        let url = try script("printf 'part=a\\n---\\n'\nsleep 0.3\ntouch '\(marker.path)'")

        for try await _ in try ScriptProcess(url: url, limit: 5).start() { break }
        try await Task.sleep(for: .seconds(0.5))

        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    func testOnlyTheFirstFrameHasATimeLimit() async throws {
        let release = folder.appendingPathComponent("release").path
        let gate = "n=0; while [ ! -f '\(release)' ] && [ $n -lt 1500 ]; do sleep 0.02; n=$((n + 1)); done"
        let silent = try script("sleep 30", name: "silent")
        let slow = try script("printf 'part=a\\n---\\n'\n\(gate)\nprintf 'part=b\\n---\\n'", name: "slow")
        var frames = try ScriptProcess(url: slow, limit: 1.5).start().makeAsyncIterator()
        let first = try await frames.next()

        do {
            for try await _ in try ScriptProcess(url: silent, limit: 1.5).start() {}
            XCTFail("It should time out.")
        } catch {
            XCTAssertEqual(error as? PluginError, .timedOut)
        }
        FileManager.default.createFile(atPath: release, contents: Data())
        let second = try await frames.next()

        XCTAssertEqual([first, second], ["part=a\n", "part=b\n"])
    }

    func testALaterFrameChangesOnlyThePartsItNames() throws {
        var panel = try XCTUnwrap(SheetParts(output: PluginOutput(text: "part=a\ntitle=A\n\npart=b\ntitle=B\n")))

        panel.merge(PluginOutput(text: "part=b\ntitle=New\n"))
        XCTAssertEqual(panel.parts.map(\.title), ["A", "New"])

        panel.merge(PluginOutput(text: "part=c\ntitle=C\n"))
        XCTAssertEqual(panel.parts.map(\.id), ["a", "b", "c"])
    }

    func testAFrameWithALayoutReplacesTheSheet() throws {
        var panel = try XCTUnwrap(SheetParts(output: PluginOutput(text: "part=a\ntitle=A\n\npart=b\ntitle=B\n")))

        panel.merge(PluginOutput(text: "grid=c\n\npart=c\ncell=c\ntitle=C\n"))

        XCTAssertEqual(panel.parts.map(\.id), ["c"])
        XCTAssertNotNil(panel.layout)
    }

    func testAFrameKeepsTheTextThePersonIsTyping() throws {
        var panel = try XCTUnwrap(SheetParts(output: PluginOutput(text: "part=a\ntext=typed\n")))

        panel.merge(PluginOutput(text: "part=a\ntext=old\n"), keeping: "a")

        XCTAssertEqual(panel.parts.first?.value, "typed")
    }

    func testEventsAreBlocks() {
        XCTAssertEqual(SpotAction.read.event(), "name=read\n\n")
        XCTAssertEqual(SpotAction.press("swap").event(), "name=swap\n\n")
        XCTAssertEqual(SpotAction.set("input", to: "one\ntwo").event(), "name=input\nvalue=one\\ntwo\n\n")
        XCTAssertEqual(SpotAction.drop(paths: ["/a b.mov", "-rf.mov"]).event(), "name=drop\nvalue=/a b.mov\nvalue=-rf.mov\n\n")
    }

    func testAnEventHoldsEachValueOfTheSheet() {
        let values = "input=one\\ntwo\nsource=auto\n"

        XCTAssertEqual(
            SpotAction.set("source", to: "auto").event(values: values),
            "name=source\nvalue=auto\nfield.input=one\\ntwo\nfield.source=auto\n\n"
        )
    }

    func testALiveScriptAnswersEachEventAndKeepsItsState() async throws {
        let url = try script("""
        count=0
        while IFS= read -r line; do
          [ -n "$line" ] || { count=$((count + 1)); printf 'part=a\\ntitle=%s\\n---\\n' "$count"; }
        done
        """)
        let live = ScriptProcess(url: url, mode: .stays, limit: 5)
        var frames = try live.start().makeAsyncIterator()

        live.send(.read)
        let first = try await frames.next()
        live.send(.press("a"))
        let second = try await frames.next()

        XCTAssertEqual(first, "part=a\ntitle=1\n")
        XCTAssertEqual(second, "part=a\ntitle=2\n")
        live.end()
    }

    func testAScriptThatIgnoresTheEndOfItsInputIsStopped() async throws {
        let url = try script("trap '' HUP\n\(String.longLoop)")
        let live = ScriptProcess(url: url, mode: .stays, limit: 5, stopPause: 0.2)
        _ = try live.start()

        live.end()
        try await wait(until: { !live.isRunning })
    }

    func testAScriptThatStaysIsAList() throws {
        let url = try script("# stay=true\n# read=panel")
        let command = try XCTUnwrap(try Plugin(file: url, id: "script")).commands.first

        XCTAssertEqual(command?.stays, true)
        XCTAssertEqual(command?.kind, .list)
        XCTAssertEqual(command?.readsState, false)
    }

    func testAPlainFirstReadOfAStayingScriptGivesItsFirstFrame() async throws {
        let url = try script("# stay=true\nwhile IFS= read -r line; do [ -n \"$line\" ] || printf 'part=a\\ntitle=A\\n---\\n'; done")
        let command = Spot(id: "a", name: "A", url: url, kind: .list, stays: true)

        let output = try await command.items(timeout: 5)

        XCTAssertEqual(output.parts.map(\.id), ["a"])
    }
}
