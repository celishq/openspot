import XCTest
@testable import OpenspotCore

final class QuitSpotTests: BuiltInCase {
    func testACardPressQuitsTheApp() async throws {
        let spot = try spot("quit")

        _ = try await spot.perform("quit", timeout: 60)

        let quits = await app.quits
        XCTAssertEqual(quits, 1)
    }

    func testItRunsAtOnceAndLeavesTheGrid() throws {
        let spot = try spot("quit")
        let defaults = Config(text: try String(contentsOf: repoSpots.deletingLastPathComponent().appendingPathComponent("app/defaults.toml"), encoding: .utf8))

        XCTAssertEqual(spot.mainAct, .command("quit"))
        XCTAssertEqual(spot.name, "Quit")
        XCTAssertEqual(spot.subtitle, "Openspot")
        XCTAssertTrue(spot.isFound)
        XCTAssertEqual(defaults.arrangement.isOnGrid(of: spot.id), false)
    }
}
