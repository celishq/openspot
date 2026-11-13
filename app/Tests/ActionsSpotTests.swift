import XCTest
@testable import OpenspotCore

/// Proves the spot of the app that offers the commands of each card: each fits the cards of its origin, and each asks the
/// API to do it.
final class ActionsSpotTests: BuiltInCase {
    func testEachCommandFitsTheCardsOfItsOriginAndHasNoCard() throws {
        let actions = try spot("actions")

        XCTAssertEqual(actions.offeredActions.map(\.action.title), ["Edit", "Copy prompt for AI", "Share", "Delete", "Turn off", "Change Icon", "Draw…", "Choose File…", "Reset Icon"])
        XCTAssertEqual(actions.offeredActions.map(\.origins), [[.mine], [.mine], [.mine, .core], [.mine], [.core], [], [], [], []])
        XCTAssertEqual(actions.offeredActions.map { $0.action.key?.label ?? "" }, ["⌘E", "", "⌘⇧C", "⌘⌫", "⌘⌫", "", "", "", ""])
        XCTAssertEqual(actions.offeredActions.map(\.when), [nil, nil, nil, nil, nil, nil, nil, nil, "hasIcon"])
        XCTAssertNil(actions.offeredActions[3].action.confirm)
        XCTAssertFalse(actions.offersCard)
    }

    func testEachCommandAsksTheAPIAndTurnOffTurnsTheSpotOff() async throws {
        let actions = try spot("actions")
        try "#!/bin/sh\n# title=Caffeinate\n".writeScript(to: core.appendingPathComponent("caffeinate.spot/caffeinate.sh"))

        for act in ["edit", "prompt", "share", "delete"] {
            try await actions.perform(SpotAction(arguments: [act, "weather"]), timeout: 5)
        }
        try await actions.perform(SpotAction(arguments: ["off", "caffeinate"]), timeout: 5)

        let opened = await app.opened
        let changes = await app.changeList
        XCTAssertEqual(opened, ["edit weather", "prompt weather", "share weather", "delete weather"])
        XCTAssertEqual(changes.last, .spots(["caffeinate"]))
    }

    func testChangeIconHandsEachChoiceToTheIconSpotAndResetShowsOnlyOnACardWithItsOwnIcon() async throws {
        let actions = try spot("actions")
        let icon = try spot("icon")
        let ask = { (card: String) in await actions.hook("hasIcon", card: card, origin: "mine") }
        try FileManager.default.createSymbolicLink(at: core.appendingPathComponent("openspot.spot"), withDestinationURL: repoSpots.appendingPathComponent("openspot.spot"))

        let before = await ask("weather")
        try await actions.perform(SpotAction(arguments: ["icon.draw", "weather"]), timeout: 5)
        try await icon.perform(SpotAction(arguments: ["drawer", "0" + String(repeating: ".", count: 80)]), timeout: 5)
        try await icon.perform(SpotAction(arguments: ["save"]), timeout: 5)
        let drawn = await ask("weather")
        try await actions.perform(SpotAction(arguments: ["icon.reset", "weather"]), timeout: 5)
        let after = await ask("weather")
        try await actions.perform(SpotAction(arguments: ["icon.file", "weather"]), timeout: 5)

        let opened = await app.opened
        XCTAssertEqual([before, drawn, after], [false, true, false])
        XCTAssertEqual(opened, ["open openspot/icon", "choose openspot/icon"])
    }
}
