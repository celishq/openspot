import XCTest
@testable import OpenspotCore

/// Proves the `openspot account` calls: anyone reads the public facts, and only a spot shipped in the app that declares
/// `uses=account` reaches the key, after Touch ID for the words and for a sign-out.
@MainActor
final class AccountCallsTests: XCTestCase {
    private final class Host: Mac {
        func eventStore() -> any EventStore { FakeEventStore() }
        func reminderStore() -> any ReminderStore { FakeReminderStore() }
        func showCalendar(at time: Date) throws {}
        func open(_ link: URL) -> Bool { true }
    }

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
        api = CommandAPI(mac: Host(), app: app, runs: runs)
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

    /// The answer to a call from a spot, or from the person with no spot.
    private func call(_ arguments: [String], from spot: Spot? = nil, input: String = "") async throws -> CommandAnswer {
        var environment = ["OPENSPOT_CONFIG": folder.path]
        if let spot { environment[CallerTokens.variable] = runs.tokens.issue(for: spot) }
        let parsed = api.admit(try XCTUnwrap(CommandLineCall(arguments: arguments, environment: environment)), arguments: arguments, environment: environment)
        let work = try XCTUnwrap(api.work(for: parsed, input: { input }, environment: environment))
        return await work()
    }

    private var account: Spot {
        spot(uses: [.account], isBuiltIn: true)
    }

    func testAnyoneReadsThePublicFacts() async throws {
        let key = try store.keyMadeOnce()

        let facts = try await call(["account", "--frame"], from: spot(uses: [], isBuiltIn: false))

        XCTAssertEqual(facts.output, "signedIn=true\nnpub=\(key.npub)\nbackedUp=false\n")
    }

    func testOnlyABuiltInSpotThatUsesAccountReachesTheKey() async throws {
        _ = try store.keyMadeOnce()
        let refused = "Only Openspot's Account spot can reach your account key.\n"

        for caller in [nil, spot(uses: [.account], isBuiltIn: false), spot(uses: [.app], isBuiltIn: true)] {
            for arguments in [["account", "words"], ["account", "new"], ["account", "sign-out"], ["account", "sync", "off"], ["account", "check", "1", "2"]] {
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

    func testNewMakesAKeyOnce() async throws {
        let first = try await call(["account", "new"], from: account)
        let key = try store.key()
        _ = try await call(["account", "new"], from: account)

        XCTAssertEqual(first.code, 0, first.errors)
        XCTAssertNotNil(key)
        XCTAssertEqual(try store.key(), key)
    }

    func testTheCheckGivesTheSameFourChoicesEachTimeAndMarksTheBackupWhenRight() async throws {
        let key = try store.keyMadeOnce()
        let words = try XCTUnwrap(key.words)

        let check = try await call(["account", "check", "4", "9"], from: account)
        let again = try await call(["account", "check", "4", "9"], from: account)
        let wrong = try await call(["account", "checked"], from: account, input: "4 \(words[4])\n9 \(words[8])\n")
        let right = try await call(["account", "checked"], from: account, input: "4 \(words[3])\n9 \(words[8])\n")

        XCTAssertEqual(check.output, again.output)
        let blocks = check.output.components(separatedBy: "\n\n")
        XCTAssertEqual(blocks.count, 2)
        XCTAssertTrue(blocks[0].hasPrefix("check=4\n"))
        XCTAssertTrue(blocks[0].split(separator: "\n").contains("choice=\(words[3])"))
        XCTAssertEqual(blocks[0].components(separatedBy: "choice=").count - 1, 4)
        XCTAssertEqual(wrong.errors, "That isn't word 4. Look at your words again.\n")
        XCTAssertEqual(right.code, 0, right.errors)
        XCTAssertTrue(try store.isBackedUp())
    }

    func testAPhraseSaysHowFarItIsAndSignsIn() async throws {
        let typing = try await call(["account", "phrase"], from: account, input: "abandon abuot abso")
        let ready = try await call(["account", "phrase"], from: account, input: phrase)
        let signedIn = try await call(["account", "sign-in"], from: account, input: phrase)

        XCTAssertEqual(typing.output, "counter=3 of 12\nword=abandon\nword=abuot\nword=abso\nunknown=2\ncompletion=absorb\n")
        XCTAssertEqual(ready.output, "counter=12 of 12\n" + Array(repeating: "word=abandon\n", count: 11).joined() + "word=about\naccount=\(try AccountKey(words: phrase.split(separator: " ").map(String.init)).npub)\n")
        XCTAssertEqual(signedIn.code, 0, signedIn.errors)
        XCTAssertTrue(try store.isBackedUp())
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
}
