import XCTest
@testable import OpenspotCore

/// Proves that `openspot spot run` makes a call as the app makes it, and gives back all that the script printed.
@MainActor
final class TerminalRunTests: XCTestCase {
    private var folder: URL!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-terminal-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func spot(_ name: String, header: String = "", _ body: String) throws -> Spot {
        let lines = header.split(separator: "\n").map { "# \($0)" }.joined(separator: "\n")
        try "#!/bin/sh\n\(lines)\n\(body)\n".writeScript(to: folder.appendingPathComponent("\(name).sh"))
        return try XCTUnwrap(SpotFolder(url: folder).scan().scripts.first { $0.id == name })
    }

    func testARunGivesTheArgumentsTheInputAndTheIDAndReturnsEachFrameAndTheExit() async throws {
        let spot = try spot("echo", "printf 'args=%s\\nid=%s\\n---\\n' \"$*\" \"$OPENSPOT_ID\"; cat; echo 'Nothing to send.' >&2; exit 2")
        var frames: [String] = []

        let end = await TerminalRun(spot: spot, arguments: ["open", "home"], input: "note=hi\n").start { frames.append($0) }

        XCTAssertEqual(frames.first, "args=open home\nid=echo\n")
        XCTAssertEqual(frames.last, "note=hi\n")
        XCTAssertEqual(end.code, 2)
        XCTAssertEqual(end.errors, "Nothing to send.\n")
    }

    func testARunReturnsAllOfALongStderr() async throws {
        let spot = try spot("loud", "i=0\nwhile [ $i -lt 5000 ]; do echo \"line $i of a log that runs long\" >&2; i=$((i+1)); done\nexit 1")

        let end = await TerminalRun(spot: spot, arguments: [], input: nil).start { _ in }

        XCTAssertTrue(end.errors.hasPrefix("line 0 of a log that runs long\n"))
        XCTAssertTrue(end.errors.hasSuffix("line 4999 of a log that runs long\n"))
    }

    func testARunWithNoCallReadsASpotThatReadsAndOpensOneThatDoesNot() async throws {
        let reads = try spot("reads", header: "read=sheet", "echo \"$1 $OPENSPOT_REASON\"")
        let opens = try spot("opens", "echo \"$1\"")
        var said: [String] = []

        _ = await TerminalRun(spot: reads, arguments: [], input: nil).start { said.append($0) }
        _ = await TerminalRun(spot: opens, arguments: [], input: nil).start { said.append($0) }

        XCTAssertEqual(said, ["read sheet\n", "open\n"])
    }

    func testARunOfAStayingScriptEndsWithTheFrameThatEndsItsCall() async throws {
        let spot = try spot("relay", header: "mode=stay", """
        . "$OPENSPOT_SH"
        main() { printf 'text=peer\\ntitle=%s\\n' "$1"; }
        openspot_serve main "$@"
        """)
        var frames: [String] = []

        let end = await TerminalRun(spot: spot, arguments: ["ping"], input: nil).start { frames.append($0) }

        XCTAssertEqual(frames, ["text=peer\ntitle=ping\n\n"])
        XCTAssertEqual(end.code, 0)
    }
}
