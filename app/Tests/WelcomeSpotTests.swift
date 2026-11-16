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

    private func read() async throws -> SpotOutput {
        try await welcome.items(timeout: 60)
    }

    private func part(_ id: String, in output: SpotOutput) throws -> SpotPart {
        try XCTUnwrap(output.parts.first { $0.id == id })
    }

    func testItTakesTheLaunchRoleOffersNoCardAndItsHeaderNamesThePage() throws {
        let spot = try welcome

        XCTAssertEqual(spot.edits, .launch)
        XCTAssertFalse(spot.offersCard)
        XCTAssertEqual(spot.name, "Choose your key")
        XCTAssertEqual(spot.subtitle, "It opens Openspot from any app")
        XCTAssertEqual(spot.symbol, "keyboard")
    }

    func testAReadShowsTheCurrentKeyChosenWithUseAndRecord() async throws {
        try file.set("panel-key", to: "option+space")

        let output = try await read()

        XCTAssertEqual(try part("key", in: output).control, .shortcut("option+space"))
        let use = try part("use", in: output)
        XCTAssertEqual(use.title, "Use this key")
        XCTAssertEqual(use.key, ActionKey(name: "return"))
        let record = try part("record", in: output)
        XCTAssertEqual(record.title, "Record new combination")
        XCTAssertEqual(record.records, "key")
        XCTAssertEqual(record.key, ActionKey(name: "escape"))
        XCTAssertEqual(output.parts.map(\.id).sorted(), ["key", "record", "use"])
        XCTAssertNil(output.move)
    }

    func testAReadWithNoKeyInTheFileShowsTheStandardKey() async throws {
        let output = try await read()

        XCTAssertEqual(try part("key", in: output).control, .shortcut("ctrl+space"))
    }

    func testAFailingStatusFailsTheReadAndNamesNoKey() async throws {
        try fake("openspot", "exit 1")

        do {
            _ = try await read()
            XCTFail("showed a key with no status")
        } catch {}
    }

    func testARecordedKeyShowsUntilUseSavesIt() async throws {
        try file.set("panel-key", to: "option+space")

        let kept = try await answer(["key", "ctrl+option+space"])
        let again = try await read()
        let before = file.read().panelKey
        let used = try await answer(["use"])
        let after = try await read()

        XCTAssertEqual(try part("key", in: kept).control, .shortcut("ctrl+option+space"))
        XCTAssertEqual(try part("key", in: again).control, .shortcut("ctrl+option+space"))
        XCTAssertEqual(before, Shortcut(text: "option+space"))
        XCTAssertEqual(file.read().panelKey, Shortcut(text: "ctrl+option+space"))
        XCTAssertEqual(used.move, .pop(all: false))
        XCTAssertEqual(try part("key", in: after).control, .shortcut("ctrl+option+space"))
    }

    func testUseWithTheCurrentKeyLeavesAndChangesNothing() async throws {
        try file.set("panel-key", to: "option+space")

        let used = try await answer(["use"])

        XCTAssertEqual(used.move, .pop(all: false))
        XCTAssertEqual(file.read().panelKey, Shortcut(text: "option+space"))
    }

    func testEachBlockHasAPlaceSoNoButtonBecomesAnAction() async throws {
        let output = try await read()

        XCTAssertEqual(output.actions, [])
        XCTAssertEqual(output.layout?.areas.keys.sorted(), ["key", "record", "use"])
    }
}
