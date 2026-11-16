import XCTest
@testable import OpenspotCore

final class ActionsSpotTests: BuiltInCase {
    func testEachCommandFitsTheCardsOfItsOriginAndHasNoCard() throws {
        let actions = try spot("actions")

        XCTAssertEqual(actions.offeredActions.map(\.action.title), ["Share", "Settings", "Edit", "Change Icon", "Draw…", "Choose File…", "Reset Icon", "Keys…", "Delete", "Turn off"])
        XCTAssertEqual(actions.offeredActions.map(\.origins), [[.mine, .core], [], [.mine, .core], [], [], [], [], [], [.mine], [.core]])
        XCTAssertEqual(actions.offeredActions.map { $0.action.key?.label ?? "" }, ["⇧⌘C", "⌘⏎", "⌘E", "", "", "", "", "", "⌘⌫", "⌘⌫"])
        XCTAssertEqual(actions.offeredActions.map(\.hooks), [[:], [:], [:], [:], [:], [:], [.when: "hasIcon"], [.hotkey: "openKey"], [:], [:]])
        XCTAssertNil(actions.offeredActions[8].action.confirm)
        XCTAssertFalse(actions.offersCard)
    }

    func testEachCommandAsksTheAPIAndTurnOffTurnsTheSpotOff() async throws {
        let actions = try spot("actions")
        try "#!/bin/sh\n# title=Caffeinate\n".writeScript(to: core.appendingPathComponent("caffeinate.spot/caffeinate.sh"))

        for act in ["settings", "edit", "share", "delete"] {
            try await actions.perform(SpotAction(arguments: [act, "weather"]), timeout: 60)
        }
        try await actions.perform(SpotAction(arguments: ["off", "caffeinate"]), timeout: 60)

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
        try await actions.perform(SpotAction(arguments: ["icon.draw", "weather"]), timeout: 60)
        try await icon.perform(SpotAction(arguments: ["drawer", "0" + String(repeating: ".", count: 80)]), timeout: 60)
        try await icon.perform(SpotAction(arguments: ["save"]), timeout: 60)
        let drawn = await ask("weather")
        try await actions.perform(SpotAction(arguments: ["icon.reset", "weather"]), timeout: 60)
        let after = await ask("weather")
        try await actions.perform(SpotAction(arguments: ["icon.file", "weather"]), timeout: 60)

        let opened = await app.opened
        XCTAssertEqual([before, drawn, after], [false, true, false])
        XCTAssertEqual(opened, ["open openspot/icon", "choose openspot/icon"])
    }

    func testKeysPushesTheKeysSheetOnThePageOfTheCardAndItsRowEndsInTheOpenKey() async throws {
        let actions = try spot("actions")
        try script("shelf.sh", "title=Shelf\non=sheet.open")
        let before = await actions.hotkey("openKey", card: "shelf", origin: "mine")
        _ = try file.change { $0.assign(.key(try XCTUnwrap(Shortcut(text: "ctrl+option+s"))), to: "shelf", act: .open) }

        try await actions.perform(SpotAction(arguments: ["keys", "shelf"]), timeout: 60)
        let after = await actions.hotkey("openKey", card: "shelf", origin: "mine")

        let opened = await app.opened
        XCTAssertEqual(opened, ["push openspot/keys spot:shelf"])
        XCTAssertEqual([before, after], ["", "ctrl+option+s"])
    }

    func testAWhenFunctionThatReturnsAnyTextSaysYes() async throws {
        let js = try temporaryFolder().appendingPathComponent("hooks.js")
        try "// title=Hooks\n//\n// button=go\n// title=Go\n// when=named\n// offers=actions\nfunction named(id) { return id === \"a\" ? \"yes\" : \"\"; }\n".write(to: js, atomically: true, encoding: .utf8)
        let hooks = try XCTUnwrap(try SpotFile(file: js, id: "hooks")?.spots.first)

        let a = await hooks.hook("named", card: "a", origin: "mine")
        let b = await hooks.hook("named", card: "b", origin: "mine")

        XCTAssertEqual([a, b], [true, false])
    }
}
