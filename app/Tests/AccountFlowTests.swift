import XCTest
@testable import OpenspotCore

@MainActor
final class AccountFlowTests: XCTestCase {
    private var folder: URL!
    private var store: AccountStore!
    private let phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        store = AccountStore.standard(environment: ["OPENSPOT_CONFIG": folder.path], home: folder, devState: nil)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func right(_ check: AccountFlow.Check, of flow: AccountFlow) -> String {
        flow.words[check.position - 1]
    }

    func testCreateFirstSaysWhatTheWordsAreAndMakesNoKeyYet() throws {
        let flow = AccountFlow(store: store, step: .choose)

        flow.create()

        XCTAssertEqual(flow.step, .about)
        XCTAssertNil(try store.key())
    }

    func testShowWordsKeepsANewKeyAndShowsItsTwelveWords() throws {
        let flow = AccountFlow(store: store, step: .choose)
        flow.create()

        flow.showWords()

        XCTAssertEqual(flow.step, .words)
        XCTAssertEqual(flow.words, try store.key()?.words)
        XCTAssertEqual(flow.words.count, 12)
        XCTAssertFalse(try store.isBackedUp())
    }

    func testTheCheckAsksForTwoWordsEachAmongFourChoices() {
        let flow = AccountFlow(store: store, step: .choose)
        flow.create()
        flow.showWords()

        flow.wroteThemDown()

        XCTAssertEqual(flow.step, .check)
        XCTAssertEqual(flow.checks.count, 2)
        XCTAssertNotEqual(flow.checks[0].position, flow.checks[1].position)
        for check in flow.checks {
            XCTAssertTrue((1...12).contains(check.position))
            XCTAssertEqual(Set(check.choices).count, 4)
            XCTAssertTrue(check.choices.contains(right(check, of: flow)))
        }
    }

    func testTwoRightPicksMarkTheWordsBackedUp() throws {
        let flow = AccountFlow(store: store, step: .choose)
        flow.create()
        flow.showWords()
        flow.wroteThemDown()

        flow.pick(right(flow.checks[0], of: flow), at: 0)
        XCTAssertEqual(flow.step, .check)
        flow.pick(right(flow.checks[1], of: flow), at: 1)

        XCTAssertEqual(flow.step, .done)
        XCTAssertTrue(try store.isBackedUp())
    }

    func testAWrongPickSaysWhichWordAndKeepsTheMarkOff() throws {
        let flow = AccountFlow(store: store, step: .choose)
        flow.create()
        flow.showWords()
        flow.wroteThemDown()
        let check = flow.checks[0]
        let wrong = check.choices.first { $0 != right(check, of: flow) }!

        flow.pick(wrong, at: 0)

        XCTAssertEqual(flow.mistake, "That isn't word \(check.position). Look at your words again.")
        XCTAssertFalse(try store.isBackedUp())
        flow.showWordsAgain()
        XCTAssertEqual(flow.step, .words)
        XCTAssertNil(flow.mistake)
    }

    func testAPastedPhraseNumbersItsWordsAndNamesTheAccountItSignsInTo() throws {
        let flow = AccountFlow(store: store, step: .restore)

        flow.phrase = " \(phrase.uppercased())\n"

        XCTAssertEqual(flow.typed.map(\.text), phrase.split(separator: " ").map(String.init))
        XCTAssertTrue(flow.typed.allSatisfy(\.isKnown))
        XCTAssertEqual(flow.counter, "12 of 12")
        XCTAssertEqual(flow.account, try AccountKey(words: phrase.split(separator: " ").map(String.init)).npub)
        XCTAssertTrue(flow.canSignIn)
        flow.signIn()
        XCTAssertEqual(flow.step, .done)
        XCTAssertEqual(try store.key()?.npub, flow.account)
        XCTAssertTrue(try store.isBackedUp())
    }

    func testAWordOutOfTheListIsMarkedAtOnceButTheOneBeingTypedIsNot() {
        let flow = AccountFlow(store: store, step: .restore)

        flow.phrase = "abandon abuot aba"

        XCTAssertEqual(flow.typed.map(\.isKnown), [true, false, true])
        XCTAssertEqual(flow.counter, "3 of 12")
        XCTAssertNil(flow.problem)
        XCTAssertFalse(flow.canSignIn)
        flow.phrase = "abandon abandon zzz"
        XCTAssertEqual(flow.typed.last?.isKnown, false)
    }

    func testTabCompletesTheWordBeingTyped() {
        let flow = AccountFlow(store: store, step: .restore)
        flow.phrase = "abandon abso"

        XCTAssertEqual(flow.completion, "absorb")
        flow.complete()

        XCTAssertEqual(flow.phrase, "abandon absorb ")
        XCTAssertNil(flow.completion)
    }

    func testTwelveWordsThatAreNoAccountSayToCheckTheOrder() {
        let flow = AccountFlow(store: store, step: .restore)

        flow.phrase = Array(repeating: "abandon", count: 12).joined(separator: " ")

        XCTAssertEqual(flow.problem, "These words don't match an account. Check each word and their order.")
        XCTAssertNil(flow.account)
        XCTAssertFalse(flow.canSignIn)
    }

    func testMoreThanTwelveWordsSayHowMany() {
        let flow = AccountFlow(store: store, step: .restore)

        flow.phrase = phrase + " abandon"

        XCTAssertEqual(flow.counter, "13 of 12")
        XCTAssertEqual(flow.problem, "An account has 12 words, and this has 13.")
    }

    func testAnNsecSignsIn() throws {
        let key = try AccountKey.make()
        let flow = AccountFlow(store: store, step: .restore)

        flow.usesNsec = true
        flow.phrase = key.nsec

        XCTAssertEqual(flow.account, key.npub)
        flow.signIn()
        XCTAssertEqual(try store.key()?.publicKey, key.publicKey)
        XCTAssertEqual(flow.step, .done)
    }

    func testAPartNsecHasNoProblemYet() {
        let flow = AccountFlow(store: store, step: .restore)
        flow.usesNsec = true

        flow.phrase = "nsec1abc"

        XCTAssertNil(flow.problem)
        XCTAssertFalse(flow.canSignIn)
        flow.phrase = "nsec1" + String(repeating: "q", count: 58)
        XCTAssertEqual(flow.problem, "This is not an nsec.")
    }

    func testASignInOverAnotherKeySaysWhatItReplaces() throws {
        try store.keep(try AccountKey.make())
        let flow = AccountFlow(store: store, step: .restore)
        flow.phrase = phrase

        XCTAssertEqual(flow.replacing, "This replaces the account on this Mac. Spots you published with it will publish as new spots.")
        try store.keep(try AccountKey(words: phrase.split(separator: " ").map(String.init)))
        XCTAssertNil(flow.replacing)
    }

    func testABackupOpensOnTheWordsOfTheKeptKey() throws {
        let key = try store.keyMadeOnce()

        let flow = AccountFlow(store: store, step: .words)

        XCTAssertEqual(flow.words, key.words)
    }

    func testSignOutRemovesTheKey() throws {
        _ = try store.keyMadeOnce()
        let flow = AccountFlow(store: store, step: .signOut)

        flow.signOut()

        XCTAssertNil(try store.key())
        XCTAssertEqual(flow.step, .done)
    }

    func testABoxSuggestsTheWordsThatStartWithItsLetters() {
        XCTAssertEqual(AccountFlow.suggestions(for: "abs"), ["absent", "absorb", "abstract", "absurd"])
        XCTAssertEqual(AccountFlow.suggestions(for: ""), [])
    }

    func testSignOutSaysWhenTheWordsWereNeverSaved() throws {
        _ = try store.keyMadeOnce()
        let flow = AccountFlow(store: store, step: .signOut)

        XCTAssertEqual(flow.signOutWords, "Openspot removes your account from this Mac. You haven't saved its 12 words, so you can't sign in to it again.")
        try store.markBackedUp()
        XCTAssertEqual(flow.signOutWords, "Openspot removes your account from this Mac. You can sign in again with your 12 words.")
    }
}
