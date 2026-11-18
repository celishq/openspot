import XCTest
@testable import OpenspotCore

final class StoreSpotTests: BuiltInCase {
    private var effects: (() -> [String])!

    private var store: Spot {
        get throws {
            try spot("store")
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"), toml: "detail = 'Counts down'")
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("timer.spot/sample.sh"))
        try "#!/bin/sh\n".writeScript(to: root.appendingPathComponent("examples/shared.spot/shared.sh"), toml: "title = 'Shared'")
        try "#!/bin/sh\n".writeScript(to: spots.appendingPathComponent("mine.spot/mine.sh"), toml: "title = 'Mine'")
        effects = try recordEffects()
    }

    private func items() async throws -> [[String]] {
        let text = try await runs.answer(of: store, .show, limit: 60)
        XCTAssertEqual(SpotOutput(text: text).parts.map(\.id), ["gallery"])
        return TextBlock.blocks(in: text).compactMap { row in
            row.value("row").map { [$0, row.value("title") ?? "", row.value("step") ?? "", row.value("origin") ?? "", row.value("detail") ?? "", row.value("size") ?? "", row.value("sample") == "true" ? "sample" : ""] }
        }
    }

    @discardableResult
    private func call(_ arguments: [String]) async throws -> String? {
        try await store.perform(SpotAction(arguments: arguments), timeout: 60)
    }

    private func answer(_ arguments: [String]) async throws -> String {
        try await runs.answer(of: store, SpotAction(arguments: arguments), limit: 60)
    }

    private func pick(_ folder: URL) throws {
        let real = tools.appendingPathComponent("openspot-real")
        if !FileManager.default.fileExists(atPath: real.path) {
            try FileManager.default.moveItem(at: tools.appendingPathComponent("openspot"), to: real)
        }
        try fake("openspot", "if [ \"$1 $2\" = 'folder pick' ]; then echo '\(folder.path)'; exit 0; fi\nexec '\(real.path)' \"$@\"")
    }

    private func friends() throws -> URL {
        let friends = root.appendingPathComponent("friends")
        try "#!/bin/sh\n".writeScript(to: friends.appendingPathComponent("clock.spot/clock.sh"), toml: "title = 'Clock'")
        return friends
    }

    func testAddStoreKeepsThePickedFolderAndShowsItsSpotsUnderIt() async throws {
        let friends = try friends()
        try pick(friends)

        let text = try await answer(["gallery", "add"])

        XCTAssertEqual(file.read().stores.map(\.url.path), [friends.path])
        XCTAssertEqual(effects(), ["toast Added the store friends with 1 spot."])
        XCTAssertEqual(SpotOutput(text: text).parts.first?.values["folder"]?.last, "\(friends.path)\tfriends\tfound\tadded")
        XCTAssertEqual(TextBlock.blocks(in: text).first { $0.value("row") == "clock" }?.value("store"), friends.path)
    }

    func testAddStoreRefusesAFolderWithNoSpot() async throws {
        let empty = root.appendingPathComponent("empty")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        try pick(empty)

        _ = try await answer(["gallery", "add"])

        XCTAssertEqual(effects(), ["toast empty has no spot folder, so it cannot be a store. Pick a folder that holds a folder such as weather.spot."])
        XCTAssertEqual(file.read().stores, [])
    }

    func testTheBuiltInStoreComesFirstWhenTheAppHasItsExamples() async throws {
        let examples = root.appendingPathComponent("examples")
        let friends = try friends()
        _ = try file.change { $0.add(store: Store(url: friends)) }
        try FileManager.default.removeItem(at: examples)
        let before = try await runs.answer(of: store, .show, limit: 60)
        XCTAssertEqual(SpotOutput(text: before).parts.first?.values["folder"], ["\(friends.path)\tfriends\tfound\tadded"])

        try "#!/bin/sh\n".writeScript(to: examples.appendingPathComponent("year.spot/year.sh"), toml: "title = 'Year'")
        let text = try await runs.answer(of: store, .show, limit: 60)

        XCTAssertEqual(SpotOutput(text: text).parts.first?.values["folder"], ["\(examples.path)\tOpenspot\tfound\tbuiltin", "\(friends.path)\tfriends\tfound\tadded"])
        XCTAssertEqual(TextBlock.blocks(in: text).first { $0.value("row") == "year" }?.value("store"), examples.path)
    }

    func testAGoneStoreSaysSoUntilRemoveDropsIt() async throws {
        let gone = root.appendingPathComponent("gone")
        _ = try file.change { $0.add(store: Store(url: gone)) }

        let text = try await runs.answer(of: store, .show, limit: 60)
        XCTAssertEqual(SpotOutput(text: text).parts.first?.values["folder"]?.last, "\(gone.path)\tgone\tmissing\tadded")

        try await call(["gallery", "remove:\(gone.path)"])
        XCTAssertEqual(file.read().stores, [])
    }

    func testLocateMovesAGoneStoreToThePickedFolder() async throws {
        let gone = root.appendingPathComponent("gone")
        _ = try file.change { $0.add(store: Store(url: gone)) }
        let friends = try friends()
        try pick(friends)

        try await call(["gallery", "locate:\(gone.path)"])

        XCTAssertEqual(file.read().stores.map(\.url.path), [friends.path])
    }

    func testGetCopiesASpotOfAStoreFolder() async throws {
        let friends = try friends()
        _ = try file.change { $0.add(store: Store(url: friends)) }

        try await call(["gallery", "get:clock"])

        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.appendingPathComponent("clock.spot/clock.sh").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: friends.appendingPathComponent("clock.spot/clock.sh").path))
    }

    func testItOpensInAWindowWithItsGalleryView() throws {
        let spot = try store

        XCTAssertEqual(spot.name, "Store")
        XCTAssertTrue(spot.offersWindow)
        XCTAssertTrue(spot.offersCard)
        XCTAssertEqual(spot.kind, .list)
        XCTAssertEqual(spot.view.map { URL(fileURLWithPath: $0).lastPathComponent }, "store.swift")
    }

    func testItListsEachSpotWithWhatItsButtonDoes() async throws {
        let rows = try await items()

        XCTAssertEqual(rows.map { Array($0.prefix(4)) }, [["mine", "Mine", "added", "mine"], ["shared", "Shared", "get", "store"], ["timer", "Timer", "get", "core"]])
        XCTAssertEqual(rows.first { $0[0] == "timer" }?[4], "Counts down")
        XCTAssertEqual(rows.map { $0[6] }, ["", "", "sample"])
    }

    func testGetTurnsOnACoreSpotAndAddsAStoredOne() async throws {
        let ids = try await items().map { $0[0] }
        XCTAssertTrue(ids.contains("timer"))

        try await call(["gallery", "get:timer"])
        XCTAssertTrue(file.read().arrangement.enabled.contains("timer"))

        try await call(["gallery", "get:shared"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.appendingPathComponent("shared.spot/shared.sh").path))
        let rows = try await items()
        XCTAssertEqual(rows.first { $0[0] == "timer" }?[2], "added")
    }

    func testAFailedGetSaysWhyInAToast() async throws {
        _ = try await runs.answer(of: store, SpotAction(arguments: ["gallery", "get:nothing"]), limit: 60)

        XCTAssertEqual(effects().map { $0.hasPrefix("toast ") }, [true])
    }

    func testPublishDoesNothingUntilTheStoreOpensIt() async throws {
        _ = try AccountStore.standard(environment: ["OPENSPOT_CONFIG": root.path], home: root, devState: nil).keyMadeOnce()

        _ = try await runs.answer(of: store, SpotAction(arguments: ["gallery", "publish:mine"]), limit: 60)

        XCTAssertEqual(effects(), [])
        let opened = await app.opened
        XCTAssertEqual(opened, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("store/mine.spot").path))
    }

    func testGetTurnsBackOnYourOwnSpotThatEditSpotsTurnedOff() async throws {
        try file.turn("mine", on: false)
        let before = try await items()
        XCTAssertEqual(before.first { $0[0] == "mine" }?[2], "get")

        try await call(["gallery", "get:mine"])

        XCTAssertEqual(file.read().arrangement.disabled, [])
    }

    func testOnlyTheSheetOfASpotGetsItsReadmeLineByLine() async throws {
        try "# Timer\n\nCounts down.\n".write(to: core.appendingPathComponent("timer.spot/readme.md"), atomically: true, encoding: .utf8)
        try "# Mine\n".write(to: spots.appendingPathComponent("mine.spot/readme.md"), atomically: true, encoding: .utf8)

        for action in [SpotAction.show, SpotAction(arguments: ["gallery", "get:timer"]), SpotAction(arguments: ["gallery", "publish:timer"])] {
            let text = try await SpotRuns(environment: TestEnvironment.values).answer(of: store, action, limit: 60)
            XCTAssertNil(SpotOutput(text: text).parts.first?.values["readme"], "\(action.arguments)")
        }
        let asked = try await SpotRuns(environment: TestEnvironment.values).answer(of: store, SpotAction(arguments: ["gallery", "readme:timer"]), limit: 60)

        XCTAssertEqual(SpotOutput(text: asked).parts.first?.values["readme"], ["timer", "timer\t# Timer", "timer\t", "timer\tCounts down."])
        XCTAssertEqual(TextBlock.blocks(in: asked).compactMap { $0.value("row") }, ["mine", "shared", "timer"])
    }

    func testAReadmePictureOrVideoInTheSpotsFolderGetsItsFullPath() async throws {
        let folder = core.appendingPathComponent("timer.spot")
        try "![The sheet](shot.png)\n![](/tmp/a.mov)\n![Web](https://example.com/a.jpg)\n".write(to: folder.appendingPathComponent("readme.md"), atomically: true, encoding: .utf8)

        let text = try await SpotRuns(environment: TestEnvironment.values).answer(of: store, SpotAction(arguments: ["gallery", "readme:timer"]), limit: 60)

        let lines = (SpotOutput(text: text).parts.first?.values["readme"] ?? []).filter { $0.hasPrefix("timer\t") }
        XCTAssertEqual(lines, ["timer\t![The sheet](\(folder.path)/shot.png)", "timer\t![](/tmp/a.mov)", "timer\t![Web](https://example.com/a.jpg)"])
    }
}
