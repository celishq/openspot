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

    private func script(_ body: String) throws -> URL {
        let url = folder.appendingPathComponent("script.sh")
        try "#!/bin/sh\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    func testAMarkEndsAFrameWhereverAChunkStops() {
        var reader = SheetFrameReader()

        XCTAssertEqual(reader.read(Data("part=a\n-".utf8)), [])
        XCTAssertEqual(reader.read(Data("--\npart=".utf8)), ["part=a\n"])
        XCTAssertEqual(reader.read(Data("b".utf8)), [])
        XCTAssertEqual(reader.finish(), "part=b")
        XCTAssertNil(reader.finish())
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
        let url = try script("printf 'part=a\\n---\\n'\nsleep 2\ntouch '\(marker.path)'")

        for try await _ in try ScriptProcess(url: url, limit: 5).start() { break }
        try await Task.sleep(for: .seconds(3))

        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    func testOnlyTheFirstFrameHasATimeLimit() async throws {
        let silent = try script("sleep 30")
        do {
            for try await _ in try ScriptProcess(url: silent, limit: 0.3).start() {}
            XCTFail("It should time out.")
        } catch {
            XCTAssertEqual(error as? PluginError, .timedOut)
        }

        let slow = try script("printf 'part=a\\n---\\n'\nsleep 1\nprintf 'part=b\\n---\\n'")
        var frames: [String] = []
        for try await frame in try ScriptProcess(url: slow, limit: 0.3).start() { frames.append(frame) }
        XCTAssertEqual(frames, ["part=a\n", "part=b\n"])
    }

    func testAFailureReportsItsLastErrorLine() async throws {
        let url = try script("echo first >&2\necho last >&2\nexit 3")
        do {
            for try await _ in try ScriptProcess(url: url, limit: 5).start() {}
            XCTFail("It should fail.")
        } catch {
            XCTAssertEqual(error as? PluginError, .failed(3, "last"))
        }
    }

    func testALaterFrameChangesOnlyThePartsItNames() throws {
        var panel = try XCTUnwrap(SpotPanel(output: PluginOutput(text: "part=a\ntitle=A\n\npart=b\ntitle=B\n")))

        panel.merge(PluginOutput(text: "part=b\ntitle=New\n"))
        XCTAssertEqual(panel.parts.map(\.title), ["A", "New"])

        panel.merge(PluginOutput(text: "part=c\ntitle=C\n"))
        XCTAssertEqual(panel.parts.map(\.id), ["a", "b", "c"])
    }

    func testAFrameWithALayoutReplacesTheSheet() throws {
        var panel = try XCTUnwrap(SpotPanel(output: PluginOutput(text: "part=a\ntitle=A\n\npart=b\ntitle=B\n")))

        panel.merge(PluginOutput(text: "grid=c\n\npart=c\ncell=c\ntitle=C\n"))

        XCTAssertEqual(panel.parts.map(\.id), ["c"])
        XCTAssertNotNil(panel.layout)
    }

    func testAFrameKeepsTheTextThePersonIsTyping() throws {
        var panel = try XCTUnwrap(SpotPanel(output: PluginOutput(text: "part=a\ntext=typed\n")))

        panel.merge(PluginOutput(text: "part=a\ntext=old\n"), keeping: "a")

        XCTAssertEqual(panel.parts.first?.value, "typed")
    }

    func testEventsAreBlocks() {
        XCTAssertEqual(SpotAction.read.event(), "name=read\n\n")
        XCTAssertEqual(SpotAction.press("swap").event(), "name=swap\n\n")
        XCTAssertEqual(SpotAction.set("input", to: "one\ntwo").event(), "name=input\nvalue=one\\ntwo\n\n")
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

    func testAnEventSentJustBeforeTheStopStillRuns() async throws {
        let marker = folder.appendingPathComponent("copied")
        let url = try script("""
        while IFS= read -r line; do
          case "$line" in name=copy) sleep 0.3; touch '\(marker.path)' ;; esac
        done
        """)
        let live = ScriptProcess(url: url, mode: .stays, limit: 5)
        _ = try live.start()

        live.send(.press("copy"))
        live.end()
        try await Task.sleep(for: .seconds(1))

        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
        XCTAssertFalse(live.isRunning)
    }

    func testAScriptThatIgnoresTheEndOfItsInputIsStopped() async throws {
        let url = try script("trap '' HUP\nwhile :; do sleep 0.1; done")
        let live = ScriptProcess(url: url, mode: .stays, limit: 5)
        _ = try live.start()

        live.end()
        try await Task.sleep(for: .seconds(4))

        XCTAssertFalse(live.isRunning)
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
        let command = PluginCommand(id: "a", name: "A", url: url, kind: .list, stays: true)

        let output = try await command.items(timeout: 5)

        XCTAssertEqual(output.parts.map(\.id), ["a"])
    }
}
