import XCTest
@testable import OpenspotCore

final class QuitSpotTests: BuiltInCase {
    func testACardPressQuitsTheApp() async throws {
        let spot = try spot("quit")

        _ = try await spot.perform(spot.click, timeout: 5)

        let quits = await app.quits
        XCTAssertEqual(quits, 1)
    }

    func testItRunsAtOnceAndLeavesTheGrid() throws {
        let spot = try spot("quit")
        let defaults = Config(text: try String(contentsOf: repoSpots.deletingLastPathComponent().appendingPathComponent("app/defaults.toml"), encoding: .utf8))

        XCTAssertEqual(spot.kind, .launch)
        XCTAssertEqual(spot.name, "Quit")
        XCTAssertEqual(spot.subtitle, "Openspot")
        XCTAssertTrue(spot.isFound)
        XCTAssertEqual(defaults.arrangement.isOnGrid(of: spot.id), false)
    }
}
