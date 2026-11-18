import XCTest
@testable import OpenspotCore

@MainActor
final class AccountCallsTests: XCTestCase {
    private var folder: URL!
    private var runs: SpotRuns!
    private var app: FakeRunningApp!
    private var api: CommandAPI!
    private let phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        runs = SpotRuns()
        app = FakeRunningApp()
        api = CommandAPI(mac: Mac(), places: .test(["OPENSPOT_CONFIG": folder.path]), app: app, runs: runs, rates: .offline)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private var store: AccountStore {
        AccountStore.standard(environment: ["OPENSPOT_CONFIG": folder.path], home: folder, devState: nil)
    }

    private func spot(uses: Set<SpotUse>, isBuiltIn: Bool) -> Spot {
        let spot = Spot(id: "openspot/account", name: "Account", url: folder.appendingPathComponent("account.sh"), dataName: "account", uses: uses)
        return isBuiltIn ? spot.builtIn() : spot
    }

    private func call(_ arguments: [String], from spot: Spot? = nil, input: String = "") async throws -> CommandAnswer {
        let request = CommandRequest(arguments: arguments, folder: folder.path, caller: spot.map { runs.callers.issue(for: $0) })
        let parsed = api.admit(try XCTUnwrap(api.call(of: request)), request: request)
        let work = try XCTUnwrap(api.work(for: parsed, request: request, input: { input }))
        return await work()
    }

    private var keyed: Spot {
        spot(uses: [.account], isBuiltIn: true)
    }

    private var secret: Account {
        Account(store: store, allows: { [app] in await app!.allows($0) })
    }

    private func reason(_ work: () async throws -> Void) async -> String? {
        do {
            try await work()
            return nil
        } catch {
            return (error as? SpotError)?.reason
        }
    }

    func testAnyoneReadsThePublicFacts() async throws {
        let key = try store.keyMadeOnce()

        let facts = try await call(["account", "show"], from: spot(uses: [], isBuiltIn: false))

        XCTAssertEqual(facts.output, "text=account\nsignedIn=true\nnpub=\(key.npub)\nsince=\(try XCTUnwrap(try store.record()?.since))\nbackedUp=false\n")
    }

    func testNoVerbMakesChangesOrRemovesTheKeyNorPrintsOrTakesAWord() async throws {
        let key = try store.keyMadeOnce()

        for caller in [nil, spot(uses: [.account], isBuiltIn: false), keyed] {
            for arguments in [["account", "words"], ["account", "choices", "2", "7"], ["account", "checked"], ["account", "phrase"], ["account", "sign-in"], ["account", "new"], ["account", "new", "tony"], ["account", "sign-out"], ["account", "sync", "off"]] {
                let answer = try await call(arguments, from: caller, input: phrase)
                XCTAssertEqual(answer.code, 2, "\(arguments)")
                XCTAssertEqual(answer.output, "", "\(arguments)")
            }
        }
        XCTAssertEqual(try store.key(), key)
        let asked = await app.asked
        XCTAssertEqual(asked, [])
    }

    func testTheWordsShowAfterTouchID() async throws {
        let key = try store.keyMadeOnce()

        let words = try await secret.words()
        await app.set(allows: false)
        let denied = await reason { _ = try await self.secret.words() }

        XCTAssertEqual(words, key.words)
        XCTAssertEqual(denied, "Touch ID didn't pass, so Openspot showed no words.")
        let asked = await app.asked
        XCTAssertEqual(asked, ["show your account words", "show your account words"])
    }

    func testAMadeKeyKeepsTheHandleItIsGivenAndAnyoneReadsItWithTheDay() async throws {
        XCTAssertThrowsError(try secret.make(handle: "Tony P"))
        try secret.make(handle: "tony")

        let facts = try await call(["account", "show"], from: spot(uses: [], isBuiltIn: false))

        XCTAssertTrue(facts.output.contains("\nhandle=tony\n"), facts.output)
        XCTAssertNotNil(facts.output.range(of: "\nsince=\\d{4}-\\d{2}-\\d{2}\n", options: .regularExpression), facts.output)
    }

    func testAKeyIsMadeOnce() async throws {
        try secret.make(handle: nil)
        let key = try store.key()
        try secret.make(handle: nil)

        XCTAssertNotNil(key)
        XCTAssertEqual(try store.key(), key)
    }

    func testAPhraseSignsInAndOneThatIsNoAccountSaysWhy() async throws {
        let wrong = await reason { try await self.secret.signIn(AccountPhrase(Array(repeating: "abandon", count: 12).joined(separator: " "))) }
        XCTAssertNil(try store.key())

        try await secret.signIn(AccountPhrase(phrase))

        XCTAssertEqual(wrong, "These words don't match an account. Check each word and their order.")
        XCTAssertTrue(try store.record()?.isBackedUp == true)
    }

    func testSignOutAsksTouchIDFirst() async throws {
        _ = try store.keyMadeOnce()
        await app.set(allows: false)

        let denied = await reason { try await self.secret.signOut() }
        XCTAssertNotNil(try store.key())
        await app.set(allows: true)
        try await secret.signOut()

        XCTAssertEqual(denied, "Touch ID didn't pass, so your account stays.")
        XCTAssertNil(try store.key())
    }

    func testTheFactsRunAloneAnswerThatTheAppIsNotRunning() async throws {
        let alone = CommandAPI(mac: Mac(), places: .test(["OPENSPOT_CONFIG": folder.path]), rates: .offline)
        let request = CommandRequest(arguments: ["account", "show"], folder: folder.path)

        let work = try XCTUnwrap(alone.work(for: try XCTUnwrap(alone.call(of: request)), request: request, input: { "" }))
        let answer = await work()

        XCTAssertEqual(answer.code, 3)
        XCTAssertTrue(answer.errors.contains("needs the Openspot app, and no app answers"), answer.errors)
    }

    func testTheCheckAnswersForTheWholeSet() async throws {
        let key = try store.keyMadeOnce()
        let words = try XCTUnwrap(key.words)

        let wrong = await reason { try await self.secret.confirm([(4, words[4]), (9, words[8])]) }
        let short = await reason { try await self.secret.confirm([(4, words[3])]) }

        XCTAssertEqual(wrong, "One of these words is wrong. Look at your words again.")
        XCTAssertEqual(short, wrong)
        XCTAssertFalse(try store.record()?.isBackedUp == true)
        try await secret.confirm([(4, words[3]), (9, words[8])])
        XCTAssertTrue(try store.record()?.isBackedUp == true)
    }

    func testTheConfigOfACallerDoesNotMoveTheKeyStore() async throws {
        _ = try store.keyMadeOnce()
        let other = folder.appendingPathComponent("other", isDirectory: true)
        let line = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0", "id": 1, "method": "ask",
            "params": ["argv": ["account", "show"], "cwd": other.path, "env": ["OPENSPOT_CONFIG": other.path]]
        ])
        let request = try XCTUnwrap(CommandRequest(line: line))
        let work = try XCTUnwrap(api.work(for: api.admit(try XCTUnwrap(api.call(of: request)), request: request), request: request, input: { "" }))

        let answer = await work()

        XCTAssertTrue(answer.output.hasPrefix("text=account\nsignedIn=true\n"), answer.output + answer.errors)
    }

    func testEachActOnTheSecretAsksTouchIDFirst() async throws {
        _ = try store.keyMadeOnce()
        let before = try store.key()
        await app.set(allows: false)

        let signIn = await reason { try await self.secret.signIn(AccountPhrase(self.phrase)) }
        let checked = await reason { try await self.secret.confirm([(1, "abandon"), (2, "abandon")]) }
        let sync = await reason { try await self.secret.sync(false) }

        XCTAssertEqual(signIn, "Touch ID didn't pass, so Openspot didn't sign in.")
        XCTAssertEqual(checked, "Touch ID didn't pass, so Openspot checked no words.")
        XCTAssertEqual(sync, "Touch ID didn't pass, so your account stays where it is.")
        XCTAssertEqual(try store.key(), before)
        let asked = await app.asked
        XCTAssertEqual(asked, ["sign in to your account", "check your account words", "change where your account is kept"])
    }
}
