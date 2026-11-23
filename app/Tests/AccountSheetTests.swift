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
        let message = (arguments == ["show"] ? "input.event=\(reason)\n" : "") + Self.inputs(arguments, page: page) + (input ?? "")
        return try await runs.answer(of: account, SpotWords(arguments: Array(arguments.prefix(1))), input: message, limit: 60)
    }

    private func said(_ arguments: [String], input: String? = nil, page: String? = nil) async throws -> HostAnswer {
        _ = try account
        let message = Self.inputs(arguments, page: page) + (input ?? "")
        return try await XCTUnwrap(sheet).answer(Array(arguments.prefix(1)), input: message)
    }

    private static func inputs(_ arguments: [String], page: String?) -> String {
        (arguments.dropFirst().first.map { "input.value=\($0)\n" } ?? "") + (page.map { "input.route=\($0)\n" } ?? "")
    }

    private func effects(_ arguments: [String], input: String? = nil, page: String? = nil) async throws -> [SpotEffect] {
        try await said(arguments, input: input, page: page).effects
    }

    private func push(_ page: String) -> SpotEffect {
        .route(.push(spot: nil, route: page, title: nil, replace: false))
    }

    private func block(_ id: String, in frame: String) -> [String: String] {
        let found = frame.components(separatedBy: "\n\n").first { $0.split(separator: "\n").contains { $0.hasSuffix("=\(id)") && !$0.hasPrefix("parent=") } }
        var keys: [String: String] = [:]
        for line in (found ?? "").split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 { keys[parts[0]] = parts[1] }
        }
        return keys
    }

    private func words(in frame: String) -> [String] {
        (1...12).compactMap { block("w\($0)", in: frame)["title"] }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    func testSearchFindsItAndItShipsWithTheApp() throws {
        let spot = try account

        XCTAssertEqual(spot.name, "Account")
        XCTAssertTrue(spot.isFound)
        XCTAssertFalse(spot.triggers.showsOnPanel)
        XCTAssertTrue(spot.reachesAccountKey)
        XCTAssertEqual(spot.views, ["card": AccountSheet.card])
    }

    func testWithNoAccountItOffersANewKeyOrYourOwn() async throws {
        let read = try await frame(["show"])

        XCTAssertEqual(block("head", in: read)["title"], "You need a key to publish")
        XCTAssertEqual(block("new", in: read)["title"], "Create a new key")
        XCTAssertEqual(block("own", in: read)["title"], "Use my own key")
    }

    func testALineIsATileWhoseEdgeMeetsTheButtonsAndWhoseWordsWrapInsideIt() async throws {
        let read = try await frame(["show"])
        let tree = Frame(text: read).tree
        let frames = tree.frames(in: SpotTokens.partsWidth, room: SpotTokens.partsMaxHeight, words: [:])
        let head = try XCTUnwrap(tree.node("head"))
        let style = head.style.resolved(for: [.sheet])

        XCTAssertEqual(style.fill, .tile)
        XCTAssertEqual(frames["head"]?.minX, frames["row-2"]?.minX)
        let type = SpotTokens.layout.type
        let detailLine = CGFloat(type.detail) + SpotTokens.textLeading
        let twoLines = CGFloat(type.body) + SpotTokens.textLeading + SpotTokens.textLineGap + 2 * detailLine
        XCTAssertEqual(frames["head"]?.height, twoLines + 2 * 3 * SpotTokens.spaceUnit)
    }

    func testANewKeyAsksForAHandleUnderItsTitleThenOpensTheAccount() async throws {
        let pushed = try await effects(["new"])
        XCTAssertEqual(pushed, [push("handle")])
        let asked = try await frame(["show"], page: "handle")
        XCTAssertNil(try store.key())
        XCTAssertEqual(block("handle", in: asked)["value"], "tonypinkevych")
        XCTAssertEqual(block("handle", in: asked)["grow"], "false")
        XCTAssertEqual(block("label", in: asked)["title"], "Handle")
        XCTAssertEqual(block("label", in: asked)["class"], "font-section")
        XCTAssertEqual(block("create", in: asked)["title"], "Create key")
        XCTAssertEqual(block("create", in: asked)["parent"], "end")
        XCTAssertNil(block("back", in: asked)["title"])

        let answer = try await said(["create"], input: "input.handle=tony\n", page: "handle")
        let made = answer.frame

        XCTAssertNotNil(try store.key())
        XCTAssertEqual(answer.effects, [.route(.pop(all: true))])
        XCTAssertEqual(try store.record()?.handle, "tony")
        XCTAssertEqual(block("card", in: made)["handle"], "tony")
        XCTAssertEqual(block("card", in: made)["npub"], try store.key()?.npub)
        XCTAssertEqual(block("about", in: made)["detail"], "Not saved yet")
    }

    func testThePillOfTheCardCopiesTheKeyAndSaysSo() async throws {
        let key = try store.keyMadeOnce(handle: "tony")

        let copied = try await effects(["card", "copy"])

        XCTAssertEqual(mac.copied, [key.npub])
        XCTAssertEqual(copied, [.toast("Copied your key")])
    }

    func testTypingAHandleCleansItAndATooShortOneKeepsThePageAndSaysTheRule() async throws {
        let typed = try await frame(["handle", "Tony P!"], page: "handle")
        let short = try await frame(["handle", "T."], page: "handle")
        let refused = try await frame(["create"], input: "input.handle=T.\n", page: "handle")

        XCTAssertEqual(block("handle", in: typed)["value"], "tonyp")
        XCTAssertNil(block("status", in: typed)["title"])
        XCTAssertEqual(block("status", in: short)["title"], AccountHandle.rule)
        XCTAssertNil(try store.key())
        XCTAssertEqual(block("status", in: refused)["title"], AccountHandle.rule)
    }

    func testTheAccountPageGroupsBackupThenHowItWorksAndSignOutWithNoDone() async throws {
        _ = try store.keyMadeOnce(handle: "tony")

        let read = try await frame(["show"])

        XCTAssertEqual(block("card", in: read)["grow"], "false")
        XCTAssertEqual(block("backup", in: read)["title"], "Backup")
        XCTAssertTrue(read.contains("class=h-px bg-tile\n"), read)
        XCTAssertNotNil(block("how", in: read)["parent"])
        XCTAssertEqual(block("how", in: read)["parent"], block("leave", in: read)["parent"])
        XCTAssertFalse(read.contains("button=done"), read)
    }

    func testAKeyNotBackedUpOpensOnTheAccountNotOnTheWords() async throws {
        _ = try store.keyMadeOnce()

        let read = try await frame(["show"])

        XCTAssertEqual(block("card", in: read)["npub"], try store.key()?.npub)
    }

    func testHowItWorksIsAButtonOnTheChoiceAndTheAccountThatExplainsTheKey() async throws {
        let read = try await frame(["show"])
        let pushed = try await effects(["how"])
        let how = try await frame(["show"], page: "how")
        let done = try await effects(["done"], page: "how")
        _ = try store.keyMadeOnce()
        let account = try await frame(["show"])

        XCTAssertEqual(block("how", in: read)["title"], "How it works")
        XCTAssertNotNil(block("how", in: read)["parent"])
        XCTAssertEqual(block("own", in: read)["parent"], block("how", in: read)["parent"])
        XCTAssertEqual(block("how", in: account)["parent"], block("leave", in: account)["parent"])
        XCTAssertEqual(pushed, [push("how")])
        XCTAssertEqual(block("head", in: how)["title"], "How your key works")
        XCTAssertEqual(done, [.route(.pop(all: false))])
    }

    func testWithAPublishThatWaitsANewKeyPublishesItAndGoesBack() async throws {
        await publishes.wait(for: "a")

        let done = try await effects(["create"], input: "input.handle=tony\n", page: "handle")

        XCTAssertNotNil(try store.key())
        let published = await publishes.ids
        XCTAssertEqual(published, ["a"])
        XCTAssertEqual(done, [.route(.pop(all: true))])
    }

    func testWithAPublishThatWaitsYourOwnWordsSignInPublishItAndGoBack() async throws {
        await publishes.wait(for: "a")

        let restore = try await frame(["show"], page: "restore")
        let done = try await effects(["sign_in"], input: "input.phrase=\(phrase)\n", page: "restore")

        XCTAssertTrue(restore.contains("field=phrase"), restore)
        XCTAssertEqual(try store.key()?.words?.joined(separator: " "), phrase)
        let published = await publishes.ids
        XCTAssertEqual(published, ["a"])
        XCTAssertEqual(done, [.route(.pop(all: true)), .toast("Signed in")])
    }

    func testAPageThatACallerNamesPublishesNothing() async throws {
        XCTAssertFalse(try account.takes(route: "publish:evil"))

        _ = try await frame(["new"], page: "publish:evil")
        let made = try await effects(["create"], input: "input.handle=tony\n", page: "publish:evil")
        _ = try await frame(["leave"], page: "publish:evil")
        _ = try await frame(["sign_out"], page: "publish:evil")
        _ = try await frame(["own"], page: "publish:evil")
        let signedIn = try await effects(["sign_in"], input: "input.phrase=\(phrase)\n", page: "publish:evil")

        let published = await publishes.ids
        XCTAssertEqual(published, [])
        XCTAssertFalse(made.contains(.route(.pop(all: false))))
        XCTAssertFalse(signedIn.contains(.route(.pop(all: false))))
    }

    func testYourOwnKeyPushesTheSignInPageWhichHasNoBackButton() async throws {
        let pushed = try await said(["own"])
        let restore = try await frame(["show"], page: "restore")

        XCTAssertEqual(pushed.effects, [push("restore")])
        XCTAssertEqual(block("new", in: pushed.frame)["title"], "Create a new key")
        XCTAssertNil(block("back", in: restore)["title"])
    }

    func testShowMyWordsSaysWhatTheWordsAreThenShowsThem() async throws {
        _ = try store.keyMadeOnce()
        let pushed = try await effects(["about"])
        XCTAssertEqual(pushed, [push("about")])
        let about = try await frame(["show"], page: "about")
        XCTAssertEqual(block("head", in: about)["title"], "Your 12 words are your key")
        XCTAssertEqual(block("private", in: about)["title"], "Anyone with them is you")
        XCTAssertEqual(block("reset", in: about)["title"], "Nobody can reset them")

        let shown = try await frame(["reveal"], page: "about")

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
        _ = try await frame(["reveal"], page: "about")

        let wrote = try await effects(["wrote"], page: "about")
        XCTAssertEqual(wrote, [push("check")])
        let check = try await frame(["show"], page: "check")
        let choices = picks(in: check)
        XCTAssertEqual(choices.count, 8)
        let places = Array(Set(choices.map(\.place))).sorted()
        let first = try await frame(["pick-\(places[0])-\(words[places[0] - 1])"], page: "check")
        XCTAssertEqual(block("pick-\(places[0])-\(words[places[0] - 1])", in: first)["class"], "bg-accent")
        let done = try await said(["pick-\(places[1])-\(words[places[1] - 1])"], page: "check")

        XCTAssertTrue(try store.record()?.isBackedUp == true)
        XCTAssertEqual(done.effects, [.route(.pop(all: true)), .toast("Your words are backed up")])
        XCTAssertNotNil(block("card", in: done.frame)["short"])
    }

    func testAWrongPickSaysWhichWord() async throws {
        let words = try XCTUnwrap(try store.keyMadeOnce().words)
        _ = try await frame(["wrote"], page: "about")
        let check = try await frame(["show"], page: "check")
        let choices = picks(in: check)
        let places = Array(Set(choices.map(\.place))).sorted()
        let wrong = try XCTUnwrap(choices.first { $0.place == places[0] && $0.word != words[places[0] - 1] })

        _ = try await frame(["pick-\(wrong.place)-\(wrong.word)"], page: "check")
        let after = try await frame(["pick-\(places[1])-\(words[places[1] - 1])"], page: "check")

        XCTAssertEqual(block("head", in: after)["title"], "One of these words is wrong. Look at your words again.")
        XCTAssertFalse(try store.record()?.isBackedUp == true)
    }

    func testTheSignInPageIsAFieldOfThreeLinesThatCountsTheWordsWithSignInOnTheRight() async throws {
        let empty = try await frame(["show"], page: "restore")
        let typing = try await frame(["phrase", "abandon"], page: "restore")

        XCTAssertEqual(block("phrase", in: empty)["class"], "h-32")
        XCTAssertEqual(block("phrase", in: empty)["grow"], "false")
        XCTAssertEqual(block("sign_in", in: empty)["parent"], "end")
        XCTAssertNil(block("status", in: empty)["title"])
        XCTAssertNil(block("w1", in: typing)["title"])
        XCTAssertEqual(block("status", in: typing)["title"], "1 of 12")
    }

    func testThePhraseSaysWhatIsWrongAsItIsTypedAndSignsIn() async throws {
        let typing = try await frame(["phrase", "abandon abuot abso"], page: "restore")
        let completing = try await frame(["phrase", "abandon abso"], page: "restore")
        let ready = try await frame(["phrase", phrase], page: "restore")
        let signedIn = try await effects(["sign_in"], input: "input.phrase=\(phrase)\n", page: "restore")

        XCTAssertEqual(block("status", in: typing)["title"], "abuot isn't an account word")
        XCTAssertEqual(block("status", in: completing)["title"], "Did you mean absorb?")
        XCTAssertEqual(block("status", in: ready)["title"], "Signs in as")
        XCTAssertEqual(signedIn.last, .toast("Signed in"))
        XCTAssertTrue(try store.record()?.isBackedUp == true)
    }

    func testAReadAtLaunchNeverShowsTheWordsNorAsksForTouchID() async throws {
        _ = try store.keyMadeOnce()
        _ = try await frame(["reveal"], page: "about")
        let before = await app.asked

        let launch = try await frame(["show"], reason: "app.launch")
        let sheet = try await frame(["show"])

        let after = await app.asked
        XCTAssertEqual(after, before)
        XCTAssertTrue(words(in: launch).isEmpty)
        XCTAssertEqual(block("about", in: sheet)["title"], "Recovery words")
    }

    func testAReadAsTheSheetOpensNeverAsksForTouchID() async throws {
        _ = try store.keyMadeOnce()
        _ = try await frame(["reveal"], page: "about")
        let before = await app.asked

        _ = try await frame(["show"])

        let after = await app.asked
        XCTAssertEqual(after, before)
    }

    func testASheetThatOpensAgainOffersTheWordsAgainAndKeepsTheCheckWhole() async throws {
        _ = try store.keyMadeOnce()
        _ = try await frame(["reveal"], page: "about")

        let reopened = try await frame(["show"])
        _ = try await frame(["wrote"], page: "about")
        let check = try await frame(["show"], page: "check")

        XCTAssertTrue(words(in: reopened).isEmpty)
        XCTAssertEqual(block("about", in: reopened)["title"], "Recovery words")
        XCTAssertEqual(picks(in: check).count, 8)
    }

    func testSignOutAsksForTouchIDAndRemovesTheKey() async throws {
        _ = try store.keyMadeOnce()
        try store.markBackedUp()

        let pushed = try await effects(["leave"])
        XCTAssertEqual(pushed, [push("leave")])
        let leave = try await frame(["show"], page: "leave")
        let out = try await said(["sign_out"], page: "leave")

        XCTAssertEqual(block("head", in: leave)["title"], "Sign out of your account?")
        XCTAssertNil(try store.key())
        XCTAssertEqual(block("head", in: out.frame)["title"], "You need a key to publish")
        XCTAssertEqual(out.effects, [.route(.pop(all: true)), .toast("Signed out")])
        let asked = await app.asked
        XCTAssertEqual(asked, ["sign out of your account"])
    }
}
