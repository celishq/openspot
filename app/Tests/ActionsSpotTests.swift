import XCTest
@testable import OpenspotCore

final class ActionsSpotTests: BuiltInCase {
    func testEachCommandFitsTheCardsOfItsOriginAndHasNoCard() throws {
        let actions = try spot("actions")

        XCTAssertEqual(actions.offeredActions.map(\.action.title), ["Share", "Settings", "Edit", "Change Icon", "Draw…", "Choose File…", "Reset Icon", "Delete", "Turn off"])
        XCTAssertEqual(actions.offeredActions.map(\.origins), [[.mine, .core], [], [.mine, .core], [], [], [], [], [.mine], [.core]])
        XCTAssertEqual(actions.offeredActions.map { $0.action.key?.label ?? "" }, ["⇧⌘C", "⌘⏎", "⌘E", "", "", "", "", "⌘⌫", "⌘⌫"])
        XCTAssertEqual(actions.offeredActions.map(\.hooks), [[:], [:], [:], [:], [:], [:], [.when: "hasIcon"], [:], [:]])
        XCTAssertNil(actions.offeredActions[7].action.confirm)
        XCTAssertFalse(actions.isFound)
    }

    func testEachCommandAsksTheAPIAndTurnOffTurnsTheSpotOff() async throws {
        let actions = try spot("actions")
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("caffeinate.spot/caffeinate.sh"), toml: "title = 'Caffeinate'")

        for act in ["settings", "edit", "share", "delete"] {
            try await actions.perform(SpotAction(arguments: [act]), input: "input.item=weather\n", timeout: 60)
        }
        try await actions.perform(SpotAction(arguments: ["off"]), input: "input.item=caffeinate\n", timeout: 60)

        let opened = await app.opened
        let changes = await app.changeList
        XCTAssertEqual(opened, ["settings weather", "edit weather", "share weather", "delete weather"])
        XCTAssertEqual(changes.last, .spots(["caffeinate"]))
    }

    func testChangeIconHandsEachChoiceToTheIconSpotAndResetShowsOnlyOnACardWithItsOwnIcon() async throws {
        let actions = try spot("actions")
        let icon = try spot("icon")
        let ask = { (card: String) in await actions.hook("hasIcon", card: card, origin: "mine") }
        try FileManager.default.createSymbolicLink(at: core.appendingPathComponent("openspot.spot"), withDestinationURL: repoSpots.appendingPathComponent("openspot.spot"))

        let before = await ask("weather")
        try await actions.perform(SpotAction(arguments: ["icon.draw"]), input: "input.item=weather\n", timeout: 60)
        try await icon.perform(SpotAction(arguments: ["drawer"]), input: "input.value=0" + String(repeating: ".", count: 80) + "\n", timeout: 60)
        try await icon.perform(SpotAction(arguments: ["save"]), timeout: 60)
        let drawn = await ask("weather")
        try await actions.perform(SpotAction(arguments: ["icon.reset"]), input: "input.item=weather\n", timeout: 60)
        let after = await ask("weather")
        try await actions.perform(SpotAction(arguments: ["icon.file"]), input: "input.item=weather\n", timeout: 60)

        let opened = await app.opened
        XCTAssertEqual([before, drawn, after], [false, true, false])
        XCTAssertEqual(opened, ["open openspot/icon", "choose openspot/icon"])
    }

    func testAWhenFunctionThatReturnsAnyTextSaysYes() async throws {
        let js = try temporaryFolder().appendingPathComponent("hooks.js")
        try "function named(id) { return id === \"a\" ? \"yes\" : \"\"; }\n".writeInline(to: js, toml: "title = 'Hooks'\n[commands.go]\ntitle = 'Go'\nwhen = 'named'\noffers = ['actions']")
        let hooks = try XCTUnwrap(try SpotFile(file: js, id: "hooks")?.spots.first)

        let a = await hooks.hook("named", card: "a", origin: "mine")
        let b = await hooks.hook("named", card: "b", origin: "mine")

        XCTAssertEqual([a, b], [true, false])
    }
}
