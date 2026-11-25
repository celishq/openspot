import XCTest
@testable import OpenspotCore

@MainActor
final class SettingsBookTests: PanelCase {
    private final class Login: @unchecked Sendable {
        var isOn = false
    }

    private let accesses = FakeAccesses()
    private let login = Login()

    private static let builtInTheme = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Themes/openspot.theme/theme.toml")

    private var book: SettingsBook {
        model.settingsBook
    }

    private var config: Config {
        model.files.config.read()
    }

    override func setUp() async throws {
        try await super.setUp()
        let login = login
        let item = LoginItem(isOn: { login.isOn }, set: { login.isOn = $0 })
        model.runs.api = CommandAPI(mac: Mac(accesses: accesses, login: { item }, theme: Self.builtInTheme), places: model.files, app: ModelApp(model: model), runs: model.runs)
    }

    private func read() async {
        await model.reload()
        await book.read()
    }

    private func row(_ item: String) throws -> SettingRow {
        try XCTUnwrap(book.facts.row(item), "no row \(item)")
    }

    func testTheFactsHoldEveryAccessSpotRowThemeAndTheAccount() async throws {
        try script("cups", toml: "title = 'Cups'\nuses = ['screen']\n[actions.fill]\ntitle = 'Fill'", "openspot screen shot")
        accesses.set(.screen, to: .denied)

        await read()
        let facts = book.facts

        XCTAssertEqual(facts.accesses.map(\.id), MacAccess.allCases)
        XCTAssertEqual(facts.access(.screen)?.status, .denied)
        XCTAssertEqual(facts.access(.screen)?.spots, ["cups"])
        XCTAssertEqual(facts.standing("cups")?.readiness, .access)
        XCTAssertEqual(facts.standing("cups")?.needs, [.screen])
        XCTAssertEqual(facts.standing("cups")?.uses.first { $0.id == .screen }?.needs, [.screen])
        XCTAssertFalse(facts.standings.contains { $0.id.hasPrefix("openspot/") })
        XCTAssertEqual(try row("openspot/panel-key").kind, .key)
        XCTAssertEqual(try row("openspot/panel-key").value, "ctrl+space")
        XCTAssertEqual(try row("cups/key.fill").title, "Fill")
        XCTAssertEqual(facts.looks.first { $0.isUsed }?.id, "Openspot")
        XCTAssertEqual(facts.looks.first { $0.id == "Dracula" }?.colours.dark.accent.text, "#BD93F9")
        XCTAssertEqual(facts.account?.isSignedIn, false)
    }

    func testTheSearchFindsAccessesSpotsAndRowsByTheirFoldedWords() async throws {
        try script("cups", toml: "title = 'Café Cups'\n[actions.fill]\ntitle = 'Fill'", "")
        await read()

        let found = book.facts.found("CAFE")
        let screen = book.facts.found("screen rec")

        XCTAssertEqual(found.standings.map(\.id), ["cups"])
        XCTAssertEqual(screen.accesses.map(\.id), [.screen])
        XCTAssertTrue(book.facts.found("zzz-none").isEmpty)
    }

    func testItLandsWhereTheWayInAsks() async throws {
        try script("cups", toml: "title = 'Cups'\n[actions.fill]\ntitle = 'Fill'", "")
        await read()

        book.land("access/screen")
        XCTAssertEqual(book.page, .accessOf(.screen))
        book.land("spot/cups")
        XCTAssertEqual(book.page, .spotOf("cups"))
        book.land("row/cups/key.fill")
        XCTAssertEqual(book.page, .spotOf("cups"))
        XCTAssertEqual(book.target, "cups/key.fill")
        book.land("row/openspot/panel-key")
        XCTAssertEqual(book.page, .general)
        XCTAssertEqual(book.target, "openspot/panel-key")
        book.land("keys")
        XCTAssertEqual(book.page, .keys)
        book.land("account")
        XCTAssertEqual(book.page, .account)
        book.land("search/screen")
        XCTAssertEqual(book.query, "screen")
    }

    func testBackAndForwardWalkThePagesSeen() async throws {
        await read()
        book.land("access")

        book.go(.keys)
        book.go(.look)
        book.goBack()
        XCTAssertEqual(book.page, .keys)
        book.goForward()

        XCTAssertEqual(book.page, .look)
        XCTAssertEqual(book.back, [.access, .keys])
    }

    func testASetWritesThroughSettingSetAndARemovalOfItsValueTakesItAway() async throws {
        try script("cups", toml: "title = 'Cups'\n[actions.fill]\ntitle = 'Fill'", "")
        await read()

        await book.set(try row("openspot/fix-key"), to: "ctrl+option+f")
        await book.set(try row("cups/open"), to: "ctrl+option+k")

        XCTAssertEqual(config.fixKey, Shortcut(text: "ctrl+option+f"))
        XCTAssertEqual(try row("cups/open").value, "ctrl+option+k")
        await book.set(try row("cups/open"), to: "")
        XCTAssertNil(try row("cups/open").value)
    }

    func testARecordedKeyBecomesTheValueOfItsRow() async throws {
        try script("cups", toml: "title = 'Cups'\n[actions.fill]\ntitle = 'Fill'", "")
        await read()

        book.startRecording(try row("cups/open"))
        XCTAssertTrue(book.record(key: "k", modifiers: ["ctrl", "option"]))

        try await wait("the recorded key") { (try? self.row("cups/open").value) == "ctrl+option+k" }
        XCTAssertNil(book.recording)
    }

    func testRemoveTakesAwayASecret() async throws {
        try script("weather", toml: "title = 'Weather'\n[settings]\ntoken = 'secret'", "")
        try model.files.secrets.keep("MARKER-7f3c", key: "token", of: "weather")
        await read()

        await book.remove(try row("weather/token"))

        XCTAssertNil(try model.files.secrets.read()["weather"]?["token"])
        XCTAssertEqual(try row("weather/token").kind, .secret)
        XCTAssertNil(try row("weather/token").value)
    }

    func testASecretTypedInSettingsIsKeptAndAShortOneIsNot() async throws {
        try script("weather", toml: "title = 'Weather'\n[settings]\ntoken = 'secret'", "")
        await read()

        await book.keep(secret: "abc", of: try row("weather/token"))
        await book.keep(secret: "tok-123456", of: try row("weather/token"))

        XCTAssertEqual(model.toasts.queue.map(\.words), ["Openspot didn't keep this secret, because it is shorter than \(SecretStore.shortest) characters. Type the whole value."])
        XCTAssertEqual(try model.files.secrets.read()["weather"]?["token"], "tok-123456")
        XCTAssertEqual(try row("weather/token").value, SettingRow.secretValue)
    }

    func testAChoiceWithNoValueShowsItsDefault() {
        let row = SettingRow(spot: "notes", name: "Notes", key: "sort", title: "Sort", value: nil, kind: .choice, section: .spot, icon: "", options: ["name", "date"], default: "date")

        XCTAssertEqual(book.display(row), "date")
    }

    func testAToggleOfTheAppGoesToTheMac() async throws {
        await read()

        await book.set(try row("openspot/login"), to: "true")

        XCTAssertTrue(login.isOn)
    }

    func testTurnTurnsASpotOffAndOn() async throws {
        try TestSpot(toml: "title = 'Awake'", body: "").write(to: core.appendingPathComponent("awake.spot/awake.sh"))
        await read()

        await book.turn("awake", on: true)
        XCTAssertTrue(config.arrangement.enabled.contains("awake"))
        await book.turn("awake", on: false)

        XCTAssertFalse(config.arrangement.enabled.contains("awake"))
        XCTAssertEqual(book.facts.standing("awake")?.readiness, .off)
    }

    func testAThemeIsUsedThroughThemeUse() async throws {
        await read()

        await book.use(theme: "Dracula")

        XCTAssertEqual(config.theme, "Dracula")
        XCTAssertEqual(book.facts.looks.first { $0.isUsed }?.id, "Dracula")
    }

    func testAFailedActSaysWhyInAToast() async throws {
        await read()

        await book.use(theme: "Gone")

        XCTAssertEqual(model.toasts.queue.map(\.words), ["There is no theme named Gone. Run `openspot theme list` to see each one."])
        XCTAssertFalse(book.facts.looks.isEmpty)
    }

    func testAllowStartsTheGuidedGrantAndEndGrantEndsIt() async throws {
        try script("agenda", toml: "title = 'Agenda'\nuses = ['calendar']", "openspot calendar events")
        accesses.set(.calendars, to: .denied)
        await read()

        await book.allow("agenda")

        XCTAssertEqual(book.grant?.spot, "agenda")
        XCTAssertEqual(book.grant?.step, .calendars)
        XCTAssertEqual(book.grant?.step?.place, "Privacy & Security › Calendars")
        await book.endGrant()
        XCTAssertNil(book.grant)
    }

    func testAskOpensThePaneOfAnAccessAndAsksForAccessibility() async throws {
        await read()

        await book.ask(.screen)
        await book.ask(.helper)

        XCTAssertEqual(host.opened, [MacAccess.screen.pane, MacAccess.helper.pane].compactMap { $0 })
    }

    func testNewMakesTheAccountAndTheFactsShowIt() async throws {
        await read()

        await book.makeAccount(handle: "tony")

        XCTAssertEqual(book.facts.account?.isSignedIn, true)
        XCTAssertEqual(book.facts.account?.handle, "tony")
        XCTAssertEqual(try model.files.account.record()?.handle, "tony")
    }

    func testAHandleThatBreaksTheRuleSaysTheRuleInAToast() async throws {
        await read()

        await book.makeAccount(handle: "T")

        XCTAssertEqual(model.toasts.queue.map(\.words), [AccountHandle.rule])
        XCTAssertNil(try model.files.account.key())
    }

    func testSignOutAsksTouchIDThenRemovesTheKey() async throws {
        _ = try model.files.account.keyMadeOnce()
        await read()

        await book.signOut()

        XCTAssertNil(try model.files.account.key())
        XCTAssertEqual(book.facts.account?.isSignedIn, false)
        XCTAssertEqual(host.asked, ["sign out of your account"])
    }

    func testTheGridAndTheFactsLeaveOutClashFreeKeysAndMarkClashes() async throws {
        try script("cups", toml: "title = 'Cups'\n[actions.fill]\ntitle = 'Fill'", "")
        try script("mugs", toml: "title = 'Mugs'\n[actions.fill]\ntitle = 'Fill'", "")
        await read()

        await book.set(try row("cups/open"), to: "ctrl+option+k")
        await book.set(try row("mugs/open"), to: "option+ctrl+k")

        XCTAssertEqual(book.facts.clashing, ["cups/open", "mugs/open"])
    }
}
