import XCTest
@testable import OpenspotCore

@MainActor
final class SecretLinksTests: XCTestCase {
    private var folder: URL!
    private var app: FakeRunningApp!
    private actor Kept {
        var lines: [String] = []

        func add(_ line: String) {
            lines.append(line)
        }
    }

    private let kept = Kept()
    private let phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    override func setUp() async throws {
        folder = try temporaryFolder()
        app = FakeRunningApp()
    }

    private var store: AccountStore {
        AccountStore.standard(environment: ["OPENSPOT_CONFIG": folder.path], home: folder, devState: nil)
    }

    private var input: [String: Any] {
        let app = app!, kept = kept
        return SecretLinks(account: Account(store: store, allows: { await app.allows($0) }), keep: { value, key, spot in
            await kept.add("\(spot) \(key) \(value)")
            return nil
        }).input
    }

    func testOnlyAViewOfTheAppsOwnSpotsGetsThem() {
        let core = URL(fileURLWithPath: "/App/Resources/spots")

        XCTAssertTrue(SecretLinks.isGiven(to: "/App/Resources/spots/openspot.spot/settings.swift", core: core))
        XCTAssertFalse(SecretLinks.isGiven(to: "/App/Resources/spots/notes.spot/notes.swift", core: core))
        XCTAssertFalse(SecretLinks.isGiven(to: "/Users/me/spots/openspot.spot/settings.swift", core: core))
        XCTAssertFalse(SecretLinks.isGiven(to: "/App/Resources/spots/openspot.spot/settings.swift", core: nil))
    }

    func testKeepHandsTheSecretToTheApp() async throws {
        let keep = try XCTUnwrap(input["keep"] as? (String, String, String) async -> String?)

        let failure = await keep("tok-123456", "token", "weather")

        XCTAssertNil(failure)
        let lines = await kept.lines
        XCTAssertEqual(lines, ["weather token tok-123456"])
    }

    func testTheWordsShowAfterTouchIDAndTwoRightPicksBackThemUp() async throws {
        let key = try store.keyMadeOnce()
        let words = try XCTUnwrap(input["words"] as? () async -> ([String], String?))
        let choices = try XCTUnwrap(input["choices"] as? ([Int]) -> [[String]])
        let confirm = try XCTUnwrap(input["confirm"] as? ([Int], [String]) async -> String?)
        let all = try XCTUnwrap(key.words)

        let shown = await words()
        let offered = choices([2, 7])
        let wrong = await confirm([2, 7], [all[1], all[1] == "zoo" ? "abandon" : "zoo"])
        let right = await confirm([2, 7], [all[1], all[6]])

        XCTAssertEqual(shown.0, all)
        XCTAssertNil(shown.1)
        XCTAssertEqual(offered.count, 2)
        XCTAssertTrue(offered[0].contains(all[1]))
        XCTAssertEqual(wrong, "One of these words is wrong. Look at your words again.")
        XCTAssertNil(right)
        XCTAssertTrue(try store.record()?.isBackedUp == true)
        let asked = await app.asked
        XCTAssertEqual(asked, ["show your account words", "check your account words", "check your account words"])
    }

    func testNoWordShowsWhenTouchIDFails() async throws {
        _ = try store.keyMadeOnce()
        await app.set(allows: false)
        let words = try XCTUnwrap(input["words"] as? () async -> ([String], String?))

        let shown = await words()

        XCTAssertEqual(shown.0, [])
        XCTAssertEqual(shown.1, "Touch ID didn't pass, so Openspot showed no words.")
    }

    func testTheWordsSayWhatIsWrongAsTheyAreTypedThenSignIn() async throws {
        let line = try XCTUnwrap(input["line"] as? (String) -> [String: String])
        let signIn = try XCTUnwrap(input["signIn"] as? (String) async -> String?)

        XCTAssertEqual(line(""), [:])
        XCTAssertEqual(line("abandon ab"), ["title": "Did you mean abandon?", "icon": "questionmark.circle"])
        XCTAssertEqual(line("abandon qqq "), ["title": "qqq isn't an account word", "icon": "exclamationmark.triangle", "tone": "bad"])
        XCTAssertEqual(line("abandon "), ["title": "1 of 12"])
        XCTAssertEqual(line(phrase)["title"], "Signs in as")
        let failure = await signIn(phrase)

        XCTAssertNil(failure)
        XCTAssertEqual(try store.key()?.words?.joined(separator: " "), phrase)
        XCTAssertEqual(line(phrase)["title"], "Replaces the account on this Mac")
    }
}
