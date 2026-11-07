import XCTest
@testable import OpenspotCore

@MainActor
final class QuitSpotTests: XCTestCase {
    private actor Presses {
        var count = 0
        func press() { count += 1 }
    }

    private let folder = URL(fileURLWithPath: "/tmp")

    func testACardPressQuitsTheApp() async throws {
        let presses = Presses()
        let commands = ShippedSpot.commands(folder: folder, guide: folder, app: "", quit: QuitSpot { await presses.press() })
        let spot = try XCTUnwrap(commands.first { $0.name == "Quit Openspot" })

        _ = try await spot.perform(spot.click, timeout: 1)

        let count = await presses.count
        XCTAssertEqual(count, 1)
    }

    func testItRunsAtOnceAndLeavesTheGrid() throws {
        let commands = ShippedSpot.commands(folder: folder, guide: folder, app: "", quit: QuitSpot {})
        let spot = try XCTUnwrap(commands.first { $0.id == ShippedSpot.quitID })

        XCTAssertEqual(spot.kind, .launch)
        XCTAssertFalse(spot.isOnGrid)
        XCTAssertTrue(spot.hasSpot)
    }

    func testABuildWithNoQuitHasNoSuchSpot() {
        let commands = ShippedSpot.commands(folder: folder, guide: folder, app: "")

        XCTAssertFalse(commands.contains { $0.id == ShippedSpot.quitID })
    }
}
