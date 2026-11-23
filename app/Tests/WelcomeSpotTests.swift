import XCTest
@testable import OpenspotCore

final class WelcomeSpotTests: BuiltInCase {
    private var welcome: Spot {
        get throws {
            try spot("welcome")
        }
    }

    private func answer(_ arguments: [String]) async throws -> Frame {
        try await welcome.answer(arguments[0], input: arguments.count > 1 ? "input.value=\(arguments[1])\n" : nil, timeout: 60)
    }

    private func read(page: String? = nil) async throws -> Frame {
        try await welcome.items(page: page, timeout: 60)
    }

    private func part(_ id: String, in output: Frame) throws -> SpotPart {
        try XCTUnwrap(output.parts.first { $0.id == id })
    }

    private func head(in output: Frame) throws -> ViewNode {
        try XCTUnwrap(output.tree.node("head"))
    }

    private func name(_ path: String?) -> String? {
        path.map { URL(fileURLWithPath: $0).lastPathComponent }
    }

    private func assertHead(_ output: Frame, _ title: String, _ detail: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let head = try head(in: output)
        XCTAssertEqual(head.kind, "welcome", file: file, line: line)
        XCTAssertEqual(head.block.value("grow"), "false", file: file, line: line)
        XCTAssertEqual(head.values["title"], [title], file: file, line: line)
        XCTAssertEqual(head.values["detail"], [detail], file: file, line: line)
    }

    func testItStartsTheFirstLaunchWithTwoPagesAndOffersNoCard() throws {
        let spot = try welcome

        XCTAssertEqual(spot.starts, .firstLaunch)
        XCTAssertEqual(Config(text: try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("defaults.toml"), encoding: .utf8)).arrangement.isOnGrid(of: "openspot/welcome"), false)
        XCTAssertEqual(spot.name, "Welcome spot")
        XCTAssertNil(spot.subtitle)
        XCTAssertEqual(spot.symbol, "hand.wave")
        XCTAssertEqual(spot.pages, ["key", "agent"])
        XCTAssertEqual(spot.views["welcome"].map { URL(fileURLWithPath: $0).lastPathComponent }, "welcome.swift")
    }

    func testTheFirstSheetSaysEverythingIsASpotUnderItsDrawingAndContinues() async throws {
        let output = try await read()

        try assertHead(output, "Everything is a disposable spot", "Make a script or an app for anything. Keep it, throw it away, or share it in one click.")
        XCTAssertEqual(name(try head(in: output).values["icon"]?.last), "even-this-onboarding.svg")
        XCTAssertEqual(output.tree.children, ["head", "next"])
        let next = try part("next", in: output)
        XCTAssertEqual(next.title, "Continue")
        XCTAssertEqual(next.key, ActionKey(name: "return"))
    }

    func testContinuePushesTheKeyPage() async throws {
        let effects = try recordEffects()

        _ = try await answer(["next"])

        XCTAssertEqual(effects(), ["route push key --title Choose your key"])
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
        XCTAssertEqual(record.key, ActionKey(name: "escape"))
        XCTAssertEqual(output.tree.children, ["head", "key", "use", "record"])
        XCTAssertFalse(try part("key", in: output).asksToRecord)
    }

    func testRecordAsksTheKeyFieldToRecordAndKeepsTheKey() async throws {
        try file.set("panel-key", to: "option+space")

        let output = try await answer(["record"])

        let key = try part("key", in: output)
        XCTAssertTrue(key.asksToRecord)
        XCTAssertEqual(key.control, .shortcut("option+space"))
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
        let effects = try recordEffects()

        let kept = try await answer(["key", "ctrl+option+space"])
        let again = try await read(page: "key")
        let before = file.read().panelKey
        _ = try await answer(["use"])
        let after = try await read(page: "key")

        XCTAssertEqual(try part("key", in: kept).control, .shortcut("ctrl+option+space"))
        XCTAssertEqual(try part("key", in: again).control, .shortcut("ctrl+option+space"))
        XCTAssertEqual(before, Shortcut(text: "option+space"))
        XCTAssertEqual(file.read().panelKey, Shortcut(text: "ctrl+option+space"))
        XCTAssertEqual(effects(), ["route push agent --title Make it yours"])
        XCTAssertEqual(try part("key", in: after).control, .shortcut("ctrl+option+space"))
    }

    func testUseWithTheCurrentKeyPushesTheLastPageAndChangesNothing() async throws {
        try file.set("panel-key", to: "option+space")
        let effects = try recordEffects()

        _ = try await answer(["use"])

        XCTAssertEqual(effects(), ["route push agent --title Make it yours"])
        XCTAssertEqual(file.read().panelKey, Shortcut(text: "option+space"))
    }

    func testTheLastPageShowsTwoNumberedCardsToTryAndDoneLeaves() async throws {
        let effects = try recordEffects()
        let output = try await read(page: "agent")
        _ = try await answer(["done"])

        try assertHead(output, "Make it yours", "Easily, with any of your favourite agents")
        let head = try head(in: output)
        XCTAssertEqual(name(head.values["note"]?.last), "note-and-pls.svg")
        XCTAssertEqual(output.tree.children, ["head", "done"])
        XCTAssertEqual(head.values["card.title"], ["Create your own spot", "Change it with your agent"])
        XCTAssertEqual(head.values["card.detail"], ["Open New spot and describe it.", "Select it and press ⌘E."])
        XCTAssertEqual(head.values["card.icon"], ["plus", "pencil"])
        XCTAssertEqual(head.values["card.note"]?.map { name($0) }, ["note-1.svg", "note-2.svg"])
        let button = try part("done", in: output)
        XCTAssertEqual(button.title, "Start using Openspot")
        XCTAssertEqual(button.key, ActionKey(name: "return"))
        let opened = await app.opened
        XCTAssertEqual(opened, [])
        XCTAssertEqual(effects(), ["route close", "toast \(Shortcut.standard.openHint)"])
    }

    func testEachDrawingThatAPageNamesIsAFileBesideTheScript() async throws {
        for page in [nil, "key", "agent"] {
            let output = try await read(page: page)

            let head = try head(in: output)
            let paths = ["icon", "note", "card.note"].flatMap { head.values[$0] ?? [] }
            for path in paths {
                XCTAssertTrue(FileManager.default.fileExists(atPath: path), path)
            }
        }
    }

    func testEachBlockOfEachPageHasAPlaceSoNoButtonBecomesAnAction() async throws {
        for page in [nil, "key", "agent"] {
            let output = try await read(page: page)

            XCTAssertEqual(output.actions, [], "\(page ?? "first")")
            XCTAssertEqual(output.tree.children.sorted(), output.parts.map(\.id).sorted(), "\(page ?? "first")")
        }
    }
}
