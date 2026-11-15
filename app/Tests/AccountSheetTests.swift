import XCTest
@testable import OpenspotCore

final class AccountSheetTests: BuiltInCase {
    private actor Publishes {
        var ids: [String] = []
        var waiting: String?

        func wait(for id: String) {
            waiting = id
        }

        func publishWaiting() -> Bool {
            guard let id = waiting else { return false }
            waiting = nil
            ids.append(id)
            return true
        }
    }

    private let phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private let publishes = Publishes()
    private var sheet: AccountSheet?

    private var account: Spot {
        get throws {
            if let sheet { return sheet.spot }
            let app = app, mac = mac, publishes = publishes
            let made = AccountSheet(store: store, links: AccountSheet.Links(
                allows: { await app.allows($0) },
                copy: { mac.copied.append($0); return true },
                publish: { await publishes.publishWaiting() },
                userName: { "Tony Pinkevych" }
            ))
            sheet = made
            return made.spot
        }
    }

    private var store: AccountStore {
        AccountStore.standard(environment: ["OPENSPOT_CONFIG": root.path], home: root, devState: nil)
    }

    private func frame(_ arguments: [String], input: String? = nil, reason: String = "sheet.open", page: String? = nil) async throws -> String {
        var variables = arguments == ["read"] ? ["OPENSPOT_REASON": reason] : [:]
        if let page { variables["OPENSPOT_PAGE"] = page }
        return try await runs.answer(of: account, SpotAction(arguments: arguments), input: input, limit: 60, variables: variables)
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
        (1...12).compactMap { block("w\($0)", in: frame)["title"] }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    func testSearchFindsItAndItShipsWithTheApp() throws {
        let spot = try account

        XCTAssertEqual(spot.name, "Account")
        XCTAssertTrue(spot.isFound)
        XCTAssertFalse(spot.read?.has(.panel) == true)
        XCTAssertTrue(spot.reachesAccountKey)
        XCTAssertEqual(spot.view, AccountSheet.card)
    }

    func testWithNoAccountItOffersANewKeyOrYourOwn() async throws {
        let read = try await frame(["read"])

        XCTAssertEqual(block("head", in: read)["title"], "You need a key to publish")
        XCTAssertEqual(block("new", in: read)["title"], "Create a new key")
        XCTAssertEqual(block("own", in: read)["title"], "Use my own key")
    }

    func testANewKeyAsksForAHandleUnderItsTitleThenOpensTheAccount() async throws {
        let asked = try await frame(["new"])
        XCTAssertNil(try store.key())
        XCTAssertEqual(block("handle", in: asked)["value"], "tonypinkevych")
        XCTAssertEqual(block("handle", in: asked)["grow"], "false")
        XCTAssertEqual(block("label", in: asked)["title"], "Handle")
        XCTAssertTrue(asked.contains("grid=back create\n"), asked)

        let made = try await frame(["create"], input: "handle=tony\n")

        XCTAssertNotNil(try store.key())
        XCTAssertEqual(try store.record()?.handle, "tony")
        XCTAssertEqual(block("card", in: made)["handle"], "tony")
        XCTAssertEqual(block("card", in: made)["npub"], try store.key()?.npub)
        XCTAssertEqual(block("about", in: made)["detail"], "Not saved yet")
        XCTAssertFalse(made.contains("pop=true"), made)
    }

    func testThePillOfTheCardCopiesTheKeyAndSaysSo() async throws {
        let key = try store.keyMadeOnce(handle: "tony")

        let copied = try await frame(["card", "copy"])

        XCTAssertEqual(mac.copied, [key.npub])
        XCTAssertEqual(toast(in: copied), "Copied your key")
    }

    func testTypingAHandleCleansItAndATooShortOneKeepsThePageAndSaysTheRule() async throws {
        _ = try await frame(["new"])

        let typed = try await frame(["handle", "Tony P!"])
        let short = try await frame(["handle", "T."])
        let refused = try await frame(["create"], input: "handle=T.\n")

        XCTAssertEqual(block("handle", in: typed)["value"], "tonyp")
        XCTAssertNil(block("status", in: typed)["title"])
        XCTAssertEqual(block("status", in: short)["title"], AccountHandle.rule)
        XCTAssertNil(try store.key())
        XCTAssertEqual(block("status", in: refused)["title"], AccountHandle.rule)
    }

    func testTheAccountPageGroupsBackupThenHowItWorksAndSignOutWithNoDone() async throws {
        _ = try store.keyMadeOnce(handle: "tony")

        let read = try await frame(["read"])

        XCTAssertEqual(block("card", in: read)["grow"], "false")
        XCTAssertEqual(block("backup", in: read)["title"], "Backup")
        XCTAssertTrue(read.contains("grid=- -\ngrid=how leave\n"), read)
        XCTAssertFalse(read.contains("button=done"), read)
    }

    func testAKeyNotBackedUpOpensOnTheAccountNotOnTheWords() async throws {
        _ = try store.keyMadeOnce()

        let read = try await frame(["read"])

        XCTAssertEqual(block("card", in: read)["npub"], try store.key()?.npub)
    }

    func testHowItWorksIsAButtonOnTheChoiceAndTheAccountThatExplainsTheKey() async throws {
        let read = try await frame(["read"])
        let how = try await frame(["how"])
        let done = try await frame(["done"])
        _ = try store.keyMadeOnce()
        let account = try await frame(["read"])

        XCTAssertEqual(block("how", in: read)["title"], "How it works")
        XCTAssertTrue(read.contains("grid=own how\n"), read)
        XCTAssertTrue(account.contains("grid=how leave\n"), account)
        XCTAssertEqual(block("head", in: how)["title"], "How your key works")
        XCTAssertEqual(block("head", in: done)["title"], "You need a key to publish")
    }

    func testWithAPublishThatWaitsANewKeyPublishesItAndGoesBack() async throws {
        await publishes.wait(for: "a")

        _ = try await frame(["new"])
        let done = try await frame(["create"], input: "handle=tony\n")

        XCTAssertNotNil(try store.key())
        let published = await publishes.ids
        XCTAssertEqual(published, ["a"])
        XCTAssertTrue(done.contains("pop=true\n"), done)
    }

    func testWithAPublishThatWaitsYourOwnWordsSignInPublishItAndGoBack() async throws {
        await publishes.wait(for: "a")

        let restore = try await frame(["own"])
        let done = try await frame(["sign_in"], input: "phrase=\(phrase)\n")

        XCTAssertTrue(restore.contains("field=phrase"), restore)
        XCTAssertEqual(try store.key()?.words?.joined(separator: " "), phrase)
        let published = await publishes.ids
        XCTAssertEqual(published, ["a"])
        XCTAssertTrue(done.contains("pop=true\n"), done)
    }

    func testAPageThatACallerNamesPublishesNothing() async throws {
        XCTAssertEqual(try account.pages, [])

        _ = try await frame(["new"], page: "publish:evil")
        let made = try await frame(["create"], input: "handle=tony\n", page: "publish:evil")
        _ = try await frame(["leave"], page: "publish:evil")
        _ = try await frame(["sign_out"], page: "publish:evil")
        _ = try await frame(["own"], page: "publish:evil")
        let signedIn = try await frame(["sign_in"], input: "phrase=\(phrase)\n", page: "publish:evil")

        let published = await publishes.ids
        XCTAssertEqual(published, [])
        XCTAssertFalse(made.contains("pop=true\n"), made)
        XCTAssertFalse(signedIn.contains("pop=true\n"), signedIn)
    }

    func testBackFromSignInShowsTheTwoChoicesAgain() async throws {
        _ = try await frame(["own"])

        let back = try await frame(["back"])

        XCTAssertEqual(block("new", in: back)["title"], "Create a new key")
    }

    func testShowMyWordsSaysWhatTheWordsAreThenShowsThem() async throws {
        _ = try store.keyMadeOnce()
        let about = try await frame(["about"])
        XCTAssertEqual(block("head", in: about)["title"], "Your 12 words are your key")
        XCTAssertEqual(block("private", in: about)["title"], "Anyone with them is you")
        XCTAssertEqual(block("reset", in: about)["title"], "Nobody can reset them")

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

        XCTAssertTrue(try store.record()?.isBackedUp == true)
        XCTAssertEqual(toast(in: done), "Your words are backed up")
        XCTAssertNotNil(block("card", in: done)["short"])
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

        XCTAssertEqual(block("head", in: after)["title"], "One of these words is wrong. Look at your words again.")
        XCTAssertFalse(try store.record()?.isBackedUp == true)
    }

    func testTheSignInPageIsAFieldOfThreeLinesThatCountsTheWordsWithSignInOnTheRight() async throws {
        let empty = try await frame(["sign_in"])
        let typing = try await frame(["phrase", "abandon"])

        XCTAssertTrue(empty.contains("grid=phrase phrase\ngrid=phrase phrase\ngrid=phrase phrase\n"), empty)
        XCTAssertEqual(block("phrase", in: empty)["grow"], "false")
        XCTAssertTrue(empty.contains("grid=back sign_in\n"), empty)
        XCTAssertFalse(empty.contains("grid=status"), empty)
        XCTAssertNil(block("w1", in: typing)["title"])
        XCTAssertEqual(block("status", in: typing)["title"], "1 of 12")
    }

    func testThePhraseSaysWhatIsWrongAsItIsTypedAndSignsIn() async throws {
        _ = try await frame(["sign_in"])

        let typing = try await frame(["phrase", "abandon abuot abso"])
        let completing = try await frame(["phrase", "abandon abso"])
        let ready = try await frame(["phrase", phrase])
        let signedIn = try await frame(["sign_in"], input: "phrase=\(phrase)\n")

        XCTAssertEqual(block("status", in: typing)["title"], "abuot isn't an account word")
        XCTAssertEqual(block("status", in: completing)["title"], "Did you mean absorb?")
        XCTAssertEqual(block("status", in: ready)["title"], "Signs in as")
        XCTAssertEqual(toast(in: signedIn), "Signed in")
        XCTAssertTrue(try store.record()?.isBackedUp == true)
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
        XCTAssertEqual(block("about", in: sheet)["title"], "Recovery words")
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
        XCTAssertEqual(block("about", in: reopened)["title"], "Recovery words")
        XCTAssertEqual(picks(in: check).count, 8)
    }

    func testSignOutAsksForTouchIDAndRemovesTheKey() async throws {
        _ = try store.keyMadeOnce()
        try store.markBackedUp()

        let leave = try await frame(["leave"])
        let out = try await frame(["sign_out"])

        XCTAssertEqual(block("head", in: leave)["title"], "Sign out of your account?")
        XCTAssertNil(try store.key())
        XCTAssertEqual(block("head", in: out)["title"], "You need a key to publish")
        XCTAssertEqual(toast(in: out), "Signed out")
        let asked = await app.asked
        XCTAssertEqual(asked, ["sign out of your account"])
    }
}
