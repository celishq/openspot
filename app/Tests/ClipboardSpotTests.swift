import XCTest
@testable import OpenspotCore

final class ClipboardSpotTests: BuiltInCase {
    private var log: URL {
        root.appendingPathComponent("added")
    }

    func testACopyGoesToTheTimelineWithItsKeyInTheValueAndItsPeekAfterIt() async throws {
        try fake("openspot", """
        case "$1 $2" in
          "clipboard read") printf 'text=#FF3B30\\n\\npeek=color\\n\\ntext=hex\\nparent=color\\ntitle=#FF3B30\\n' ;;
          "timeline add") cat > '\(log.path)' ;;
        esac
        """)
        let place = SpotsFolder(url: root.appendingPathComponent("none"), core: repoSpots)
        let clipboard = try XCTUnwrap(try place.scan().scripts.first { $0.id == "clipboard" })

        _ = try await clipboard.answer("clipboard.change", input: "setting.history=true\n", timeout: 60)

        let blocks = TextBlock.blocks(in: try String(contentsOf: log, encoding: .utf8))
        XCTAssertEqual(blocks.map(\.firstLine), ["text=#FF3B30", "peek=color", "text=hex"])
        XCTAssertEqual(blocks.first?.value("key")?.count, 16)
        XCTAssertNil(blocks.last?.value("key"))
    }
}
