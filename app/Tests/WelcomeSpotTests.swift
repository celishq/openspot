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

    func testAReadShowsAnEmptyKeyFieldAndKeepNamesTheCurrentKey() async throws {
        try file.set("panel-key", to: "option+space")

        let output = try await read()

        let key = try part("key", in: output)
        XCTAssertEqual(key.control, .shortcut(""))
        XCTAssertEqual(try part("keep", in: output).title, "Keep ⌥Space")
        XCTAssertEqual(try part("use", in: output).title, "Use this key")
        XCTAssertEqual(try part("again", in: output).title, "Try again")
        XCTAssertNil(output.move)
    }

    func testAFailingStatusFailsTheReadAndNamesNoKey() async throws {
        try fake("openspot", "exit 1")

        do {
            _ = try await read()
            XCTFail("showed a key with no status")
        } catch {}
    }

    func testKeepNamesTheStandardKeyWithNoFile() async throws {
        let output = try await read()

        XCTAssertEqual(try part("keep", in: output).title, "Keep ⌃Space")
    }

    func testKeepNamesTheKeyAsTheAppLabelsIt() async throws {
        for text in ["cmd+ctrl+option+shift+k", "cmd+option+k", "ctrl+return", "option+left", "ctrl+up", "ctrl+tab"] {
            try file.set("panel-key", to: text)

            let output = try await read()

            XCTAssertEqual(try part("keep", in: output).title, "Keep \(try XCTUnwrap(Shortcut(text: text)).label)", text)
        }
    }

    func testAKeyIsKeptUntilUseSavesIt() async throws {
        try file.set("panel-key", to: "option+space")

        let kept = try await answer(["key", "ctrl+option+space"])
        let again = try await read()
        let before = file.read().panelKey
        let used = try await answer(["use"])

        XCTAssertEqual(try part("key", in: kept).control, .shortcut("ctrl+option+space"))
        XCTAssertEqual(try part("key", in: again).control, .shortcut("ctrl+option+space"))
        XCTAssertEqual(before, Shortcut(text: "option+space"))
        XCTAssertEqual(file.read().panelKey, Shortcut(text: "ctrl+option+space"))
        XCTAssertEqual(used.move, .pop(all: false))
    }

    func testKeepAndUseWithNoKeyChangeNothing() async throws {
        try file.set("panel-key", to: "option+space")

        let kept = try await answer(["keep"])
        let used = try await answer(["use"])

        XCTAssertEqual(kept.move, .pop(all: false))
        XCTAssertNil(used.move)
        XCTAssertEqual(used.toast, "Press the keys you want first.")
        XCTAssertEqual(file.read().panelKey, Shortcut(text: "option+space"))
    }

    func testKeepForgetsAKeyThatWasRecorded() async throws {
        _ = try await answer(["key", "ctrl+option+space"])

        _ = try await answer(["keep"])
        let output = try await read()

        XCTAssertEqual(try part("key", in: output).control, .shortcut(""))
    }

    func testAgainClearsTheKey() async throws {
        _ = try await answer(["key", "ctrl+option+space"])

        let output = try await answer(["again"])

        XCTAssertEqual(try part("key", in: output).control, .shortcut(""))
        let next = try await read()
        XCTAssertEqual(try part("key", in: next).control, .shortcut(""))
    }

    private func button(on name: String, in output: SpotOutput) -> String? {
        output.parts.first { $0.key == ActionKey(name: name) }?.id
    }

    func testEscKeepsTheKeyWhileItListensAndTriesAgainOnceAKeyShows() async throws {
        let listening = try await read()
        XCTAssertEqual(button(on: "escape", in: listening), "keep")
        XCTAssertEqual(button(on: "backspace", in: listening), "again")

        let shown = try await answer(["key", "ctrl+option+space"])
        XCTAssertEqual(button(on: "escape", in: shown), "again")
        XCTAssertNil(try part("keep", in: shown).key)

        let again = try await answer(["again"])
        XCTAssertEqual(button(on: "escape", in: again), "keep")
    }

    func testEachBlockHasAPlaceSoNoButtonBecomesAnAction() async throws {
        let output = try await read()

        XCTAssertEqual(output.actions, [])
        XCTAssertEqual(output.layout?.areas.keys.sorted(), ["again", "keep", "key", "use"])
    }
}
