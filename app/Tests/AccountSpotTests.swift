import XCTest
@testable import OpenspotCore

final class AccountSpotTests: BuiltInCase {
    private let phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private var process: ScriptProcess?
    private var received: [String] = []
    private var call = 0
    private var shown: [String] = []

    override func tearDown() async throws {
        process?.end()
        try await super.tearDown()
    }

    private var store: AccountStore {
        AccountStore.standard(environment: ["OPENSPOT_CONFIG": root.path], home: root, devState: nil)
    }

    private func frame(_ arguments: [String], input: String? = nil, page: String? = nil, reason: String = "sheet.open") async throws -> String {
        if process == nil {
            let (script, stream, _) = runs.stay(try spot("account"), limit: 60)
            process = script
            Task { [weak self] in
                for try await next in stream { self?.received.append(next) }
            }
        }
        call += 1
        let id = String(call)
        var variables = arguments == ["read"] ? ["OPENSPOT_REASON": reason] : [:]
        if let page { variables["OPENSPOT_PAGE"] = page }
        let start = received.count
        process?.send(SpotAction(arguments: arguments), input: input, variables: variables, id: call)
        try await wait("the end of call \(id)") { self.received.dropFirst(start).contains { SpotOutput(text: $0).ends == [id] } }
        let text = received.dropFirst(start).filter { !FrameHead(text: $0).isMark && SpotOutput(text: $0).ends.isEmpty }.joined()
        shown.append(text)
        return text
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

    private func head(_ key: String, in frame: String) -> String? {
        frame.split(separator: "\n").first { $0.hasPrefix("\(key)=") }.map { String($0.dropFirst(key.count + 1)) }
    }

    private func words(in frame: String) -> [String] {
        (1...12).compactMap { block("w\($0)", in: frame)["title"] }
    }

    private func picks(in frame: String) -> [(id: String, place: Int, word: String)] {
        frame.components(separatedBy: "\n\n").compactMap { block in
            let keys = Dictionary(block.split(separator: "\n").compactMap { line -> (String, String)? in
                let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
                return parts.count == 2 ? (parts[0], parts[1]) : nil
            }) { first, _ in first }
            guard let id = keys["button"], id.hasPrefix("pick-"), let word = keys["title"] else { return nil }
            return (id, Int(id.split(separator: "-")[1]) ?? 0, word)
        }
    }

    private func everything(in folder: URL) -> String {
        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        return files.compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
    }

    func testItShipsWithTheAppReachesTheKeyAndDrawsTheCardOfTheApp() throws {
        let account = try spot("account")

        XCTAssertEqual(account.name, "Account")
        XCTAssertTrue(account.isFound)
        XCTAssertTrue(account.isBuiltIn)
        XCTAssertTrue(account.reachesAccountKey)
        XCTAssertEqual(account.view, "openspot:account-card")
        XCTAssertEqual(account.mode, .stay)
        XCTAssertFalse(account.read?.has(.panel) == true)
    }

    func testAViewOfTheAppIsDroppedFromASpotThatIsNotOfTheApp() throws {
        try "#!/bin/sh\n# title=Fake\n# on=sheet.open\n# view=openspot:account-card\n".writeScript(to: spots.appendingPathComponent("fake.spot/fake.sh"))

        let fake = try XCTUnwrap(try SpotsFolder(url: spots).scan().spots.first { $0.id == "fake" })

        XCTAssertNil(fake.view)
    }

    func testWithNoAccountItOffersANewKeyOrYourOwn() async throws {
        let read = try await frame(["read"])

        XCTAssertEqual(block("head", in: read)["title"], "You need a key to publish")
        XCTAssertEqual(block("new", in: read)["title"], "Create a new key")
        XCTAssertEqual(block("new", in: read)["look"], "strong")
        XCTAssertEqual(block("own", in: read)["title"], "Use my own key")
        XCTAssertTrue(read.hasPrefix("grid=head head\ngrid=head head\ngrid=new new\ngrid=own how\n"), read)
    }

    func testANewKeyAsksForAHandleThenMakesTheKeyAndGoesBackToTheAccount() async throws {
        let pushed = try await frame(["new"])
        let asked = try await frame(["read"], page: "handle")
        XCTAssertEqual(head("push", in: pushed), "handle")
        XCTAssertNil(try store.key())
        XCTAssertEqual(block("handle", in: asked)["grow"], "false")
        XCTAssertEqual(block("label", in: asked)["title"], "Handle")
        XCTAssertTrue(asked.contains("grid=back create\n"), asked)

        let made = try await frame(["create"], input: "handle=tony\n", page: "handle")
        let account = try await frame(["read"])

        XCTAssertEqual(try store.record()?.handle, "tony")
        XCTAssertEqual(head("pop", in: made), "all")
        XCTAssertEqual(block("card", in: account)["handle"], "tony")
        XCTAssertEqual(block("card", in: account)["npub"], try store.key()?.npub)
        XCTAssertEqual(block("card", in: account)["grow"], "false")
        XCTAssertEqual(block("about", in: account)["detail"], "Not saved yet")
        XCTAssertTrue(account.contains("grid=- -\ngrid=how leave\n"), account)
    }

    func testTypingAHandleCleansItAndATooShortOneKeepsThePageAndSaysTheRule() async throws {
        let typed = try await frame(["handle", "Zoë O'Neil-Smith"], page: "handle")
        let short = try await frame(["handle", "T."], page: "handle")
        let refused = try await frame(["create"], input: "handle=T.\n", page: "handle")

        XCTAssertEqual(block("handle", in: typed)["value"], "zooneil-smith")
        XCTAssertNil(block("status", in: typed)["title"])
        XCTAssertEqual(block("status", in: short)["title"], AccountHandle.rule)
        XCTAssertNil(try store.key())
        XCTAssertEqual(block("status", in: refused)["title"], AccountHandle.rule)
    }

    func testThePillOfTheCardCopiesTheKeyAndSaysSo() async throws {
        let key = try store.keyMadeOnce(handle: "tony")

        let copied = try await frame(["card", "copy"])

        XCTAssertEqual(head("toast", in: copied), "Copied your key")
        XCTAssertEqual(mac.copied, [key.npub])
    }

    func testHowItWorksIsAPageThatDoneLeaves() async throws {
        let read = try await frame(["read"])
        let pushed = try await frame(["how"])
        let how = try await frame(["read"], page: "how")
        let done = try await frame(["done"], page: "how")

        XCTAssertEqual(block("how", in: read)["scope"], "spot")
        XCTAssertEqual(head("push", in: pushed), "how")
        XCTAssertEqual(block("head", in: how)["title"], "How your key works")
        XCTAssertEqual(head("pop", in: done), "true")
    }

    func testANewKeyOnThePublishPageTakesItsPlaceThenPublishesAndGoesBackToTheStore() async throws {
        let choice = try await frame(["read"], page: "publish:a")
        let step = try await frame(["new"], page: "publish:a")
        let back = try await frame(["back"], page: "handle:a")
        let done = try await frame(["create"], input: "handle=tony\n", page: "handle:a")

        XCTAssertEqual(block("new", in: choice)["title"], "Create a new key")
        XCTAssertEqual(head("push", in: step), "handle:a")
        XCTAssertEqual(head("push.replace", in: step), "true")
        XCTAssertEqual(head("push", in: back), "publish:a")
        XCTAssertNotNil(try store.key())
        XCTAssertEqual(head("pop", in: done), "true")
    }

    func testThePhraseSaysWhatIsWrongAsItIsTypedAndSignsIn() async throws {
        let empty = try await frame(["read"], page: "restore")
        let counting = try await frame(["phrase", "abandon"], input: "phrase=abandon\n", page: "restore")
        let typing = try await frame(["phrase", "abandon abuot abso"], input: "phrase=abandon abuot abso\n", page: "restore")
        let completing = try await frame(["phrase", "abandon abso"], input: "phrase=abandon abso\n", page: "restore")
        let ready = try await frame(["phrase", phrase], input: "phrase=\(phrase)\n", page: "restore")
        let signedIn = try await frame(["sign_in"], input: "phrase=\(phrase)\n", page: "restore")

        XCTAssertTrue(empty.contains("grid=phrase phrase\ngrid=phrase phrase\ngrid=phrase phrase\ngrid=back sign_in\n"), empty)
        XCTAssertEqual(block("status", in: counting)["title"], "1 of 12")
        XCTAssertEqual(block("status", in: typing)["title"], "abuot isn't an account word")
        XCTAssertEqual(block("status", in: completing)["title"], "Did you mean absorb?")
        XCTAssertEqual(block("status", in: ready)["title"], "Signs in as")
        XCTAssertEqual(head("toast", in: signedIn), "Signed in")
        XCTAssertEqual(head("pop", in: signedIn), "all")
        XCTAssertTrue(try store.record()?.isBackedUp == true)
    }

    func testAReadNeverShowsTheWordsNorAsksForTouchID() async throws {
        _ = try store.keyMadeOnce()
        _ = try await frame(["show"], page: "about")
        let before = await app.asked

        let launch = try await frame(["read"], reason: "app.launch")
        let about = try await frame(["read"], page: "about")

        let after = await app.asked
        XCTAssertEqual(after, before)
        XCTAssertTrue(words(in: launch).isEmpty)
        XCTAssertTrue(words(in: about).isEmpty)
        XCTAssertEqual(block("show", in: about)["title"], "Show my words")
    }

    func testSignOutAsksForTouchIDAndRemovesTheKey() async throws {
        _ = try store.keyMadeOnce()
        try store.markBackedUp()

        let leave = try await frame(["read"], page: "leave")
        let out = try await frame(["sign_out"], page: "leave")

        XCTAssertEqual(block("head", in: leave)["title"], "Sign out of your account?")
        XCTAssertNil(try store.key())
        XCTAssertEqual(head("toast", in: out), "Signed out")
        let asked = await app.asked
        XCTAssertEqual(asked, ["sign out of your account"])
    }

    func testAWrongPickSaysSoAndKeepsTheWordsNotBackedUp() async throws {
        let words = try XCTUnwrap(try store.keyMadeOnce().words)
        let check = try await frame(["read"], page: "check:2-7")
        let wrong = try XCTUnwrap(picks(in: check).first { $0.place == 2 && $0.word != words[1] })
        let right = try XCTUnwrap(picks(in: check).first { $0.place == 7 && $0.word == words[6] })

        let first = try await frame([wrong.id], page: "check:2-7")
        let second = try await frame([right.id], page: "check:2-7:\(wrong.id.dropFirst(5))")
        let after = try await frame(["read"], page: "check:2-7:wrong")

        XCTAssertEqual(head("push", in: first), "check:2-7:\(wrong.id.dropFirst(5))")
        XCTAssertEqual(head("push", in: second), "check:2-7:wrong")
        XCTAssertEqual(block("head", in: after)["title"], "One of these words is wrong. Look at your words again.")
        XCTAssertFalse(try store.record()?.isBackedUp == true)
    }

    func testTheWordsReachNoArgumentNoLogNoToastAndNoButton() async throws {
        let programs = try countPrograms()
        let marker = "abandon"

        _ = try await frame(["read"])
        _ = try await frame(["own"])
        _ = try await frame(["read"], page: "restore")
        _ = try await frame(["phrase", "abandon abandon"], input: "phrase=abandon abandon\n", page: "restore")
        _ = try await frame(["sign_in"], input: "phrase=\(phrase)\n", page: "restore")
        XCTAssertFalse(programs().joined(separator: "\n").contains(marker), programs().joined(separator: "\n"))
        _ = try await frame(["read"])
        let shownWords = try await frame(["show"], page: "about")
        let wrote = try await frame(["wrote"], page: "about")
        let page = try XCTUnwrap(head("push", in: wrote))
        let check = try await frame(["read"], page: page)
        let words = phrase.split(separator: " ").map(String.init)
        let picked = picks(in: check).filter { $0.word == words[$0.place - 1] }
        XCTAssertEqual(Set(picked.map(\.place)).count, 2, check)
        let one = try XCTUnwrap(picked.first)
        let first = try await frame([one.id], page: page)
        let second = try XCTUnwrap(picked.first { $0.place != one.place })
        let done = try await frame([second.id], page: try XCTUnwrap(head("push", in: first)))

        XCTAssertEqual(self.words(in: shownWords), words)
        XCTAssertEqual(head("toast", in: done), "Your words are backed up")
        XCTAssertTrue(try store.record()?.isBackedUp == true)
        let calls = programs().joined(separator: "\n")
        XCTAssertTrue(calls.contains("openspot account choices"), calls)
        XCTAssertFalse(calls.contains(marker), calls)
        let heads = shown.flatMap { $0.split(separator: "\n") }.filter { line in ["toast=", "push=", "button=", "pop="].contains { line.hasPrefix($0) } }
        XCTAssertFalse(heads.joined().contains(marker), heads.joined(separator: "\n"))
        XCTAssertFalse(everything(in: root.appendingPathComponent("logs")).contains(marker))
        runs.quit()
        XCTAssertFalse(everything(in: root.appendingPathComponent("stats")).contains(marker))
    }
}
