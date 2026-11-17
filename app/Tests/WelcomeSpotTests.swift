import XCTest
@testable import OpenspotCore

final class WelcomeSpotTests: BuiltInCase {
    private var welcome: Spot {
        get throws {
            try spot("welcome")
        }
    }

    private func answer(_ arguments: [String]) async throws -> SpotOutput {
        try await welcome.answer(SpotAction(arguments: arguments), timeout: 60)
    }

    private func read(page: String? = nil) async throws -> SpotOutput {
        try await welcome.items(page: page, timeout: 60)
    }

    private func part(_ id: String, in output: SpotOutput) throws -> SpotPart {
        try XCTUnwrap(output.parts.first { $0.id == id })
    }

    private func assertHead(_ output: SpotOutput, _ title: String, _ detail: String, icon: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let head = try part("head", in: output)
        XCTAssertEqual(head.title, title, file: file, line: line)
        XCTAssertEqual(head.detail, detail, file: file, line: line)
        XCTAssertEqual(head.symbol, icon, file: file, line: line)
    }

    func testItTakesTheLaunchRoleWithTwoPagesAndOffersNoCard() throws {
        let spot = try welcome

        XCTAssertEqual(spot.edits, .launch)
        XCTAssertFalse(spot.offersCard)
        XCTAssertEqual(spot.name, "Welcome")
        XCTAssertEqual(spot.subtitle, "Openspot in three steps")
        XCTAssertEqual(spot.symbol, "hand.wave")
        XCTAssertEqual(spot.pages, ["key", "agent"])
    }

    func testTheFirstSheetWelcomesWithThreeLinesAndContinue() async throws {
        let output = try await read()

        try assertHead(output, "Welcome to Openspot", "The launcher that grows with you", icon: "hand.wave")
        XCTAssertEqual(output.parts.map(\.id).sorted(), ["agents", "head", "next", "opens", "spots"])
        let next = try part("next", in: output)
        XCTAssertEqual(next.title, "Continue")
        XCTAssertEqual(next.key, ActionKey(name: "return"))
    }

    func testContinuePushesTheKeyPage() async throws {
        let output = try await answer(["next"])

        XCTAssertEqual(output.move, .push(spot: nil, page: "key", title: "Choose your key", replace: false))
    }

    func testTheKeyPageShowsTheCurrentKeyChosenWithUseAndRecord() async throws {
        try file.set("panel-key", to: "option+space")

        let output = try await read(page: "key")

        try assertHead(output, "Choose your key", "It opens Openspot from any app", icon: "keyboard")
        XCTAssertEqual(try part("key", in: output).control, .shortcut("option+space"))
        let use = try part("use", in: output)
        XCTAssertEqual(use.title, "Use this key")
        XCTAssertEqual(use.key, ActionKey(name: "return"))
        let record = try part("record", in: output)
        XCTAssertEqual(record.title, "Record new combination")
        XCTAssertEqual(record.records, "key")
        XCTAssertEqual(record.key, ActionKey(name: "escape"))
        XCTAssertEqual(output.parts.map(\.id).sorted(), ["head", "key", "record", "use"])
        XCTAssertNil(output.move)
    }

    func testTheKeyPageWithNoKeyInTheFileShowsTheStandardKey() async throws {
        let output = try await read(page: "key")

        XCTAssertEqual(try part("key", in: output).control, .shortcut("ctrl+space"))
    }

    func testAFailingStatusFailsTheKeyPageAndNamesNoKey() async throws {
        try fake("openspot", "exit 1")

        do {
            _ = try await read(page: "key")
            XCTFail("showed a key with no status")
        } catch {}
    }

    func testARecordedKeyShowsUntilUseSavesItAndPushesTheLastPage() async throws {
        try file.set("panel-key", to: "option+space")

        let kept = try await answer(["key", "ctrl+option+space"])
        let again = try await read(page: "key")
        let before = file.read().panelKey
        let used = try await answer(["use"])
        let after = try await read(page: "key")

        XCTAssertEqual(try part("key", in: kept).control, .shortcut("ctrl+option+space"))
        XCTAssertEqual(try part("key", in: again).control, .shortcut("ctrl+option+space"))
        XCTAssertEqual(before, Shortcut(text: "option+space"))
        XCTAssertEqual(file.read().panelKey, Shortcut(text: "ctrl+option+space"))
        XCTAssertEqual(used.move, .push(spot: nil, page: "agent", title: "Make it yours", replace: false))
        XCTAssertEqual(try part("key", in: after).control, .shortcut("ctrl+option+space"))
    }

    func testUseWithTheCurrentKeyPushesTheLastPageAndChangesNothing() async throws {
        try file.set("panel-key", to: "option+space")

        let used = try await answer(["use"])

        XCTAssertEqual(used.move, .push(spot: nil, page: "agent", title: "Make it yours", replace: false))
        XCTAssertEqual(file.read().panelKey, Shortcut(text: "option+space"))
    }

    func testTheLastPageSaysAnAgentChangesAnySpotAndDoneLeaves() async throws {
        let output = try await read(page: "agent")
        let done = try await answer(["done"])

        try assertHead(output, "Make it yours", "Your agent writes and changes spots", icon: "sparkles")
        XCTAssertEqual(output.parts.map(\.id).sorted(), ["copy", "done", "edit", "file", "head", "new"])
        let button = try part("done", in: output)
        XCTAssertEqual(button.title, "Start using Openspot")
        XCTAssertEqual(button.key, ActionKey(name: "return"))
        XCTAssertEqual(done.move, .pop(all: true))
    }

    func testEachBlockOfEachPageHasAPlaceSoNoButtonBecomesAnAction() async throws {
        for page in [nil, "key", "agent"] {
            let output = try await read(page: page)

            XCTAssertEqual(output.actions, [], "\(page ?? "first")")
            XCTAssertEqual(output.layout?.areas.keys.sorted(), output.parts.map(\.id).sorted(), "\(page ?? "first")")
        }
    }
}
