import XCTest
@testable import OpenspotCore

/// Proves the Account spot of the app: it draws each step of the account in its view, from the facts of `openspot
/// account`, and only it reaches the key, which a test keeps in a file of its own.
final class AccountSpotTests: BuiltInCase {
    private let phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    private var account: Spot {
        get throws {
            try spot("account")
        }
    }

    private var store: AccountStore {
        AccountStore.standard(environment: ["OPENSPOT_CONFIG": root.path], home: root, devState: nil)
    }

    /// The frame that a call of the spot prints: a read as the open sheet or the panel asks it, or a press.
    private func frame(_ arguments: [String], reason: String = "sheet.open") async throws -> String {
        let variables = arguments == ["read"] ? ["OPENSPOT_REASON": reason] : [:]
        return try await runs.answer(of: account, SpotAction(arguments: arguments), limit: 10, variables: variables)
    }

    private func values(_ key: String, in frame: String) -> [String] {
        frame.split(separator: "\n").filter { $0.hasPrefix("\(key)=") }.map { String($0.dropFirst(key.count + 1)) }
    }

    func testSearchFindsItAndItShipsWithTheApp() throws {
        let spot = try account

        XCTAssertEqual(spot.name, "Account")
        XCTAssertTrue(spot.isFound)
        XCTAssertTrue(spot.isBuiltIn)
        XCTAssertTrue(spot.uses.contains(.account))
        XCTAssertNotNil(spot.view)
    }

    func testWithNoAccountItOffersToSetOneUpWithTheMainButtonOnTop() async throws {
        let read = try await frame(["read"])

        XCTAssertTrue(read.hasPrefix("grid=steps\ngrid=create\ngrid=sign_in\n"), read)
        XCTAssertEqual(values("step", in: read), ["choose"])
    }

    func testCreateSaysWhatTheWordsAreThenShowsTheWordsOfANewKey() async throws {
        let about = try await frame(["create"])
        XCTAssertEqual(values("step", in: about), ["about"])
        XCTAssertNil(try store.key())

        let words = try await frame(["show"])

        XCTAssertEqual(values("word", in: words), try store.key()?.words)
        let asked = await app.asked
        XCTAssertEqual(asked, ["show your account words"])
    }

    func testTwoRightPicksBackTheWordsUp() async throws {
        let key = try store.keyMadeOnce()
        let words = try XCTUnwrap(key.words)
        _ = try await frame(["show"])

        let check = try await frame(["wrote"])
        let places = values("check", in: check).compactMap(Int.init)
        XCTAssertEqual(places.count, 2)
        XCTAssertEqual(values("choice", in: check).count, 8)
        let picks = places.map { "\($0) \(words[$0 - 1])" }.joined(separator: " ")
        let done = try await frame(["steps", "checked \(picks)"])

        XCTAssertTrue(try store.isBackedUp())
        XCTAssertEqual(values("step", in: done), ["account"])
        XCTAssertEqual(values("toast", in: done), ["Your words are backed up"])
    }

    func testAWrongPickSaysWhichWord() async throws {
        let key = try store.keyMadeOnce()
        let words = try XCTUnwrap(key.words)
        _ = try await frame(["show"])
        let check = try await frame(["wrote"])
        let places = values("check", in: check).compactMap(Int.init)

        let wrong = try await frame(["steps", "checked \(places[0]) \(words[places[0] % 12]) \(places[1]) \(words[places[1] - 1])"])

        XCTAssertEqual(values("mistake", in: wrong), ["That isn't word \(places[0]). Look at your words again."])
        XCTAssertFalse(try store.isBackedUp())
    }

    func testAPhraseShowsHowFarItIsAndSignsIn() async throws {
        _ = try await frame(["sign_in"])

        let typing = try await frame(["steps", "phrase \(phrase)"])
        let signedIn = try await frame(["steps", "sign-in \(phrase)"])

        XCTAssertEqual(values("counter", in: typing), ["12 of 12"])
        XCTAssertEqual(values("account", in: typing), [try AccountKey(words: phrase.split(separator: " ").map(String.init)).npub])
        XCTAssertEqual(values("toast", in: signedIn), ["Signed in"])
        XCTAssertEqual(values("step", in: signedIn), ["account"])
        XCTAssertTrue(try store.isBackedUp())
    }

    func testAReadAsThePanelOpensNeverAsksForTouchID() async throws {
        _ = try store.keyMadeOnce()
        _ = try await frame(["show"])
        let before = await app.asked

        _ = try await frame(["read"], reason: "panel.open")

        let after = await app.asked
        XCTAssertEqual(after, before)
    }

    func testSignOutAsksForTouchIDAndRemovesTheKey() async throws {
        _ = try store.keyMadeOnce()
        try store.markBackedUp()

        let leave = try await frame(["leave"])
        let out = try await frame(["sign_out"])

        XCTAssertEqual(values("step", in: leave), ["leave"])
        XCTAssertNil(try store.key())
        XCTAssertEqual(values("step", in: out), ["choose"])
        let asked = await app.asked
        XCTAssertEqual(asked, ["sign out of your account"])
    }
}
