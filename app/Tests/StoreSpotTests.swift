import XCTest
@testable import OpenspotCore

/// Proves the Store spot of the app: a window of every spot from `openspot store list`, where Return gets a spot that the
/// person lacks and Publish publishes one of their own, each through the API.
final class StoreSpotTests: BuiltInCase {
    private var store: Spot {
        get throws {
            try spot("store")
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        try "#!/bin/sh\n# detail=Counts down\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"))
        try "#!/bin/sh\n# title=Shared\n".writeScript(to: root.appendingPathComponent("store/shared.spot/shared.sh"))
        try "#!/bin/sh\n# title=Mine\n".writeScript(to: spots.appendingPathComponent("mine.spot/mine.sh"))
    }

    private func items() async throws -> [SpotItem] {
        try await store.items(timeout: 5).items
    }

    @discardableResult
    private func call(_ arguments: [String]) async throws -> String? {
        try await store.perform(SpotAction(arguments: arguments), timeout: 5)
    }

    func testItOpensInAWindowAndTheSearchFindsIt() throws {
        let spot = try store

        XCTAssertEqual(spot.name, "Store")
        XCTAssertTrue(spot.offersWindow)
        XCTAssertTrue(spot.offersCard)
        XCTAssertEqual(spot.kind, .list)
    }

    func testItListsEachSpotWithACheckOnTheOnesYouHave() async throws {
        let rows = try await items()

        XCTAssertEqual(rows.map(\.run), ["mine", "shared", "timer"])
        XCTAssertEqual(rows.map(\.isOn), [true, false, false])
        XCTAssertEqual(rows.first { $0.run == "mine" }?.subtitle, "Not published")
        XCTAssertEqual(rows.first { $0.run == "timer" }?.subtitle, "Counts down")
    }

    func testReturnTurnsOnACoreSpotAndAddsAStoredOne() async throws {
        let ids = try await items().map(\.run)
        XCTAssertTrue(ids.contains("timer"))

        try await call(["open", "timer"])
        XCTAssertTrue(file.read().arrangement.enabled.contains("timer"))

        try await call(["open", "shared"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.appendingPathComponent("shared.spot/shared.sh").path))
    }

    func testPublishPublishesYourOwnSpotInTheApp() async throws {
        let rows = try await items()
        let id = try XCTUnwrap(rows.first { $0.subtitle == "Not published" }?.run)

        try await call(["publish", id])

        let opened = await app.opened
        XCTAssertEqual(opened, ["publish mine"])
    }
}
