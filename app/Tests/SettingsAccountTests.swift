import XCTest
@testable import OpenspotCore

@MainActor
final class SettingsAccountTests: PanelCase {
    private let phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    private var book: SettingsBook {
        model.settingsBook
    }

    private var store: AccountStore {
        model.files.account
    }

    func testTheWordsShowAfterTouchIDAndTwoRightPicksBackThemUp() async throws {
        let key = try store.keyMadeOnce()
        let all = try XCTUnwrap(key.words)

        let shown = await book.words()
        let offered = book.choices(at: [2, 7])
        let wrong = await book.confirm([2, 7], [all[1], all[1] == "zoo" ? "abandon" : "zoo"])
        let right = await book.confirm([2, 7], [all[1], all[6]])

        XCTAssertEqual(shown.words, all)
        XCTAssertNil(shown.failure)
        XCTAssertEqual(offered.count, 2)
        XCTAssertTrue(offered[0].contains(all[1]))
        XCTAssertEqual(wrong, "One of these words is wrong. Look at your words again.")
        XCTAssertNil(right)
        XCTAssertTrue(try store.record()?.isBackedUp == true)
        XCTAssertEqual(host.asked, ["show your account words", "check your account words", "check your account words"])
    }

    func testNoWordShowsWhenTouchIDFails() async throws {
        _ = try store.keyMadeOnce()
        host.allowsActs = false

        let shown = await book.words()

        XCTAssertEqual(shown.words, [])
        XCTAssertEqual(shown.failure, "Touch ID didn't pass, so Openspot showed no words.")
    }

    func testTheWordsSayWhatIsWrongAsTheyAreTypedThenSignIn() async throws {
        takeCalls()
        await book.read()
        XCTAssertEqual(book.line(of: ""), [:])
        XCTAssertEqual(book.line(of: "abandon ab"), ["title": "Did you mean abandon?", "icon": "questionmark.circle"])
        XCTAssertEqual(book.line(of: "abandon qqq "), ["title": "qqq isn't an account word", "icon": "exclamationmark.triangle", "tone": "bad"])
        XCTAssertEqual(book.line(of: "abandon "), ["title": "1 of 12"])
        XCTAssertEqual(book.line(of: phrase)["title"], "Signs in as")

        let failure = await book.signIn(phrase)

        XCTAssertNil(failure)
        XCTAssertEqual(try store.key()?.words?.joined(separator: " "), phrase)
        XCTAssertEqual(book.line(of: phrase)["title"], "Replaces the account on this Mac")
    }

    func testTheWholeFlowLeavesNoWordInAToastOrAFact() async throws {
        takeCalls()
        await book.read()

        await book.makeAccount(handle: "tony")
        let all = await book.words().words
        _ = await book.confirm([3, 9], [all[2], all[8]])
        await book.signOut()
        _ = await book.signIn(phrase)
        host.allowsActs = false
        _ = await book.words()
        await book.signOut()

        XCTAssertEqual(try store.key()?.words?.joined(separator: " "), phrase)
        let reached = model.toasts.queue.map(\.words) + ["\(book.facts)"]
        for said in reached {
            XCTAssertFalse(said.contains("abandon"), said)
        }
    }
}
