import XCTest
@testable import OpenspotCore

/// Proves the Account spot of the app: with no account it offers to set one up, and with one it shows the account, its
/// backup and its buttons, each of which opens the account window through the API.
final class AccountSpotTests: BuiltInCase {
    private var account: Spot {
        get throws {
            try spot("account")
        }
    }

    private var store: AccountStore {
        AccountStore.standard(environment: ["OPENSPOT_CONFIG": root.path], home: root, devState: nil)
    }

    private func items() async throws -> [SpotItem] {
        try await account.items(timeout: 5).items
    }

    @discardableResult
    private func call(_ arguments: [String]) async throws -> String? {
        try await account.perform(SpotAction(arguments: arguments), timeout: 5)
    }

    func testSearchFindsIt() throws {
        let spot = try account

        XCTAssertEqual(spot.name, "Account")
        XCTAssertEqual(spot.kind, .list)
        XCTAssertTrue(spot.isFound)
        XCTAssertTrue(spot.isBuiltIn)
    }

    func testWithNoAccountItOffersToSetOneUp() async throws {
        let rows = try await items()

        XCTAssertEqual(rows.map(\.run), ["account"])
        XCTAssertEqual(rows.first?.title, "Set up your account")
        try await call(["open", "account"])
        let opened = await app.opened
        XCTAssertEqual(opened, ["account"])
    }

    func testWithAnAccountItShowsItsIDAndItsBackupAndEachOpensTheSheet() async throws {
        let key = try store.keyMadeOnce()

        let rows = try await items()

        XCTAssertEqual(rows.map(\.run), ["account", "backup"])
        XCTAssertEqual(rows[0].title, "Your account")
        XCTAssertEqual(rows[0].subtitle, String(key.npub.prefix(12)) + "…" + String(key.npub.suffix(6)))
        XCTAssertEqual(rows[1].title, "Back up your words")
        try store.markBackedUp()
        let backedUp = try await items()
        XCTAssertEqual(backedUp[1].title, "Backed up")
        try await call(["open", "backup"])
        let opened = await app.opened
        XCTAssertEqual(opened, ["account"])
    }
}
