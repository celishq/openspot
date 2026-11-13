import XCTest
@testable import OpenspotCore

/// Proves the Playground spot of the app: search finds it by its name or as sandbox, it has no card on the grid, and a press
/// opens the playground.
final class PlaygroundSpotTests: BuiltInCase {
    func testAPressOpensThePlayground() async throws {
        let spot = try spot("playground")

        _ = try await spot.perform(spot.click, timeout: 5)

        let opened = await app.opened
        XCTAssertEqual(opened, ["sandbox  careful=false"])
    }

    func testSearchFindsItAndItLeavesTheGrid() throws {
        let spot = try spot("playground")
        let defaults = Config(text: try String(contentsOf: repoSpots.deletingLastPathComponent().appendingPathComponent("app/defaults.toml"), encoding: .utf8))

        XCTAssertEqual(spot.kind, .launch)
        XCTAssertEqual(spot.name, "Playground")
        XCTAssertEqual(spot.keywords, ["sandbox"])
        XCTAssertTrue(spot.isFound)
        XCTAssertEqual(defaults.arrangement.isOnGrid(of: spot.id), false)
    }
}
