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

    private func assertHead(_ output: SpotOutput, _ title: String, _ detail: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let head = try part("head", in: output)
        XCTAssertEqual(head.look, .heading, file: file, line: line)
        XCTAssertEqual(head.title, title, file: file, line: line)
        XCTAssertEqual(head.detail, detail, file: file, line: line)
    }

    func testItStartsTheFirstLaunchWithTwoPagesAndOffersNoCard() throws {
        let spot = try welcome

        XCTAssertEqual(spot.starts, .firstLaunch)
        XCTAssertFalse(spot.offersCard)
        XCTAssertEqual(spot.name, "Welcome spot")
        XCTAssertNil(spot.subtitle)
        XCTAssertEqual(spot.symbol, "hand.wave")
        XCTAssertEqual(spot.pages, ["key", "agent"])
    }

    func testTheFirstSheetSaysEverythingIsASpotUnderItsDrawingAndContinues() async throws {
        let output = try await read()

        try assertHead(output, "Everything is a disposable spot", "Make a script or an app for anything. Keep it, throw it away, or share it in one click.")
        XCTAssertEqual(try part("head", in: output).image.map { URL(fileURLWithPath: $0).lastPathComponent }, "even-this-onboarding.svg")
        XCTAssertEqual(output.parts.map(\.id).sorted(), ["head", "next"])
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

        try assertHead(output, "Choose your key", "It opens Openspot from any app.")
        XCTAssertEqual(try part("key", in: output).control, .shortcut("option+space"))
        let use = try part("use", in: output)
        XCTAssertEqual(use.title, "Use this key")
        XCTAssertEqual(use.key, ActionKey(name: "return"))
        let record = try part("record", in: output)
        XCTAssertEqual(record.title, "Record another key")
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

    func testTheLastPageShowsTwoNumberedCardsToTryAndDoneLeaves() async throws {
        let output = try await read(page: "agent")
        let done = try await answer(["done"])
        let name = { (path: String?) in path.map { URL(fileURLWithPath: $0).lastPathComponent } }

        try assertHead(output, "Make it yours", "Easily, with any of your favourite agents")
        XCTAssertEqual(name(try part("head", in: output).note), "note-and-pls.svg")
        XCTAssertEqual(output.parts.map(\.id).sorted(), ["done", "edit", "head", "new"])
        for (id, title, symbol, note) in [("new", "Create your own spot", "plus", "note-1.svg"), ("edit", "Change it with your agent", "pencil", "note-2.svg")] {
            let card = try part(id, in: output)
            XCTAssertEqual(card.look, .card, id)
            XCTAssertEqual(card.title, title, id)
            XCTAssertEqual(card.symbol, symbol, id)
            XCTAssertEqual(name(card.note), note, id)
        }
        let button = try part("done", in: output)
        XCTAssertEqual(button.title, "Start using Openspot")
        XCTAssertEqual(button.key, ActionKey(name: "return"))
        let opened = await app.opened
        XCTAssertEqual(opened, ["pop openspot/welcome all"])
        XCTAssertEqual(done.move, .pop(all: false))
        XCTAssertEqual(done.toast, Shortcut.standard.openHint)
    }

    func testEachDrawingThatAPageNamesIsAFileBesideTheScript() async throws {
        for page in [nil, "key", "agent"] {
            let output = try await read(page: page)

            for path in output.parts.flatMap({ [$0.image, $0.note].compactMap { $0 } }) {
                XCTAssertTrue(FileManager.default.fileExists(atPath: path), path)
            }
        }
    }

    func testEachBlockOfEachPageHasAPlaceSoNoButtonBecomesAnAction() async throws {
        for page in [nil, "key", "agent"] {
            let output = try await read(page: page)

            XCTAssertEqual(output.actions, [], "\(page ?? "first")")
            XCTAssertEqual(output.layout?.areas.keys.sorted(), output.parts.map(\.id).sorted(), "\(page ?? "first")")
        }
    }
}
