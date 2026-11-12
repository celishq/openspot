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

    func testCreateKeepsANewKeyAndShowsItsTwelveWords() throws {
        let flow = AccountFlow(store: store, step: .choose)

        flow.create()

        XCTAssertEqual(flow.step, .words)
        XCTAssertEqual(flow.words, try store.key()?.words)
        XCTAssertEqual(flow.words.count, 12)
        XCTAssertFalse(try store.isBackedUp())
    }

    func testTheCheckAsksForTwoWordsEachAmongFourChoices() {
        let flow = AccountFlow(store: store, step: .choose)
        flow.create()

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

    func testAPastedPhraseFillsTheBoxesAndSignsIn() throws {
        let flow = AccountFlow(store: store, step: .restore)

        flow.paste(" \(phrase.uppercased())\n")

        XCTAssertEqual(flow.boxes, phrase.split(separator: " ").map(String.init))
        XCTAssertTrue(flow.canSignIn)
        flow.signIn()
        XCTAssertEqual(flow.step, .done)
        XCTAssertEqual(try store.key(), try AccountKey(words: flow.boxes))
        XCTAssertTrue(try store.isBackedUp())
    }

    func testAnNsecSignsIn() throws {
        let key = try AccountKey.make()
        let flow = AccountFlow(store: store, step: .restore)

        flow.paste(key.nsec)
        flow.signIn()

        XCTAssertEqual(try store.key()?.publicKey, key.publicKey)
        XCTAssertEqual(flow.step, .done)
    }

    func testAWordOutOfTheListIsNamedOnceAllBoxesHoldOne() {
        let flow = AccountFlow(store: store, step: .restore)
        flow.paste(phrase.replacingOccurrences(of: "about", with: "abuot"))

        XCTAssertEqual(flow.unknownBoxes, [11])
        XCTAssertEqual(flow.problem, "abuot is not a word of an account key.")
        XCTAssertFalse(flow.canSignIn)
    }

    func testAPartPhraseHasNoProblemYetAndCannotSignIn() {
        let flow = AccountFlow(store: store, step: .restore)

        flow.paste("abandon abandon")

        XCTAssertNil(flow.problem)
        XCTAssertFalse(flow.canSignIn)
    }

    func testASignInOverAnotherKeySaysWhatItReplaces() throws {
        try store.keep(try AccountKey.make())
        let flow = AccountFlow(store: store, step: .restore)
        flow.paste(phrase)

        XCTAssertEqual(flow.replacing, "This replaces the account on this Mac. Spots you published with it will publish as new spots.")
        try store.keep(try AccountKey(words: flow.boxes))
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
}
