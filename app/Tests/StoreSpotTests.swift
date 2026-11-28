import XCTest
@testable import OpenspotCore

final class StoreSpotTests: BuiltInCase {
    private var store: Spot {
        get throws {
            try spot("store")
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        try "#!/bin/sh\n".writeScript(to: root.appendingPathComponent("store/clock.spot/clock.sh"), toml: "title = 'Clock'")
    }

    func testItsCardOpensTheStoreWindowOfTheApp() async throws {
        let spot = try store

        try await spot.perform("open", input: nil, timeout: 60)

        let opened = await app.opened
        XCTAssertEqual(opened, ["store"])
        XCTAssertNil(spot.views["store"])
        XCTAssertEqual(Config(text: try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("defaults.toml"), encoding: .utf8)).arrangement.isWindow(of: "openspot/store"), nil)
    }

    func testItsCardIsOnTheGridOfANewMac() throws {
        let defaults = Config(text: try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("defaults.toml"), encoding: .utf8))

        XCTAssertEqual(defaults.arrangement.isOnGrid(of: "openspot/store"), true)
    }

    func testASearchEndsWithARowThatLooksInTheStore() async throws {
        let spot = try store

        let rows = try await spot.answer("search", input: "input.text= pomodoro \n", timeout: 60).answers(asCard: false)

        XCTAssertEqual(try XCTUnwrap(spot.triggers.search).isLast, true)
        XCTAssertEqual(rows.map(\.run), ["pomodoro"])
        XCTAssertEqual(rows.map(\.title), ["Look in the Store for “pomodoro”"])
    }

    func testAPickOfThatRowOpensTheStoreWithTheWordsInItsSearch() async throws {
        try await store.perform("press", input: "input.item=pomodoro\n", timeout: 60)

        let opened = await app.opened
        XCTAssertEqual(opened, ["store search pomodoro"])
    }
}
