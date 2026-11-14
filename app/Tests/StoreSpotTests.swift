import XCTest
@testable import OpenspotCore

/// Proves the Store spot of the app: a window with a gallery of every spot from `openspot store list`, where Get gets a spot
/// that the person lacks and Publish publishes one of their own, each through the API.
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

    /// The spots of the gallery, each as its id, name and button, in the order of the store's list.
    private func items() async throws -> [[String]] {
        let parts = try await store.items(timeout: 5).parts
        XCTAssertEqual(parts.map(\.id), ["gallery"])
        return (parts.first?.values["value"] ?? []).map { $0.split(separator: "\t").map(String.init) }
    }

    @discardableResult
    private func call(_ arguments: [String]) async throws -> String? {
        try await store.perform(SpotAction(arguments: arguments), timeout: 5)
    }

    func testItOpensInAWindowWithItsGalleryView() throws {
        let spot = try store

        XCTAssertEqual(spot.name, "Store")
        XCTAssertTrue(spot.offersWindow)
        XCTAssertTrue(spot.offersCard)
        XCTAssertEqual(spot.kind, .list)
        XCTAssertEqual(spot.view.map { URL(fileURLWithPath: $0).lastPathComponent }, "store.swift")
    }

    func testItListsEachSpotWithWhatItsButtonDoes() async throws {
        let rows = try await items()

        XCTAssertEqual(rows, [["mine", "Mine", "publish"], ["shared", "Shared", "get"], ["timer", "Timer", "get"]])
    }

    func testGetTurnsOnACoreSpotAndAddsAStoredOne() async throws {
        let ids = try await items().map { $0[0] }
        XCTAssertTrue(ids.contains("timer"))

        try await call(["gallery", "get:timer"])
        XCTAssertTrue(file.read().arrangement.enabled.contains("timer"))

        try await call(["gallery", "get:shared"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.appendingPathComponent("shared.spot/shared.sh").path))
        let rows = try await items()
        XCTAssertEqual(rows.first { $0[0] == "timer" }?[2], "added")
    }

    func testGetTurnsBackOnYourOwnSpotThatEditSpotsTurnedOff() async throws {
        try file.turn("mine", on: false)
        let before = try await items()
        XCTAssertEqual(before.first { $0[0] == "mine" }?[2], "get")

        try await call(["gallery", "get:mine"])

        XCTAssertEqual(file.read().arrangement.disabled, [])
    }

    func testPublishPublishesYourOwnSpotInTheApp() async throws {
        let rows = try await items()
        let id = try XCTUnwrap(rows.first { $0[2] == "publish" }?[0])

        try await call(["gallery", "publish:\(id)"])

        let opened = await app.opened
        XCTAssertEqual(opened, ["publish mine"])
    }
}
