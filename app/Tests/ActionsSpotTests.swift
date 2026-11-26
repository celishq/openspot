import XCTest
@testable import OpenspotCore

final class ActionsSpotTests: BuiltInCase {
    func testEachCommandFitsTheCardsOfItsOriginAndHasNoCard() throws {
        let actions = try spot("actions")

        XCTAssertEqual(actions.offeredActions.map(\.action.title), ["Share", "Settings", "Edit", "Arrange", "Change Icon", "Draw…", "Choose File…", "Reset Icon", "Remove"])
        XCTAssertEqual(actions.offeredActions.map(\.origins), [[.mine, .core], [], [.mine], [], [], [], [], [], [.mine]])
        XCTAssertEqual(actions.offeredActions.map { $0.action.key?.label ?? "" }, ["⇧⌘C", "⌘⏎", "⌘E", "", "", "", "", "", "⌘⌫"])
        XCTAssertEqual(actions.offeredActions.map(\.when), [nil, nil, nil, nil, nil, nil, nil, "hasIcon", nil])
        XCTAssertNil(actions.offeredActions[8].action.confirm)
        XCTAssertFalse(actions.isFound)
    }

    func testArrangeKeepsThePanelOpenFromTheCardMenuAndFromTheSpotsSpot() throws {
        let actions = try spot("actions")
        let spots = try spot("spots")

        XCTAssertEqual(actions.offeredActions.first { $0.action.title == "Arrange" }?.action.after, .stay)
        XCTAssertEqual(spots.commands.first { $0.title == "Arrange" }?.closes, false)
    }

    func testEachCommandAsksTheAPI() async throws {
        let actions = try spot("actions")

        for act in ["settings", "edit", "share", "delete", "arrange"] {
            try await actions.perform(act, input: "input.item=weather\n", timeout: 60)
        }

        let opened = await app.opened
        XCTAssertEqual(opened, ["settings at spot/weather", "edit weather", "share weather", "delete weather", "grid"])
    }

    func testChangeIconHandsEachChoiceToTheIconSpotAndResetShowsOnlyOnACardWithItsOwnIcon() async throws {
        let actions = try spot("actions")
        let icon = try spot("icon")
        let ask = { (card: String) in await actions.hook("hasIcon", card: card, origin: "mine") }
        try FileManager.default.createSymbolicLink(at: core.appendingPathComponent("openspot.spot"), withDestinationURL: repoSpots.appendingPathComponent("openspot.spot"))
        runs.api = CommandAPI(mac: Mac(), places: .test(TestEnvironment.values), app: app, runs: runs)
        runs.take(try SpotsFolder(url: root.appendingPathComponent("none"), core: repoSpots).scan())
        defer { runs.quit() }
        let acts = try XCTUnwrap(runs.sheets["openspot/actions"])
        let weather = [TextBlock.Field(key: "item", value: "weather")]

        let before = await ask("weather")
        _ = try await acts.call("icon.draw", inputs: weather)
        try await icon.perform("drawer", input: "input.value=0" + String(repeating: ".", count: 80) + "\n", timeout: 60)
        try await icon.perform("save", timeout: 60)
        let drawn = await ask("weather")
        _ = try await acts.call("icon.reset", inputs: weather)
        let after = await ask("weather")
        _ = try await acts.call("icon.file", inputs: weather)

        let opened = await app.opened
        XCTAssertEqual([before, drawn, after], [false, true, false])
        XCTAssertEqual(opened, ["open openspot/icon", "choose openspot/icon"])
    }

    func testAWhenHandlerThatReturnsAnyTextSaysYes() async throws {
        let js = try temporaryFolder().appendingPathComponent("hooks.js")
        try "export default { named({ item }) { return item === \"a\" ? \"yes\" : \"\" } }\n".writeInline(to: js, toml: "title = 'Hooks'\n[actions.go]\ntitle = 'Go'\nwhen = 'named'\noffers = ['actions']")
        let hooks = try XCTUnwrap(try SpotFile(file: js, id: "hooks", isApp: true)?.spots.first)

        let a = await hooks.hook("named", card: "a", origin: "mine")
        let b = await hooks.hook("named", card: "b", origin: "mine")

        XCTAssertEqual([a, b], [true, false])
    }
}
