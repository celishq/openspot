import XCTest
@testable import OpenspotCore

@MainActor
final class SnoozeTabContextTests: ContextCase {
    private var example: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("examples/snooze-tab.spot")
    }

    private func openTab(dropping drop: Bool) async throws -> [String] {
        let copy = spots.appendingPathComponent("snooze-tab.spot")
        try FileManager.default.copyItem(at: example, to: copy)
        if !drop {
            let toml = copy.appendingPathComponent("spot.toml")
            let lines = try String(contentsOf: toml, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false)
            try lines.filter { !$0.hasPrefix("drop") }.joined(separator: "\n").write(to: toml, atomically: true, encoding: .utf8)
        }
        try taker(takes: "'url'")
        try source(adds: "url=https://example.com/a title=A app=com.apple.Safari")
        await open()
        try await wait("the value of the tab") { self.model.context.chips.first?.value != nil }
        XCTAssertTrue(model.handleKey(ActionKey(name: "tab")))
        return model.visible.map(\.state.title)
    }

    func testTheTabChipOffersSnoozeTab() async throws {
        let shown = try await openTab(dropping: true)

        XCTAssertEqual(Set(shown), ["keep", "Snooze Tab"])
    }

    func testACopyOfSnoozeTabWithNoDropIsNotOffered() async throws {
        let shown = try await openTab(dropping: false)

        XCTAssertEqual(Set(shown), ["keep"])
    }
}
