import XCTest
@testable import OpenspotCore

final class SettingsSpotTests: BuiltInCase {
    private var settings: Spot {
        get throws {
            try spot("settings")
        }
    }

    private func show(at destination: String? = nil) async throws -> String {
        try await runs.answer(of: settings, ScriptEntry.show.name, input: destination.map { "input.at=\($0)\n" }, limit: 60)
    }

    private func send(_ words: String...) async throws -> String {
        try await runs.answer(of: settings, "window", input: "input.value=\(words.joined(separator: "\t"))\n", limit: 60)
    }

    private func records(_ text: String) -> [String: TextBlock] {
        Dictionary(TextBlock.blocks(in: text).compactMap { block in block.value("item").map { ($0, block) } }) { first, _ in first }
    }

    private func viewValues(_ text: String) throws -> [String: [String]] {
        let frame = Frame(text: text, kinds: try settings.kinds)
        XCTAssertEqual(frame.parts.map(\.id), ["window"])
        return frame.parts.first.flatMap { frame.tree.node($0.id) }?.values ?? [:]
    }

    func testItOpensAsAWindowOfTheSettingsSizeAndDrawsItsOwnView() throws {
        let spot = try settings

        XCTAssertEqual(spot.window, .settings)
        XCTAssertEqual(Array(spot.views.keys), ["settings"])
    }

    func testTheShowHandsTheViewEveryAccessSpotRowThemeAndTheAccount() async throws {
        try "#!/bin/sh\nopenspot screen shot\n".writeScript(to: spots.spotFile("cups"), toml: "title = 'Cups'\nuses = ['screen']\n[actions.fill]\ntitle = 'Fill'")
        accesses.set(.screen, to: .denied)

        let text = try await show()
        let found = records(text)

        XCTAssertNil(try viewValues(text)["at"])
        XCTAssertEqual(Set(found.keys.filter { $0.hasPrefix("access:") }), Set(MacAccess.allCases.map { "access:\($0.rawValue)" }))
        XCTAssertEqual(found["access:screen"]?.value("title"), "Screen Recording")
        XCTAssertEqual(found["access:screen"]?.value("access"), "denied")
        XCTAssertEqual(found["access:screen"]?.value("spots"), "cups")
        XCTAssertEqual(found["spot:cups"]?.value("kind"), "spot")
        XCTAssertEqual(found["spot:cups"]?.value("state"), "access")
        XCTAssertEqual(found["spot:cups"]?.value("needs"), "screen")
        XCTAssertEqual(found["spot:cups"]?.value("access.screen"), "screen")
        XCTAssertFalse(found.keys.contains { $0.hasPrefix("spot:openspot/") })
        XCTAssertEqual(found["row:openspot/panel-key"]?.value("form"), "key")
        XCTAssertEqual(found["row:openspot/panel-key"]?.value("value"), "ctrl+space")
        XCTAssertEqual(found["row:cups/key.fill"]?.value("title"), "Fill")
        XCTAssertEqual(found["theme:Openspot"]?.value("used"), "true")
        XCTAssertEqual(found["theme:Dracula"]?.value("dark.accent"), "#BD93F9")
        XCTAssertEqual(Set(found.values.compactMap { $0.value("parent") }), ["rows"])
    }

    func testAShowAskedToLandHandsWhereToTheView() async throws {
        let text = try await show(at: "access/screen")

        XCTAssertEqual(try viewValues(text)["at"], ["access/screen"])
    }

    func testASetSentByTheViewWritesThroughSettingSetAndShowsTheWindowAgain() async throws {
        try script("cups.sh", "title = 'Cups'\n[actions.fill]\ntitle = 'Fill'")

        _ = try await send("set", "openspot", "fix-key", "ctrl+option+f")
        let text = try await send("set", "cups", "open", "ctrl+option+k")

        XCTAssertEqual(file.read().fixKey, Shortcut(text: "ctrl+option+f"))
        XCTAssertEqual(records(text)["row:cups/open"]?.value("value"), "ctrl+option+k")
        XCTAssertNil(try viewValues(text)["at"])
        let removed = try await send("set", "cups", "open", "")
        XCTAssertNil(records(removed)["row:cups/open"]?.value("value"))
    }

    func testRemoveSentByTheViewTakesAwayASecret() async throws {
        try "#!/bin/sh\n".writeScript(to: spots.spotFile("weather"), toml: "title = 'Weather'\n[settings]\ntoken = 'secret'")
        try AppPlaces.test(TestEnvironment.values).secrets.keep("MARKER-7f3c", key: "token", of: "weather")

        let text = try await send("remove", "weather", "token")

        XCTAssertNil(try AppPlaces.test(TestEnvironment.values).secrets.read()["weather"]?["token"])
        XCTAssertEqual(records(text)["row:weather/token"]?.value("form"), "secret")
        XCTAssertNil(records(text)["row:weather/token"]?.value("value"))
    }

    func testAToggleOfTheAppGoesToTheMac() async throws {
        offerLogin()

        _ = try await send("set", "openspot", "login", "true")

        XCTAssertTrue(opensAtLogin)
    }

    func testTurnTurnsASpotOffAndOn() async throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("awake.spot/awake.sh"), toml: "title = 'Awake'")

        _ = try await send("turn", "awake", "true")
        XCTAssertTrue(file.read().arrangement.enabled.contains("awake"))
        let text = try await send("turn", "awake", "false")

        XCTAssertFalse(file.read().arrangement.enabled.contains("awake"))
        XCTAssertEqual(records(text)["spot:awake"]?.value("state"), "off")
    }

    func testAThemeSentByTheViewIsUsed() async throws {
        let text = try await send("theme", "Dracula")

        XCTAssertEqual(file.read().theme, "Dracula")
        XCTAssertEqual(records(text)["theme:Dracula"]?.value("used"), "true")
    }

    func testAllowStartsTheGuidedGrantAndTheWindowShowsItsStepUntilNotNowEndsIt() async throws {
        try "#!/bin/sh\nopenspot clipboard paste\n".writeScript(to: spots.spotFile("paste"), toml: "title = 'Paste'\nuses = ['clipboard']")
        reads.set(trust: .unasked)

        let text = try await send("allow", "paste")
        let ended = try await send("grant", "end")

        let grants = await app.grants
        XCTAssertEqual(grants, ["paste accessibility"])
        XCTAssertEqual(records(text)["grant"]?.value("kind"), "grant")
        XCTAssertEqual(records(text)["grant"]?.value("step"), "accessibility")
        XCTAssertEqual(records(text)["grant"]?.value("place"), "Privacy & Security › Accessibility")
        XCTAssertNil(records(ended)["grant"])
    }

    func testFailedWordsShowWhyInAToastAndTheWindowStays() async throws {
        let effects = try recordEffects()

        let text = try await send("theme", "Gone")

        XCTAssertEqual(effects(), ["toast There is no theme named Gone. Run `openspot theme list` to see each one."])
        XCTAssertNotNil(records(text)["theme:Openspot"])
    }

    func testSayShowsWhatTheViewWasTold() async throws {
        let effects = try recordEffects()

        _ = try await send("say", "Openspot didn't keep this secret.")

        XCTAssertEqual(effects(), ["toast Openspot didn't keep this secret."])
    }

    private var accountStore: AccountStore {
        AccountStore.standard(environment: ["OPENSPOT_CONFIG": root.path], home: root, devState: nil)
    }

    func testNewSentByTheViewMakesTheAccountAndTheWindowShowsIt() async throws {
        let signedOut = try await show()
        let text = try await send("new", "tony")

        XCTAssertEqual(records(signedOut)["account"]?.value("signedIn"), "false")
        XCTAssertEqual(records(text)["account"]?.value("signedIn"), "true")
        XCTAssertEqual(records(text)["account"]?.value("handle"), "tony")
        XCTAssertEqual(try accountStore.record()?.handle, "tony")
    }

    func testAHandleThatBreaksTheRuleSaysTheRuleInAToast() async throws {
        let effects = try recordEffects()

        _ = try await send("new", "T")

        XCTAssertEqual(effects(), ["toast \(AccountHandle.rule)"])
        XCTAssertNil(try accountStore.key())
    }

    func testSignOutSentByTheViewAsksTouchIDThenRemovesTheKey() async throws {
        _ = try accountStore.keyMadeOnce()

        let text = try await send("sign-out")

        XCTAssertNil(try accountStore.key())
        XCTAssertEqual(records(text)["account"]?.value("signedIn"), "false")
        let asked = await app.asked
        XCTAssertEqual(asked, ["sign out of your account"])
    }

    func testUnknownWordsFail() async throws {
        do {
            _ = try await send("gone")
            XCTFail("took unknown words")
        } catch {
            XCTAssertEqual((error as? SpotError)?.reason, "Settings cannot do that.")
        }
    }
}
