import XCTest
@testable import OpenspotCore

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

    private func spot(_ name: String, toml: String = "", _ body: String) throws -> Spot {
        try TestSpot(toml: toml, body: "\(body)").write(to: folder.spotFile(name))
        return try XCTUnwrap(SpotsFolder(url: folder).scan().scripts.first { $0.id == name })
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

    func testARunRefusesASpotThatReachesTheAccountKey() async throws {
        let ran = folder.appendingPathComponent("ran")
        var store = try spot("store", toml: "uses = ['account']", "touch '\(ran.path)'; echo title=Store")
        store = store.builtIn()
        store.uses.insert(.account)
        var frames: [String] = []

        let end = await TerminalRun(spot: store, arguments: ["show"], input: nil).start { frames.append($0) }

        XCTAssertEqual(end, TerminalRun.End(code: 1, errors: "Store reaches your account key, so it runs only in the Openspot panel. Open it there.\n"))
        XCTAssertEqual(frames, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: ran.path))
    }

    func testARunReturnsAllOfALongStderr() async throws {
        let spot = try spot("loud", "i=0\nwhile [ $i -lt 5000 ]; do echo \"line $i of a log that runs long\" >&2; i=$((i+1)); done\nexit 1")

        let end = await TerminalRun(spot: spot, arguments: [], input: nil).start { _ in }

        XCTAssertTrue(end.errors.hasPrefix("line 0 of a log that runs long\n"))
        XCTAssertTrue(end.errors.hasSuffix("line 4999 of a log that runs long\n"))
    }

    func testARunKeepsTheEndOfAStderrOverItsLimit() async throws {
        let spot = try spot("flood", "head -c 3000000 /dev/zero | tr '\\0' 'a' >&2\necho ' the end' >&2\nexit 1")

        let end = await TerminalRun(spot: spot, arguments: [], input: nil).start { _ in }

        XCTAssertLessThanOrEqual(end.errors.utf8.count, 2 * TerminalRun.errorLimit)
        XCTAssertTrue(end.errors.hasSuffix("a the end\n"))
    }

    func testARunWithNoCallShowsASpotWithASheetAndOpensOneWithCommandsAndNoEvents() async throws {
        let reads = try spot("reads", "\(TestSpot.event)\necho \"$1 $ev\"")
        let opens = try spot("opens", toml: "[commands.left]\ntitle = 'Left'", "echo \"$1\"")
        var said: [String] = []

        _ = await TerminalRun(spot: reads, arguments: [], input: nil).start { said.append($0) }
        _ = await TerminalRun(spot: opens, arguments: [], input: nil).start { said.append($0) }

        XCTAssertEqual(said, ["show sheet.open\n", "open\n"])
    }

    func testARunOfAStayingScriptEndsWithTheFrameThatEndsItsCall() async throws {
        let spot = try spot("relay", toml: "mode = 'stay'", """
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
