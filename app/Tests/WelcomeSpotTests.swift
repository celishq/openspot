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

    private func node(_ id: String, in output: Frame) throws -> ViewNode {
        try XCTUnwrap(output.tree.node(id))
    }

    private func name(_ path: String?) -> String? {
        path.map { URL(fileURLWithPath: $0).lastPathComponent }
    }

    private func assertHead(_ output: Frame, _ title: String, _ detail: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let head = try node("head", in: output)
        XCTAssertEqual(head.kind, .box, file: file, line: line)
        XCTAssertNil(head.style.height, file: file, line: line)
        XCTAssertEqual(try part("title", in: output).title, title, file: file, line: line)
        XCTAssertEqual(try node("title", in: output).style.font, .heading, file: file, line: line)
        XCTAssertEqual(try part("detail", in: output).title, detail, file: file, line: line)
        XCTAssertEqual(try node("detail", in: output).style.font, .lead, file: file, line: line)
        XCTAssertEqual(try node("end", in: output).style.padding[.top], .steps(6), file: file, line: line)
        XCTAssertEqual(head.style.padding[.top], .steps(3), file: file, line: line)
    }

    private func assertDrawing(_ output: Frame, _ file: String, after: String, line: UInt = #line) throws {
        let note = try node("note", in: output)
        XCTAssertEqual(note.kind.name, "welcome", line: line)
        XCTAssertEqual(note.style.height, .steps(10), line: line)
        XCTAssertEqual(name(note.values["drawing"]?.last), file, line: line)
        let head = try node("head", in: output).children
        XCTAssertEqual(head.firstIndex(of: "note"), head.firstIndex(of: after).map { $0 + 1 }, line: line)
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
        try assertDrawing(output, "even-this-onboarding.svg", after: "title")
        XCTAssertEqual(output.tree.children, ["head", "end"])
        let next = try part("next", in: output)
        XCTAssertEqual(next.title, "Continue")
        XCTAssertNil(next.key)
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
        XCTAssertNil(use.key)
        let record = try part("record", in: output)
        XCTAssertEqual(record.title, "Record another key")
        XCTAssertEqual(record.key, ActionKey(name: "backspace"))
        XCTAssertEqual(output.tree.children, ["head", "body", "end"])
        XCTAssertEqual(try node("body", in: output).children, ["key"])
        XCTAssertEqual(try node("body", in: output).style.padding[.top], .steps(5))
        XCTAssertEqual(try node("end", in: output).children, ["use", "record"])
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
        try assertDrawing(output, "note-and-pls.svg", after: "detail")
        XCTAssertEqual(output.tree.children, ["head", "cards", "end"])
        XCTAssertEqual(try node("cards", in: output).children, ["card-1", "card-2"])
        let cards = try ["card-1", "card-2"].map { try node($0, in: output) }
        XCTAssertEqual(cards.map(\.style.height), [.steps(16), .steps(16)])
        XCTAssertEqual(cards.map { $0.values["title"]?.last }, ["Create your own spot", "Change it with your agent"])
        XCTAssertEqual(cards.map { $0.values["detail"]?.last }, ["Open New spot and describe it.", "Select it and press ⌘E."])
        XCTAssertEqual(cards.map { $0.values["icon"]?.last }, ["plus", "pencil"])
        XCTAssertEqual(cards.map { name($0.values["note"]?.last) }, ["note-1.svg", "note-2.svg"])
        let button = try part("done", in: output)
        XCTAssertEqual(button.title, "Start using Openspot")
        XCTAssertNil(button.key)
        let opened = await app.opened
        XCTAssertEqual(opened, [])
        XCTAssertEqual(effects(), ["route close", "toast \(Shortcut.standard.openHint)"])
    }

    func testEachDrawingThatAPageNamesIsAFileBesideTheScript() async throws {
        for page in [nil, "key", "agent"] {
            let output = try await read(page: page)

            let paths = ["note", "card-1", "card-2"].compactMap { output.tree.node($0) }.flatMap { ($0.values["drawing"] ?? []) + ($0.values["note"] ?? []) }
            XCTAssertEqual(paths.isEmpty, page == "key", page ?? "first")
            for path in paths {
                XCTAssertTrue(FileManager.default.fileExists(atPath: path), path)
            }
        }
    }

    func testEachBlockOfEachPageHasAPlaceSoNoButtonBecomesAnAction() async throws {
        for page in [nil, "key", "agent"] {
            let output = try await read(page: page)

            XCTAssertEqual(output.actions, [], "\(page ?? "first")")
            XCTAssertTrue(output.parts.allSatisfy { output.tree.node($0.id) != nil }, "\(page ?? "first")")
        }
    }
}
