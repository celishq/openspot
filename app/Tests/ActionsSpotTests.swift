import XCTest
@testable import OpenspotCore

/// Proves the spot of the app that offers the commands of each card: each fits the cards of its origin, and each asks the
/// API to do it.
final class ActionsSpotTests: BuiltInCase {
    func testEachCommandFitsTheCardsOfItsOriginAndHasNoCard() throws {
        let actions = try spot("actions")

        XCTAssertEqual(actions.offeredActions.map(\.action.title), ["Edit", "Copy prompt for AI", "Share", "Delete", "Turn off"])
        XCTAssertEqual(actions.offeredActions.map(\.origins), [[.mine], [.mine], [.mine, .core], [.mine], [.core]])
        XCTAssertEqual(actions.offeredActions.map { $0.action.key?.label ?? "" }, ["⌘E", "", "⌘⇧C", "⌘⌫", "⌘⌫"])
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
}
