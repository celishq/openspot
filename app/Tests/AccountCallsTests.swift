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
        api = CommandAPI(mac: FakeMac(), places: .test(["OPENSPOT_CONFIG": folder.path]), app: app, runs: runs)
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
        let request = CommandRequest(arguments: arguments, folder: folder.path, token: spot.map { runs.tokens.issue(for: $0) }, isBound: true)
        let parsed = api.admit(try XCTUnwrap(api.call(of: request)), request: request)
        let work = try XCTUnwrap(api.work(for: parsed, request: request, input: { input }))
        return await work()
    }

    private var account: Spot {
        spot(uses: [.account], isBuiltIn: true)
    }

    func testAnyoneReadsThePublicFacts() async throws {
        let key = try store.keyMadeOnce()

        let facts = try await call(["account", "--frame"], from: spot(uses: [], isBuiltIn: false))

        XCTAssertEqual(facts.output, "signedIn=true\nnpub=\(key.npub)\nsince=\(try XCTUnwrap(try store.record()?.since))\nbackedUp=false\n")
    }

    func testOnlyABuiltInSpotThatUsesAccountReachesTheKey() async throws {
        _ = try store.keyMadeOnce()
        let refused = "Only Openspot's Account and Store spots can reach your account key.\n"

        for caller in [nil, spot(uses: [.account], isBuiltIn: false), spot(uses: [.app], isBuiltIn: true)] {
            for arguments in [["account", "words"], ["account", "new"], ["account", "checked"], ["account", "phrase"], ["account", "sign-in"], ["account", "sign-out"], ["account", "sync", "off"]] {
                let answer = try await call(arguments, from: caller)
                XCTAssertEqual(answer.errors, refused, "\(arguments) from \(caller?.uses ?? [])")
                XCTAssertEqual(answer.code, 1)
            }
        }
        let words = try await call(["account", "words"], from: account)
        XCTAssertEqual(words.code, 0, words.errors)
    }

    func testTheWordsShowAfterTouchID() async throws {
        let key = try store.keyMadeOnce()

        let words = try await call(["account", "words"], from: account)
        await app.set(allows: false)
        let denied = try await call(["account", "words"], from: account)

        XCTAssertEqual(words.output, (key.words ?? []).map { "word=\($0)\n" }.joined())
        XCTAssertEqual(denied.errors, "Touch ID didn't pass, so Openspot showed no words.\n")
        let asked = await app.asked
        XCTAssertEqual(asked, ["show your account words", "show your account words"])
    }

    func testNewKeepsTheHandleItIsGivenAndAnyoneReadsItWithTheDay() async throws {
        let refused = try await call(["account", "new", "Tony P"], from: account)
        let made = try await call(["account", "new", "tony"], from: account)

        let facts = try await call(["account", "--frame"], from: spot(uses: [], isBuiltIn: false))

        XCTAssertNotEqual(refused.code, 0)
        XCTAssertEqual(made.code, 0, made.errors)
        XCTAssertTrue(facts.output.contains("\nhandle=tony\n"), facts.output)
        XCTAssertNotNil(facts.output.range(of: "\nsince=\\d{4}-\\d{2}-\\d{2}\n", options: .regularExpression), facts.output)
    }

    func testNewMakesAKeyOnce() async throws {
        let first = try await call(["account", "new"], from: account)
        let key = try store.key()
        _ = try await call(["account", "new"], from: account)

        XCTAssertEqual(first.code, 0, first.errors)
        XCTAssertNotNil(key)
        XCTAssertEqual(try store.key(), key)
    }

    func testAPhraseSaysHowFarItIsAndSignsIn() async throws {
        let typing = try await call(["account", "phrase"], from: account, input: "abandon abuot abso")
        let ready = try await call(["account", "phrase"], from: account, input: phrase)
        let signedIn = try await call(["account", "sign-in"], from: account, input: phrase)

        XCTAssertEqual(typing.output, "counter=3 of 12\nword=abandon\nword=abuot\nword=abso\nunknown=2\ncompletion=absorb\n")
        XCTAssertEqual(ready.output, "counter=12 of 12\n" + Array(repeating: "word=abandon\n", count: 11).joined() + "word=about\naccount=\(try AccountKey(words: phrase.split(separator: " ").map(String.init)).npub)\n")
        XCTAssertEqual(signedIn.code, 0, signedIn.errors)
        XCTAssertTrue(try store.record()?.isBackedUp == true)
    }

    func testASignInThatIsNoAccountSaysWhy() async throws {
        let answer = try await call(["account", "sign-in"], from: account, input: Array(repeating: "abandon", count: 12).joined(separator: " "))

        XCTAssertEqual(answer.errors, "These words don't match an account. Check each word and their order.\n")
        XCTAssertNil(try store.key())
    }

    func testSignOutAsksTouchIDFirst() async throws {
        _ = try store.keyMadeOnce()
        await app.set(allows: false)

        let denied = try await call(["account", "sign-out"], from: account)
        XCTAssertNotNil(try store.key())
        await app.set(allows: true)
        _ = try await call(["account", "sign-out"], from: account)

        XCTAssertEqual(denied.errors, "Touch ID didn't pass, so your account stays.\n")
        XCTAssertNil(try store.key())
    }

    func testEachAccountVerbRunAloneAnswersThatTheAppIsNotRunning() async throws {
        let alone = CommandAPI(mac: FakeMac(), places: .test(["OPENSPOT_CONFIG": folder.path, CallerTokens.variable: runs.tokens.issue(for: account)]))
        let phrase = phrase

        for arguments in [["account"], ["account", "new"], ["account", "words"], ["account", "checked"], ["account", "phrase"], ["account", "sign-in"], ["account", "sign-out"], ["account", "sync", "off"]] {
            let request = CommandRequest(arguments: arguments, folder: folder.path)
            let work = try XCTUnwrap(alone.work(for: try XCTUnwrap(alone.call(of: request)), request: request, input: { phrase }))
            let answer = await work()
            XCTAssertEqual(answer.code, 1, "\(arguments)")
            XCTAssertTrue(answer.errors.contains("needs the Openspot app, and no app answers"), "\(arguments): \(answer.errors)")
        }
        XCTAssertNil(try store.key())
    }

    func testTheCheckAnswersForTheWholeSetAndPrintsNoWord() async throws {
        let key = try store.keyMadeOnce()
        let words = try XCTUnwrap(key.words)

        let choices = try await call(["account", "check", "4", "9"], from: account)
        let wrong = try await call(["account", "checked"], from: account, input: "4 \(words[4])\n9 \(words[8])\n")
        let short = try await call(["account", "checked"], from: account, input: "4 \(words[3])\n")

        XCTAssertEqual(choices.code, 2)
        XCTAssertEqual(choices.output, "")
        XCTAssertEqual(wrong.errors, "One of these words is wrong. Look at your words again.\n")
        XCTAssertEqual(short.errors, wrong.errors)
        XCTAssertFalse(try store.record()?.isBackedUp == true)
        let right = try await call(["account", "checked"], from: account, input: "4 \(words[3])\n9 \(words[8])\n")
        XCTAssertEqual(right.code, 0, right.errors)
        XCTAssertTrue(try store.record()?.isBackedUp == true)
    }

    func testTheConfigOfACallerDoesNotMoveTheKeyStore() async throws {
        let other = folder.appendingPathComponent("other", isDirectory: true)
        let line = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0", "id": 1, "method": "ask",
            "params": ["argv": ["account", "new"], "cwd": other.path, "token": runs.tokens.issue(for: account), "env": ["OPENSPOT_CONFIG": other.path]]
        ])
        var request = try XCTUnwrap(CommandRequest(line: line))
        XCTAssertFalse(request.isBound)
        request.isBound = true
        let work = try XCTUnwrap(api.work(for: api.admit(try XCTUnwrap(api.call(of: request)), request: request), request: request, input: { "" }))

        let answer = await work()

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertNil(try AccountStore.standard(environment: ["OPENSPOT_CONFIG": other.path], home: folder, devState: nil).key())
        XCTAssertNotNil(try store.key())
    }

    func testEachActOnTheSecretAsksTouchIDFirst() async throws {
        _ = try store.keyMadeOnce()
        let before = try store.key()
        await app.set(allows: false)

        let signIn = try await call(["account", "sign-in"], from: account, input: phrase)
        let checked = try await call(["account", "checked"], from: account, input: "1 abandon\n2 abandon\n")
        let sync = try await call(["account", "sync", "off"], from: account)

        XCTAssertEqual(signIn.errors, "Touch ID didn't pass, so Openspot didn't sign in.\n")
        XCTAssertEqual(checked.errors, "Touch ID didn't pass, so Openspot checked no words.\n")
        XCTAssertEqual(sync.errors, "Touch ID didn't pass, so your account stays where it is.\n")
        XCTAssertEqual(try store.key(), before)
        let asked = await app.asked
        XCTAssertEqual(asked, ["sign in to your account", "check your account words", "change where your account is kept"])
    }
}
