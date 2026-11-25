import XCTest
@testable import OpenspotCore

@MainActor
final class ShippedChipRowsTests: AttachmentCase {
    private var repo: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func rows(of words: String) async throws -> [String] {
        for path in ["spots/links.spot", "spots/snippets.spot", "examples/snooze-tab.spot"] {
            try FileManager.default.copyItem(at: repo.appendingPathComponent(path), to: spots.appendingPathComponent(URL(fileURLWithPath: path).lastPathComponent))
        }
        try source(adds: words)
        await open()
        try await wait("the value of the chip") { self.chips.first?.value != nil }
        XCTAssertTrue(model.handleKey(ActionKey(name: "tab")))
        return model.visible.map { "\($0.state.title) · \($0.state.subtitle ?? "")" }
    }

    func testALinkChipOffersTheVerbsOfLinksAndSnoozeTab() async throws {
        let shown = try await rows(of: "url=https://example.com/a title=A app=com.apple.Safari")

        XCTAssertEqual(shown, ["Add to Links · Links", "Snooze until tomorrow · Snooze Tab", "Snooze until the weekend · Snooze Tab", "Snooze until next week · Snooze Tab"])
    }

    func testATextChipOffersSaveAsASnippet() async throws {
        let shown = try await rows(of: "text=Dear\\ Ann title=Selected")

        XCTAssertEqual(shown, ["Save as a snippet · Snippets"])
    }
}
