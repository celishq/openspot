import XCTest
@testable import OpenspotCore

/// Proves that an MCP server on stdio becomes a spot: its tools are actions, and its resources are rows (F10).
@MainActor
final class McpSpotTests: XCTestCase {
    private var folder: URL!
    private var runs: SpotRuns!

    private static let server = #"""
    #!/bin/sh
    # name=Notes
    # mcp=true
    while IFS= read -r line; do
      printf '%s\n' "$line" >> "$(dirname "$0")/requests"
      id=$(printf '%s' "$line" | sed -n 's/.*"id":\([0-9]*\).*/\1/p')
      case "$line" in
        *'"method":"initialize"'*)
          printf '{"jsonrpc":"2.0","id":%s,"result":{"protocolVersion":"2025-06-18","capabilities":{"tools":{},"resources":{}},"serverInfo":{"name":"notes","version":"1"}}}\n' "$id" ;;
        *'"method":"tools/list"'*)
          printf '{"jsonrpc":"2.0","id":%s,"result":{"tools":[{"name":"echo","title":"Echo","inputSchema":{"type":"object","properties":{"text":{"type":"string","title":"Text"},"times":{"type":"integer"}},"required":["text"]}},{"name":"ping","inputSchema":{"type":"object"}}]}}\n' "$id" ;;
        *'"method":"resources/list"'*)
          printf '{"jsonrpc":"2.0","id":%s,"result":{"resources":[{"uri":"note://a","name":"Note A","description":"The first note"}]}}\n' "$id" ;;
        *'"method":"tools/call"'*)
          text=$(printf '%s' "$line" | sed -n 's/.*"text":"\([^"]*\)".*/\1/p')
          times=$(printf '%s' "$line" | sed -n 's/.*"times":\([0-9]*\).*/\1/p')
          printf '{"jsonrpc":"2.0","id":%s,"result":{"content":[{"type":"text","text":"You said %s %s times"}]}}\n' "$id" "$text" "$times" ;;
        *'"method":"resources/read"'*)
          printf '{"jsonrpc":"2.0","id":%s,"result":{"contents":[{"uri":"note://a","text":"Hello from A"}]}}\n' "$id" ;;
      esac
    done
    """#

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-mcp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        runs = SpotRuns(stopPause: 0.2)
        try Self.server.writeScript(to: folder.appendingPathComponent("notes.sh"))
    }

    override func tearDown() async throws {
        runs.quit()
        try? FileManager.default.removeItem(at: folder)
    }

    private func spot() throws -> Spot {
        let scan = try PluginFolder(url: folder).scan()
        XCTAssertEqual(scan.refused, [])
        return try XCTUnwrap(scan.scripts.first)
    }

    func testTheHeaderMakesAListThatReadsWhenItsSheetOpensAndAScanStartsNothing() throws {
        let spot = try spot()

        XCTAssertTrue(spot.isMcp)
        XCTAssertEqual(spot.kind, .list)
        XCTAssertEqual(spot.read, .sheet)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("requests").path))
    }

    func testAReadListsEachToolAsAnActionAndEachResourceAsARow() async throws {
        let output = PluginOutput(text: try await runs.answer(of: try spot(), .read))

        XCTAssertEqual(output.actions, [
            CommandAction(id: "echo", title: "Echo", scope: .command, isForm: true),
            CommandAction(id: "ping", title: "ping", scope: .command)
        ])
        XCTAssertEqual(output.items, [SpotItem(title: "Note A", subtitle: "The first note", run: "note://a")])
        XCTAssertEqual(output.errors, [])
    }

    func testAToolWithInputAsksForItsFieldsThenCallsWithTheirValues() async throws {
        let spot = try spot()

        let fields = try await runs.answer(of: spot, SpotAction(arguments: ["echo"]))
        let form = try XCTUnwrap(ItemForm(output: PluginOutput(text: fields)))
        let answer = PluginOutput(text: try await runs.answer(of: spot, SpotAction(arguments: ["echo"]), input: "text=hi\ntimes=3\n"))

        XCTAssertEqual(form.fields.map(\.name), ["text", "times"])
        XCTAssertEqual(form.fields.map(\.label), ["Text", "times"])
        XCTAssertEqual(answer.toast, "You said hi 3 times")
        let requests = try String(contentsOf: folder.appendingPathComponent("requests"), encoding: .utf8)
        XCTAssertTrue(requests.contains(#""arguments":{"text":"hi","times":3}"#))
    }

    func testAPickReadsTheResource() async throws {
        let answer = PluginOutput(text: try await runs.answer(of: try spot(), .item(SpotItem(title: "Note A", run: "note://a"))))

        XCTAssertEqual(answer.toast, "Hello from A")
    }
}
