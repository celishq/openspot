import XCTest
@testable import OpenspotCore

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

    private func frame(_ arguments: [String], input: String? = nil, reason: String = "sheet.open") async throws -> String {
        let variables = arguments == ["read"] ? ["OPENSPOT_REASON": reason] : [:]
        return try await runs.answer(of: account, SpotAction(arguments: arguments), input: input, limit: 10, variables: variables)
    }

    private func block(_ id: String, in frame: String) -> [String: String] {
        let found = frame.components(separatedBy: "\n\n").first { $0.split(separator: "\n").contains { $0.hasSuffix("=\(id)") && !$0.hasPrefix("grid=") } }
        var keys: [String: String] = [:]
        for line in (found ?? "").split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 { keys[parts[0]] = parts[1] }
        }
        return keys
    }

    private func toast(in frame: String) -> String? {
        frame.split(separator: "\n").first { $0.hasPrefix("toast=") }.map { String($0.dropFirst(6)) }
    }

    private func words(in frame: String) -> [String] {
        (1...12).compactMap { block("w\($0)", in: frame)["title"] }
    }

    func testSearchFindsItAndItShipsWithTheApp() throws {
        let spot = try account

        XCTAssertEqual(spot.name, "Account")
        XCTAssertTrue(spot.isFound)
        XCTAssertFalse(spot.read?.has(.panel) == true)
        XCTAssertTrue(spot.reachesAccountKey)
        XCTAssertNil(spot.view)
    }

    func testWithNoAccountItOffersToSetOneUpWithTheMainButtonOnTop() async throws {
        let read = try await frame(["read"])

        XCTAssertTrue(read.hasPrefix("grid=head\ngrid=head\ngrid=create\ngrid=sign_in\n"), read)
        XCTAssertEqual(block("head", in: read)["title"], "Set up your account")
        XCTAssertEqual(block("create", in: read)["look"], "strong")
    }

    func testCreateSaysWhatTheWordsAreThenShowsTheWordsOfANewKey() async throws {
        let about = try await frame(["create"])
        XCTAssertEqual(block("head", in: about)["title"], "Your account is 12 words")
        XCTAssertNil(try store.key())

        let shown = try await frame(["show"])

        XCTAssertEqual(words(in: shown), try store.key()?.words)
        XCTAssertEqual(block("w12", in: shown)["icon"], "12.circle")
        let asked = await app.asked
        XCTAssertEqual(asked, ["show your account words"])
    }

    private func picks(in frame: String) -> [(place: Int, word: String)] {
        frame.split(separator: "\n").filter { $0.hasPrefix("button=pick-") }.map { line in
            let rest = line.dropFirst("button=pick-".count)
            let place = Int(rest.prefix { $0 != "-" }) ?? 0
            return (place, String(rest.drop { $0 != "-" }.dropFirst()))
        }
    }

    func testTwoRightPicksBackTheWordsUp() async throws {
        let words = try XCTUnwrap(try store.keyMadeOnce().words)
        _ = try await frame(["show"])

        let check = try await frame(["wrote"])
        let choices = picks(in: check)
        XCTAssertEqual(choices.count, 8)
        let places = Array(Set(choices.map(\.place))).sorted()
        let first = try await frame(["pick-\(places[0])-\(words[places[0] - 1])"])
        XCTAssertEqual(block("pick-\(places[0])-\(words[places[0] - 1])", in: first)["look"], "strong")
        let done = try await frame(["pick-\(places[1])-\(words[places[1] - 1])"])

        XCTAssertTrue(try store.isBackedUp())
        XCTAssertEqual(toast(in: done), "Your words are backed up")
        XCTAssertEqual(block("head", in: done)["title"], "Your account")
    }

    func testAWrongPickSaysWhichWord() async throws {
        let words = try XCTUnwrap(try store.keyMadeOnce().words)
        _ = try await frame(["show"])
        let check = try await frame(["wrote"])
        let choices = picks(in: check)
        let places = Array(Set(choices.map(\.place))).sorted()
        let wrong = try XCTUnwrap(choices.first { $0.place == places[0] && $0.word != words[places[0] - 1] })

        _ = try await frame(["pick-\(wrong.place)-\(wrong.word)"])
        let after = try await frame(["pick-\(places[1])-\(words[places[1] - 1])"])

        XCTAssertEqual(block("head", in: after)["title"], "That isn't word \(places[0]). Look at your words again.")
        XCTAssertFalse(try store.isBackedUp())
    }

    func testThePhraseNumbersItsWordsAsItIsTypedAndSignsIn() async throws {
        _ = try await frame(["sign_in"])

        let typing = try await frame(["phrase", "abandon abuot abso"])
        let ready = try await frame(["phrase", phrase])
        let signedIn = try await frame(["sign_in"], input: "phrase=\(phrase)\n")

        XCTAssertEqual(words(in: typing), ["abandon", "abuot", "abso"])
        XCTAssertEqual(block("w2", in: typing)["tone"], "bad")
        XCTAssertEqual(block("status", in: typing)["title"], "Did you mean absorb?")
        XCTAssertEqual(block("status", in: ready)["title"], "Signs in as")
        XCTAssertEqual(toast(in: signedIn), "Signed in")
        XCTAssertTrue(try store.isBackedUp())
    }

    func testAReadAtLaunchNeverShowsTheWordsNorAsksForTouchID() async throws {
        _ = try store.keyMadeOnce()
        _ = try await frame(["show"])
        let before = await app.asked

        let launch = try await frame(["read"], reason: "app.launch")
        let sheet = try await frame(["read"])

        let after = await app.asked
        XCTAssertEqual(after, before)
        XCTAssertTrue(words(in: launch).isEmpty)
        XCTAssertEqual(block("show", in: sheet)["title"], "Show my words")
    }

    func testAReadAsTheSheetOpensNeverAsksForTouchID() async throws {
        _ = try store.keyMadeOnce()
        _ = try await frame(["show"])
        let before = await app.asked

        _ = try await frame(["read"])

        let after = await app.asked
        XCTAssertEqual(after, before)
    }

    func testASheetThatOpensAgainOffersTheWordsAgainAndKeepsTheCheckWhole() async throws {
        _ = try store.keyMadeOnce()
        _ = try await frame(["show"])

        let reopened = try await frame(["read"])
        _ = try await frame(["wrote"])
        let check = try await frame(["read"])

        XCTAssertTrue(words(in: reopened).isEmpty)
        XCTAssertEqual(block("show", in: reopened)["title"], "Show my words")
        XCTAssertEqual(picks(in: check).count, 8)
    }

    func testSignOutAsksForTouchIDAndRemovesTheKey() async throws {
        _ = try store.keyMadeOnce()
        try store.markBackedUp()

        let leave = try await frame(["leave"])
        let out = try await frame(["sign_out"])

        XCTAssertEqual(block("head", in: leave)["title"], "Sign out of your account?")
        XCTAssertNil(try store.key())
        XCTAssertEqual(block("head", in: out)["title"], "Set up your account")
        XCTAssertEqual(toast(in: out), "Signed out")
        let asked = await app.asked
        XCTAssertEqual(asked, ["sign out of your account"])
    }
}
