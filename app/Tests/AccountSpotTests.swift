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

        XCTAssertEqual(rows.map(\.run), ["set_up"])
        XCTAssertEqual(rows.first?.title, "Set up your account")
        try await call(["open", "set_up"])
        let opened = await app.opened
        XCTAssertEqual(opened, ["account set-up"])
    }

    func testWithAnAccountItShowsItsIDItsBackupAndSignOut() async throws {
        let key = try store.keyMadeOnce()

        let rows = try await items()

        XCTAssertEqual(rows.map(\.run), ["npub", "words", "sign_out"])
        XCTAssertEqual(rows[0].subtitle, String(key.npub.prefix(12)) + "…" + String(key.npub.suffix(6)))
        XCTAssertEqual(rows[1].title, "Back up your words")
        XCTAssertEqual(rows[1].subtitle, "Not backed up")
        try store.markBackedUp()
        let backedUp = try await items()
        XCTAssertEqual(backedUp[1].title, "Show your words")
        XCTAssertEqual(backedUp[1].subtitle, "Backed up")
    }

    func testEachButtonOpensItsStepOfTheWindow() async throws {
        _ = try store.keyMadeOnce()

        try await call(["open", "words"])
        try await call(["open", "sign_out"])

        let opened = await app.opened
        XCTAssertEqual(opened, ["account words", "account sign-out"])
    }
}
